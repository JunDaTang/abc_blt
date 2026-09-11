-- /***************************************************************************
-- Copyright 2022 sf-express.com Inc. All rights reserved.
-- Taskname: air_abc_fact_acco_sap（资源sap总账科目）
-- Description：sap总账管理处理,并按照业务逻辑处理为管理账调整后的数据
-- Source: ods_sap_bw.bic_asgl1d00400   ods_sap_fico.ce1sf00   air_abc_rel_air_port_city_code
-- Author: 刘直 2018-12-08
-- HISTORY
-- ***************************************************************************
-- ID DATE MODIFY MODIFIER REASON
-- 1 2018-12-08            刘直       create
-- 2 2021-08-05   01393364 陈维镇     modify ABC从sap收集的费用明细从202107去掉公司代码 SEI1     202106本来就没有这种数据 select * from dm_air_dw.air_abc_fact_acco_sap_initial t where t.inc_month='202102' and company_code='SEI1' limit 200
-- 3 2022-02-12   01393364 陈维镇     modify 利润中心t1.prctr='EX000' and 和成本中心t1.copa_kostl='EX00028' 2个表之前关联需要匹配公司代码t1.bukrs
-- 4 2022-04-06   01393364 陈维镇     modify add by 20220406 21年财务部成本中心变更为EX00028，设置不取凭证类型为空的条目（详见21年6月22日邮件-"财务费用-经营财报ABC取数逻辑（ex00028、ex00205 ）"），22年1月始EX00028财务费用不再通过管理账划走，但是1 2月份仍沿用前述规则，在3月正式限制条件，不再沿用该规则
-- 5 2022-04-06   01393364 陈维镇     modify t1.copa_kostl='SF0011430' and t1.bukrs='EX01' 成本中心SF0011430且公司代码为EX01的数据           
-- 6 2024-03-05   01393364 陈维镇     modify 科目6601370000 并且凭证号9开头的不进行计算  
-- 7 2024-11-05   01393364 陈维镇     剔除8K项目K-MILE公司代码SFE1 的成本
-- 8 2024-12-05   01393364 陈维镇     剔除成本剔除6401开头也是研发费用的凭证
-- ***************************************************************************/

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_acco_sap
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--##################################################################### 
--设置参数
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
----step1：处理400表数据 
drop table if exists tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp01;
create table tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp01 stored as parquet as
select concat(t.fiscyear_e, substr(t.fiscper3_e, 2, 2)) month,
       t.ac_doc_typ,
       t.postxt,
       t.fiscyear_e,
       t.fiscper3_e,
       t.ac_doc_nr,
       t.profit_ctr,
       t.gl_account,
       t.ac_doc_ln,
       t.comp_code,
       t.doc_currcy,
       t.ref_key3,
       case when substr(t.alloc_nmbr,1,2) = 'ME' then 'ME'
       else '' end alloc_nmbr,
       t.bic_zcsteter
  from ods_sap_bw.bic_asgl1d00400 t
 where concat(t.fiscyear_e, substr(t.fiscper3_e, 2, 2)) = '${v_month}'
   and ((substr(t.profit_ctr, 1, 2) = 'EX' or t.profit_ctr  in ('SF027H','EX00028') or t.profit_ctr = 'SF015HDE' or t.bic_zcsteter='SF0011430'))    --add by cwz 20220407 新增成本中心SF0011430
 group by t.ac_doc_typ,
          t.postxt,
          t.fiscyear_e,
          t.fiscper3_e,
          t.ac_doc_nr,
          t.profit_ctr,
          t.gl_account,
          t.ac_doc_ln,
          t.comp_code,
          t.doc_currcy,
          t.ref_key3,
          case when substr(t.alloc_nmbr,1,2) = 'ME' then 'ME'
          else '' end,
          t.bic_zcsteter;

----step2：数据写入SAP资源总账源数据表_管理帐调整前 
 insert overwrite table dm_air_dw.air_abc_fact_acco_sap_initial partition
  (inc_month = '${v_month}')
select concat(t1.gjahr, substr(t1.perde, 2, 2)) month, --月份
       t1.prctr as profit_code, --利润中心
       t1.bukrs as company_code, --公司代码
       t1.copa_kostl as cost_center, --成本中心
       case
         when t1.rbeln = '' then
          t1.belnr
         when t1.rbeln = ' ' then
          t1.belnr
         when t1.rbeln is null then
          t1.belnr
         else
          t1.rbeln
       end as voucher_number, --凭证编号
       t2.ac_doc_typ as voucher_type, --凭证类型
       t2.postxt as voucher_desc, --行文本
       t3.doc_currcy, --凭证货币
       t1.crmcsty as acco_code, --会计科目
       t1.wwyu5 as func_code, --功能范围
       t1.rkaufnr as intern_code, --内部订单
       cast(null as string) ref_doc_no,
       t2.ref_key3,
       'CNY' as base_currency, --货币
       case
         when t1.frwae = 'CNY' then
          t1.vv100
         else
          t1.vv100 * t4.ukurs
       end as base_currency_amt, --金额     
       t1.budat as post_date, --记帐日期
       t1.belnr remark, --备注
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm, --加载时间 
       t2.alloc_nmbr
  from ods_sap_fico.ce1sf00 t1
  left join tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp01 t2
    on concat(t1.gjahr, substr(t1.perde, 2, 2)) = t2.month
   and case
         when t1.rbeln = '' then
          t1.belnr
         when t1.rbeln = ' ' then
          t1.belnr
         when t1.rbeln is null then
          t1.belnr
         else
          t1.rbeln
       end = t2.ac_doc_nr
   and t1.prctr = t2.profit_ctr
   and t1.crmcsty = t2.gl_account
   and t1.rposn = t2.ac_doc_ln
   and t1.copa_kostl =t2.bic_zcsteter
and case
         when t1.copa_kostl in ('SF027H','EX00028') then     --modify by cwz 20220406 由 prctr 修改为 copa_kostl
          t1.bukrs
         ----when t1.prctr='EX000' and t1.copa_kostl='EX00028' then    --add by cwz 20220212
         ---- t1.bukrs
         else
          'ALL'
       end = case
         when t2.bic_zcsteter in ('SF027H','EX00028') then    --modify by cwz 20220406 由 profit_ctr 修改为 bic_zcsteter
          t2.comp_code
         ----when t2.profit_ctr='EX000' and t2.bic_zcsteter='EX00028' then   --add by cwz 20220212
         ---- t2.comp_code
         else
          'ALL'
       end
  left join tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp01 t3
    on concat(t1.gjahr, substr(t1.perde, 2, 2)) = t3.month
   and case
         when t1.rbeln = '' then
          t1.belnr
         when t1.rbeln = ' ' then
          t1.belnr
         when t1.rbeln is null then
          t1.belnr
         else
          t1.rbeln
       end = t3.ac_doc_nr
   and t1.prctr = t3.profit_ctr
   and t1.crmcsty = t3.gl_account
   and t1.rposn = t3.ac_doc_ln
   and t1.bukrs = t3.comp_code
  left join (select *
               from ods_sap.tcurr
              where inc_day = '${v_date}'
                and tcurr = 'CNY'
                and kurst = 'M') t4
    on t1.frwae = t4.fcurr
   and concat(t1.gjahr, substr(t1.perde, 2, 2)) =
       substr(cast(99999999 - t4.gdatu as int), 1, 6)
 where t1.kokrs = 'SF00'
   and t1.mandt = '800'
   and (
        substr(t1.prctr, 1, 2) = 'EX' or  t1.prctr = 'SF015HDE' or
       (t1.prctr in ('SF027H','EX00028') and
       nvl(t1.copa_awtyp, 'XXX') not in ('COBK', 'FMRES', 'FSRES')) 
       or (t1.copa_kostl='SF0011430' and t1.bukrs='EX01')             --add by cwz 20220407
       --or (t1.prctr='0000000001' and substr(bukrs,1,2)='EX')  --add by cwz 20240105 目前存在利润中心为1公司代码为EX03顺航系的数据 20240305确认不加
       ) 
   ----and concat(t1.copa_kostl,nvl(t2.ac_doc_typ,'XXX')) <> 'EX00028XXX'
   and case when '${v_month}'<'202203' then concat(t1.copa_kostl,nvl(t2.ac_doc_typ,'XXX')) <> 'EX00028XXX' else 1=1 end   --add by 20220406 21年财务部成本中心变更为EX00028，设置不取凭证类型为空的条目（详见21年6月22日邮件-"财务费用-经营财报ABC取数逻辑（ex00028、ex00205 ）"），22年1月始EX00028财务费用不再通过管理账划走，但是1 2月份仍沿用前述规则，在3月正式限制条件，不再沿用该规则
   and concat(t1.gjahr, substr(t1.perde, 2, 2)) = '${v_month}'
   and t1.paledger = '01'
   and case when concat(t1.gjahr, substr(t1.perde, 2, 2)) = '201911' then nvl(t1.vrgar, 'XXX') <> '8' else 
   1=1 end
   and case when concat(t1.gjahr, substr(t1.perde, 2, 2)) >= '202107' then nvl(t1.bukrs, 'XXX') <> 'SEI1' else 
   1=1 end        --add by cwz 20210805
   and case when concat(t1.gjahr, substr(t1.perde, 2, 2)) >= '202410' then nvl(t1.bukrs, 'XXX') <> 'SFE1' else 
   1=1 end        --add by cwz 20241105 8K项目的公司代码   
   ;
   

----step3：管理帐调整
drop table if exists tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02_1;
create table tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02_1 stored as parquet as
    select voucher_number from (
        select
            bukrs company_code
            ,crmcsty acco_code
            ,concat(t1.gjahr, substr(t1.perde, 2, 2)) month
            ,belnr voucher_number
            ,count(distinct copa_kostl) as cost_center_cnt --成本中心个数
            ,count(case copa_kostl when '0000000001' then copa_kostl else null end) as cost_1_cnt --统计成本中心为1的数量
        from
            ods_sap_fico.ce1sf00 t1
        where
             concat(t1.gjahr, substr(t1.perde, 2, 2)) = '${v_month}'
            and t1.paledger = '01'
            and t1.mandt = '800'
            and bukrs = 'EX01'
            and crmcsty = '6601020500'
        group by
            bukrs    --公司代码
            ,crmcsty      --会计科目
            ,concat(t1.gjahr, substr(t1.perde, 2, 2))
            ,belnr
    ) t
    where (cost_1_cnt>0 and cost_center_cnt>=3) or (cost_1_cnt=0 and cost_center_cnt>=2)
    group by voucher_number;
  
   
   
----step3：管理帐调整
drop table if exists tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02;
create table tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02 stored as parquet as
select a.month,
       a.profit_code,
       a.company_code,
       a.cost_center,
       a.voucher_number,
       a.voucher_type,
       a.voucher_desc,
       case
         when a.acco_code = '6401011500' and a.voucher_desc like '%营养保健费%' and
              a.company_code = 'EX01' and a.cost_center = 'EX00004' then
          '6401010100'
         when '${v_month}' <= '202003' and a.acco_code = '6401150100' and
              a.company_code = 'EX01' and (a.voucher_desc like '%扣款信息%' or a.voucher_desc like '%||员工往来%') then
          '6051010003'
         else
          a.acco_code
       end acco_code,
       a.func_code,
       case
         when a.acco_code = '6401011500' and a.voucher_desc like '%营养保健费%' and
              a.company_code = 'EX01' and a.cost_center = 'EX00004' and
              (a.intern_code = '' or a.intern_code = ' ' or
              a.intern_code is null) then
          'ALL'
         else
          a.intern_code
       end intern_code,
       a.base_currency,
       case
         when '${v_month}' <= '202003' and a.acco_code = '6401150100' and
              a.company_code = 'EX01' and (a.voucher_desc like '%扣款信息%' or a.voucher_desc like '%||员工往来%') then
          -a.base_currency_amt
         else
          a.base_currency_amt
       end base_currency_amt,
       a.post_date,
       'SYSTEM' dest_type,
       case
         when b.comp_code is not null and a.profit_code in ('SF027H','EX00028') and
              a.doc_currcy = 'CNY' and
              a.acco_code in ('6603030200', '6603030100') then
          -1
         when e.voucher_number is not null then
          -1
         when a.acco_code in ('6001030102',
                              '6001030101',
                              '6401030201',
                              '6401030202',
                              '6401030203',
                              '6401030204',
                              '6401030213') and a.company_code = 'EX01' then
          -1
         when a.acco_code = '6401012000' then
          -1
         when b.comp_code is not null and
              a.acco_code in ('6401180100', '6001070100') then
          -1
         when a.acco_code = '6401011500' and a.voucher_desc like '%营养保健费%' and
              a.company_code = 'EX01' and a.cost_center = 'EX00004' then
          2
         when '${v_month}' <= '202003' and a.acco_code = '6401150100' and
              a.company_code = 'EX01' and (a.voucher_desc like '%扣款信息%' or a.voucher_desc like '%||员工往来%') then
          2
          when a.acco_code in ('6601370000', '6601020500') and
              a.company_code = 'EX01' and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type = '' or a.voucher_type = ' ' or
              a.voucher_type is null) and (f.voucher_number is not null or g.voucher_number is not null) then
          2
--         when a.acco_code in ('6601370000', '6601020500') and
--              a.company_code = 'EX01' and
--              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
--              (a.voucher_type = '' or a.voucher_type = ' ' or
--              a.voucher_type is null) then
--          -1                                                               --add by cwz 20240305注释掉
         when a.acco_code in ('6601020500') and
              a.company_code = 'EX01' and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type = '' or a.voucher_type = ' ' or
              a.voucher_type is null) then                                   --add by cwz 20240305 6601020500 保持跟旧的不变
          -1
         when a.acco_code in ('6601370000') and
              a.company_code = 'EX01' and
              nvl(a.cost_center, 'XXX') not in ('SF027H') and
              (a.voucher_type = '' or a.voucher_type = ' ' or
              a.voucher_type is null) and substr(remark,1,1)='9' then       --add by cwz  20240305 科目6601370000 并且凭证号9开头的不进行计算
          -1
         when a.acco_code in ('6601370000', '6601020500') and
              a.company_code = 'EX01' and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type <> '' and a.voucher_type <> ' ' and
              a.voucher_type is not null) then
          2
         when a.acco_code = '6601370000' and b.comp_code is not null and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type = '' or a.voucher_type = ' ' or
              a.voucher_type is null) then
          -1
         when a.acco_code = '6601370000' and b.comp_code is not null and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type <> '' and a.voucher_type <> ' ' and
              a.voucher_type is not null) then
          2
         when a.acco_code = '6601370000' and b.comp_code is null and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              nvl(a.company_code, 'XXX') <> 'EX01' then
          -1
         when substr(a.acco_code, 1, 4) in ('6403', '6603') and
              a.company_code = 'EX01' and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type = '' or a.voucher_type = ' ' or
               a.voucher_type is null) then
          -1
         when substr(a.acco_code, 1, 4) in ('6403', '6603') and
              a.company_code = 'EX01' and
              nvl(a.cost_center, 'XXX') not in ('SF027H','EX00028') and
              (a.voucher_type <> '' and a.voucher_type <> ' ' and
               a.voucher_type is not null) then
          2
         when a.profit_code  in ('SF027H','EX00028') and b.comp_code is null and nvl(a.company_code, 'XXX') <> 'EX01' then 
         -1
         else
          1
       end gb_type,
       a.remark,
       a.alloc_nmbr
  from dm_air_dw.air_abc_fact_acco_sap_initial a
  left join (select trim(comp_code) comp_code
               from dm_air_dw.air_abc_rel_air_port_city_code
              where trim(comp_type) = 'SPV'
                and to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')
              group by trim(comp_code)) b
    on a.company_code = b.comp_code
  left join (select trim(cost_code) cost_code, cost_name
               from dm_air_dw.air_abc_rel_air_port_city_code
              where to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')
              group by trim(cost_code), cost_name) d
    on a.cost_center = d.cost_code
  left join (select voucher_number
               from dm_air_dw.air_abc_fact_acco_sap_initial
              where inc_month = '${v_month}'
                and month = '${v_month}'
                and substr(acco_code, 1, 4) in ('6605','6401') --20241205 剔除6401开头也是研发费用的凭证
                and company_code = 'EX01'
                and voucher_desc like '%调整%'
                and voucher_desc like '%研发费用%'
                and case when '${v_month}' = '201912' and voucher_desc like '%调整冲销19年1-11月研发费用%' 
                then 1=0
                when '${v_month}' = '201912' and voucher_desc like '%调整19年1-11月研发费用--分项目%' 
                then 1=0
                else 
                1=1 end
              group by voucher_number) e
    on a.voucher_number = e.voucher_number
  left join tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02_1 f
  on a.voucher_number = f.voucher_number  
    left join tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02_1 g
  on a.remark = g.voucher_number  
 where a.inc_month = '${v_month}'
   and a.month = '${v_month}';


----step2：数据写入SAP资源总账源数据表_管理帐调整后 
 insert overwrite table dm_air_dw.air_abc_fact_acco_sap partition
  (inc_type = 'SYSTEM', inc_month = '${v_month}')
select a.month,
       a.profit_code,
       a.company_code,
       a.cost_center,
       c.cost_name cost_center_name,
       a.voucher_number,
       a.voucher_type,
       a.voucher_desc,
       a.acco_code,
       b.acco_name acco_code_name,
       a.func_code,
       a.intern_code,
       a.base_currency,
       a.base_currency_amt,
       a.post_date,
       a.gb_type, --(-1:删除,1不变,2调整)
       a.dest_type,
       a.remark,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm,
       a.alloc_nmbr
  from tmp_dm_air_dw.air_abc_fact_acco_sap_initial_tmp02 a
  left join (select trim(acco_code) acco_code, acco_name
               from dm_air_dw.air_abc_rel_acco
              group by trim(acco_code), acco_name) b
    on a.acco_code = b.acco_code
  left join (select trim(cost_code) cost_code, cost_name
               from dm_air_dw.air_abc_rel_air_port_city_code
              where to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')
              group by trim(cost_code), cost_name) c
    on a.cost_center = c.cost_code;
        