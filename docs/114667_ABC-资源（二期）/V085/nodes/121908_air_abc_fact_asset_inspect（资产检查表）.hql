--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  资产检查表
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_asset_inspect
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]    
--${v_one_date}:  统计日期(yyyymmdd)   --$[time(yyyy-MM-01)] 
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       资产检查表
--2022-09-22            chenweizhen    计划在20221015后由ods_sap_bw.bic_asaa1d00600切换为ods_sap_bw.bic_asaa1d00700
--2025-02-11            chenweizhen    ods_sap_bw.bic_asaa1d00700，这个表， 日常都是同步到5号分区，由于春节关停延迟， 10号分区重新同步了一份新数据 ，5号和10号分区都有数据， 10号的数据是最新的， 5号分区数据， 缺失部分数据，如航空的当月折旧为0
                         
--#####################################################################

--##################################################################### 
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
set mapred.job.name=${v_proc_name};
set hive.exec.reducers.max=400;
set mapred.task.timeout=1000000;
set hive.fetch.task.conversion=more;
set hive.exec.compress.output=false;
set hive.exec.compress.intermediate=true;
set mapred.max.split.size=1000000000;
set mapred.min.split.size.per.node=1000000000;
set mapred.min.split.size.per.rack=1000000000;
set hive.auto.convert.join=true;
set hive.groupby.skewindata=true;
set hive.exec.mode.local.auto=false;
set hive.mapjoin.smalltable.filesize=128000000;
set hive.exec.dynamic.partition.mode=nonstrict;
set hive.ignore.mapjoin.hint=true;
set hive.exec.parallel=true;
set hive.exec.parallel.thread.number=16;
set hive.mapjoin.smalltable.filesize=128000000;


--#####################################################################
--链接数据库
use dm_air_dw;

--#####################################################################
-- step1.清洗anla表，并计算总账科目
drop table if exists tmp_dm_air_dw.anla_tmp;
create table tmp_dm_air_dw.anla_tmp as 
select t.bukrs  as company_code, -- 公司代码
       t.anln1  as asset_no, -- 资产卡片号
       t.anln2  as asset_no_2, -- 资产次级编号
       t.aibn1  as initial_asset_no, -- 原始资产号
       t.invnr  as stock_no, -- 存货号
       t.sernr  as list_no, -- 序列号
       t.txt50  as remark, -- 描述
       t.aktiv  as asset_date, -- 资本日期
       t.ord42  as car_use, -- 车辆用途（行政+运营)
       t.menge  as rn_qty, -- 数量
       t.meins  as unit_code, -- 单位
       t.typbz  as asset_type_desc, -- 类型名
       b.ktnafg as sap_account -- 总账科目-资产样表
  from (select bukrs,
               anln1,
               anln2,
               aibn1,
               invnr,
               sernr,
               txt50,
               aktiv,
               ord42,
               menge,
               meins,
               typbz,
               ktogr,
               row_number() over(partition by bukrs, anln1, anln2 order by inc_month desc) as rn
          from ods_sap_fico.anla) t
  left join ods_sap_fico.t095b b
    on t.ktogr = b.ktogr
   and b.afabe = '01'
   and case
         when '${v_month}' <= '201811' then
          b.inc_day = '20181231'
         else
          b.inc_day = '${v_one_date}'
       end
 where t.rn = 1;
		 
-- step2.清洗anlb表
drop table if exists tmp_dm_air_dw.anlb_tmp;
create table tmp_dm_air_dw.anlb_tmp as 
select t.bukrs      as company_code, -- 公司代码
       t.anln1      as asset_no, -- 资产卡片号
       t.anln2      as asset_no_2, -- 资产次级编号
       t.afasl      as depreciation_code, -- 折旧码
       t.ndjar      as limit_time_01, -- 使用年限（01）
       t.schrw_proz as residual_rate -- 残值率
  from (select bukrs,
               anln1,
               anln2,
               afasl,
               concat_ws(':', ndjar, ndper) as ndjar,
               case
                 when AFASL = 'ZLN1' then
                  5
                 else
                  schrw_proz
               end as schrw_proz,
               row_number() over(partition by bukrs, anln1, anln2 order by inc_month desc) as rn
          from ods_sap_fico.anlb
         where afabe = '01') t
 where t.rn = 1;

-- step3.清洗anlz表
drop table if exists tmp_dm_air_dw.anlz_tmp;
create table tmp_dm_air_dw.anlz_tmp as 
select t.bukrs     as company_code, -- 公司代码
       t.anln1     as asset_no, -- 资产卡片号
       t.anln2     as asset_no_2, -- 资产次级编号
       t.caufn     as intern_code, -- 内部订单
       t.grant_nbr as grant_nbr -- 功能范围
  from (select bukrs,
               anln1,
               anln2,
               caufn,
               grant_nbr,
               row_number() over(partition by bukrs, anln1, anln2 order by bdatu desc) as rn
          from ods_sap_fico.anlz
         where substr(bdatu, 1, 6) <= '${v_month}'
           and substr(adatu, 1, 6) >= '${v_month}') t
 where t.rn = 1;

-- step4.汇总生成SAP总账-资产表  modify by cwz 20220922注释掉
--insert overwrite table dm_air_dw.air_abc_fact_asset_inspect partition (inc_month = '${v_month}')
--select t.calmonth as month,
--       t.comp_code as company_code,
--       t.bic_zgsdmdes as company_name,
--       t.asset_main as asset_no,
--       a.asset_no_2,
--       a.initial_asset_no,
--       a.stock_no,
--       a.list_no,
--       a.remark,
--       a.asset_date,
--       t.bic_zcalmonth as enter_month,
--       b.depreciation_code,
--       b.limit_time_01,
--       t.asset_clas as asset_type_code,
--       t.bic_zczcfldes as asset_type_name,
--       a.car_use,
--       t.ass_sup_no as asset_classify_code,
--       t.bic_zzctjhdes as asset_classify_desc,
--       a.rn_qty,
--       a.unit_code,
--       t.bic_zkzcyz as original_value,
--       t.fi_accdepr as depreciation_total,
--       t.bic_zkzcyz + t.fi_accdepr as net_amount,
--       t.bic_zkzcyz * b.residual_rate / 100 as residual_value,
--       t.bic_zkdyzj as depreciation_mon,
--       t2.depreciation_year,
--       t.costcenter as cost_code,
--       t.profit_ctr as prif_code,
--       z.intern_code,
--       a.asset_type_desc,
--       t.transtype as asset_scrap_code,
--       t.bic_zczcswdes as asset_scrap_desc,
--       t.bic_zccphm as plate_no,
--       t.bic_zcbjhrq as scrap_date,
--       b.residual_rate,
--       a.sap_account,
--       t3.grant_nbr,
--       null as virtual_group,
--       null as virtual_desc,
--       null as b_code,
--       null as limit_time_30,
--       null as fund_amt,
--       null as plant_state,
--       null as user_name,
--       null as lease_state,
--       null as sap_account_name,
--       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as loadtime
--  from ods_sap_bw.bic_asaa1d00600 t
--  left join tmp_dm_air_dw.anla_tmp a
--    on t.comp_code = a.company_code
--   and t.asset_main = a.asset_no
--  left join tmp_dm_air_dw.anlb_tmp b
--    on t.comp_code = b.company_code
--   and t.asset_main = b.asset_no
--  left join tmp_dm_air_dw.anlz_tmp z
--    on t.comp_code = z.company_code
--   and t.asset_main = z.asset_no
--  left join (select comp_code,
--                    asset_main,
--                    sum(bic_zkdyzj) as depreciation_year
--               from ods_sap_bw.bic_asaa1d00600 o
--              where inc_month >= '${v_year}01'
--                and inc_month <= '${v_month}'
--              group by comp_code, asset_main) t2
--    on t.comp_code = t2.comp_code
--   and t.asset_main = t2.asset_main
--  left join (select t1.copa_kostl as cost_center,
--                    t1.crmcsty,
--                    t1.wwyu5      as grant_nbr
--               from ods_sap_fico.ce1sf00 t1
--              where t1.bukrs = 'EX01'
--              group by t1.copa_kostl, t1.crmcsty, t1.wwyu5) t3
--    on t.costcenter = t3.cost_center
--   and a.sap_account = t3.crmcsty
-- where (t.bic_zcbjhrq = '00000000' or
--       substr(t.bic_zcbjhrq, 1, 6) = '${v_month}')
--   and t.CO_AREA = 'SF00'
--   and t.FM_AREA = 'SF00'
--   and t.calmonth = '${v_month}'
--   and t.comp_code = 'EX01'
--   and t.asset_main not like '9%'
--   and t.inc_month = '${v_month}';
-- ##################################################################################### 


-- select min(inc_day),max(inc_day) from ods_sap_bw.bic_asaa1d00700 where inc_day >= '$[time(yyyy0105)]' and inc_day <= '$[time(yyyyMM05)]'
-- 返回20220107  20220807 后续有10月后就会包含20221005
-- ods_sap_bw.bic_asaa1d00700 在20220921前每个月8号一版数据 存储在当月7日分区   20221001后每个月6号有一版数据会存储在 inc_day=20221005  即以后每个月inc_day='$[time(yyyyMM05)]' 会有数据

-- step4.汇总生成SAP总账-资产表   --add by cwz 20220922  计划20221015后启用
insert overwrite table dm_air_dw.air_abc_fact_asset_inspect partition (inc_month = '${v_month}')
select t.calmonth as month,
       t.comp_code as company_code,
       t.bic_zgsdmdes as company_name,
       t.asset_main as asset_no,
       a.asset_no_2,
       a.initial_asset_no,
       a.stock_no,
       a.list_no,
       a.remark,
       a.asset_date,
       substr(t.calday,1,6) as enter_month,      ----t.bic_zcalmonth as enter_month, 20220922
       b.depreciation_code,
       b.limit_time_01,
       t.asset_clas as asset_type_code,
       t.bic_zczcfldes as asset_type_name,
       a.car_use,
       t.ass_sup_no as asset_classify_code,
       t.bic_zzctjhdes as asset_classify_desc,
       a.rn_qty,
       a.unit_code,
       t.bic_zkzcyz as original_value,
       t.fi_accdepr as depreciation_total,
       t.bic_zkzcyz + t.fi_accdepr as net_amount,
       t.bic_zkzcyz * b.residual_rate / 100 as residual_value,
       t.bic_zkdyzj as depreciation_mon,
       t2.depreciation_year,     --这个指标4年都没有用到 abc   20220922
       t.costcenter as cost_code,
       t.profit_ctr as prif_code,
       z.intern_code,
       a.asset_type_desc,
       t.transtype as asset_scrap_code,
       t.bic_zczcswdes as asset_scrap_desc,
       t.bic_zccphm as plate_no,
       t.bic_zcbjhrq as scrap_date,
       b.residual_rate,
       a.sap_account,
       t3.grant_nbr,
       null as virtual_group,
       null as virtual_desc,
       null as b_code,
       null as limit_time_30,
       null as fund_amt,
       null as plant_state,
       null as user_name,
       null as lease_state,
       null as sap_account_name,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as loadtime
  from ods_sap_bw.bic_asaa1d00700 t
  left join tmp_dm_air_dw.anla_tmp a
    on t.comp_code = a.company_code
   and t.asset_main = a.asset_no
  left join tmp_dm_air_dw.anlb_tmp b
    on t.comp_code = b.company_code
   and t.asset_main = b.asset_no
  left join tmp_dm_air_dw.anlz_tmp z
    on t.comp_code = z.company_code
   and t.asset_main = z.asset_no
  left join (select comp_code,
                    asset_main,
                    sum(bic_zkdyzj) as depreciation_year
               from ods_sap_bw.bic_asaa1d00700 o
              where inc_day >= '$[time(yyyy0105)]'
                and inc_day <= '$[time(yyyyMM05)]'
              group by comp_code, asset_main) t2
    on t.comp_code = t2.comp_code
   and t.asset_main = t2.asset_main
  left join (select t1.copa_kostl as cost_center,
                    t1.crmcsty,
                    t1.wwyu5      as grant_nbr
               from ods_sap_fico.ce1sf00 t1
              where t1.bukrs = 'EX01'
              group by t1.copa_kostl, t1.crmcsty, t1.wwyu5) t3
    on t.costcenter = t3.cost_center
   and a.sap_account = t3.crmcsty
 where (t.bic_zcbjhrq = '00000000' or
       substr(t.bic_zcbjhrq, 1, 6) = '${v_month}')
   and t.CO_AREA = 'SF00'
   and t.FM_AREA = 'SF00'
   and t.calmonth = '${v_month}'
   and t.comp_code = 'EX01'
   and t.asset_main not like '9%'
   and t.inc_day =  (case when '$[time(yyyyMMdd)]'='20250206' then '20250210' else '$[time(yyyyMM05)]' end) 
;