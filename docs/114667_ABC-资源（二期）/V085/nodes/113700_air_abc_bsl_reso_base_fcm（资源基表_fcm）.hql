-- /***************************************************************************
-- Copyright 2022 sf-express.com Inc. All rights reserved.
-- Taskname: air_abc_bsl_reso_base_fcm(资源基表_fcm)
-- Description：数据主要来源为成本预提、发票业务、预提调整费用,通过关联汇率、成本要素、资源转换等逻辑处理生成FCM资源归集费用,支撑财务abc计算fcm的账务费用
-- Source: dwd_sh_fin_cost_af_fymx_dtl_mf  dwd_sh_fin_cost_af_ytcbmx_dtl_mf
-- Author: 刘直 2019
-- HISTORY
-- ***************************************************************************
-- ID DATE MODIFY MODIFIER REASON
-- 1  2019         刘直 Create
-- 2  2021-07-09 01393364 陈维镇 Modify 剔除滑行航班H 不计入成本
-- 3  2021-10-10 01393364 陈维镇 Modify FCM录错账单 101074896  修改为 101078879  何林畴要求修改
-- 4  2021-10-14 01393364 陈维镇 Modify FCM_无航班资源（02）分摊规则重述   修改为在对应机型的FCM_有航班（01）资源的航班范围内按航班量均摊
-- 5  2022-07-29 01393364 陈维镇 Modify FCM费用id对应成本中心关系表 ods_air_fcm.v_fycbzx 每次都是取最新的数据不满足  EX00011在20220729已经发现为EX00029,但跟用户确认202206还是属于EX00011的  比如ZY051_01
-- 6  2022-08-26 01393364 陈维镇 Modify  FCM前置跑数
-- 7  2022-10-09 01393364 陈维镇 Modify 胡洁要求注释掉 ZY021_02 ZY030_02  ZY060_02 以前金鹏湿租起降费用不由航空承担  现在可以由航空承担  注释是有可能会导致金鹏航班进入A01 以后自有航班FCM_02费用 也可能会包含金鹏在内的
-- 8  2021-10-10 01393364 陈维镇 Modify FCM录错账单 101986863  修改为 101908884  hujie要求修改
-- 9  2023-04-10 01393364 陈维镇 Modify ods_air_fcm.v_bdp_ytcbmx切换为dwd_sh.dwd_sh_fin_cost_af_ytcbmx_dtl_mf
-- 10 2023-04-25 01393364 陈维镇 Modify 资源分摊逻辑设置成2019年1月1日-2022年6月只在自有航班分摊，22年7月开始不再对航班性质作限制 添加月份限制条件  t1.month>='201901' and t1.month<='202206'  优化前('ZY009_02','ZY127_02','ZY048_02','ZY050_02','ZY051_02') 龙浩航班都会记录至_02资源    优化后 龙浩账单是当月和当月飞的航班 会记录至对应的_01资源
-- 11 2024-01-04 01393364 陈维镇 Modify ods_air_fcm.v_bdp_fymx切换为dwd_sh.dwd_sh_fin_cost_af_fymx_dtl_mf
-- 12 2024-03-14 01393364 陈维镇 Modify  国际航班航班号为3位数或4位数，例如O33123，O31234。 特殊情况下会有例如 O312Z，O3123Z       [因为有些航班号长度是5位且是J结尾的要保留之前的判断逻辑 符合小于6位范围,如果FCM直接传3位数的航班号也满足此判断逻辑]
--                                       国内航班为4位数，包含数字和字母，例如O31234， 补班航班的航班号最后一位为字母，例如O3123V {0,1,2,3,4,5,6,7,8,9}分别对应更改为{Z,Y,X,W,V,U,T,S,R,Q}
-- 13 2025-01-09 01393364 陈维镇 Modify  B73N任务改造 asset_classify_desc
-- 14 2026-06-05 01393364 陈维镇 Modify flight_id 102494396 修改为 102490311 修改内部订单
-- ***************************************************************************/
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

--链接数据库
use dm_air_dw;

--#####################################################################
--step1.FCM明细费用（发票业务明细、预提调整明细）按总账会计期间处理数据
--凭证总账没有转换汇率值，直接取明细币种,凭证总账有转换汇率值,按转换汇率把明细的币种转换为总账币种。
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_01;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_01 stored as parquet as
select t01.zdqj, t01.f_zdid
               from (select regexp_replace(substr(a01.f_date, 1, 7), '-', '') zdqj,
                            a01.f_zdid
                       from dm_air_dw.air_abc_fact_zw_pzxx a01
                      where a01.f_pzzbid not in
                            (select distinct t02.f_oldpzzbid
                               from dm_air_dw.air_abc_fact_zw_pzxx t02
                              where t02.f_oldpzzbid is not null and t02.f_voucher_id is not null and t02.f_ywlb = '冲销凭证')
                        and a01.f_oldpzzbid is null
                        and substr(a01.f_account_code, 1, 2) = '64'
                        and a01.inc_month = '${v_month}'
                        and nvl(a01.f_voucher_id,'XXX') not in ('XXX','',' ')
                        and regexp_replace(substr(a01.f_date, 1, 7), '-', '') =
                            '${v_month}'
                      group by regexp_replace(substr(a01.f_date, 1, 7),
                                              '-',
                                              ''),
                               a01.f_zdid) t01;

drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_02;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_02 stored as parquet as
select t02.zdqj, --账单期间
                    t02.f_zdid, --账单ID
                    t02.f_ywlbid,
                    t02.f_hbdm, --凭证货币代码
                    t02.exchange_rate, --凭证汇率
                    row_number() over(partition by t02.f_zdid,t02.f_ywlbid order by t02.exchange_rate desc) rn
               from (select regexp_replace(substr(t01.f_date, 1, 7), '-', '') as zdqj,--账单期间
                            t01.f_zdid,
                            t01.f_ywlbid,
                            t01.f_currency as f_hbdm, --凭证货币代码
                            regexp_extract(t01.f_pzh_oracle,
                                           '(.*)([\\(])(.*)',
                                           1) f_hbdm_pz, --明细货币类型(凭证汇率)
                            regexp_extract(t01.f_pzh_oracle,
                                           '(.*)([\\(])(.*)([\\)])',
                                           3) exchange_rate, --汇率
                            t01.inc_month
                       from dm_air_dw.air_abc_fact_zw_pzxx t01
                      where t01.f_pzzbid not in
                            (select distinct t.f_oldpzzbid
                               from dm_air_dw.air_abc_fact_zw_pzxx t
                              where t.f_oldpzzbid is not null and t.f_voucher_id is not null and t.f_ywlb = '冲销凭证')
                        and t01.f_oldpzzbid is null
                        and substr(t01.f_account_code, 1, 2) = '64'
                        --and t01.f_ywlbid = '2'
                        and t01.inc_month = '${v_month}'
                        and regexp_replace(substr(t01.f_date, 1, 7), '-', '') =
                            '${v_month}'
                      group by regexp_replace(substr(t01.f_date, 1, 7),
                                              '-',
                                              ''),
                               t01.f_zdid,
                               t01.f_ywlbid,
                               t01.f_currency,
                               regexp_extract(t01.f_pzh_oracle,
                                              '(.*)([\\(])(.*)',
                                              1),
                               regexp_extract(t01.f_pzh_oracle,
                                              '(.*)([\\(])(.*)([\\)])',
                                              3),
                               t01.inc_month) t02
              where nvl(t02.exchange_rate, 1) <> 1;

drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_03;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_03 stored as parquet as
select t02.zdqj, --账单期间
                    t02.f_zdid, --账单ID
                    t02.f_ywlbid,
                    t02.f_hbdm --凭证货币代码
               from (select regexp_replace(substr(t01.f_date, 1, 7), '-', '') as zdqj,--账单期间
                            t01.f_zdid,
                            t01.f_ywlbid,
                            t01.f_currency as f_hbdm, --凭证货币代码
                            t01.inc_month,
                            row_number() over(partition by t01.f_zdid,t01.f_ywlbid order by t01.inc_month desc) rn
                       from dm_air_dw.air_abc_fact_zw_pzxx t01
                      where t01.f_pzzbid not in
                            (select distinct t.f_oldpzzbid
                               from dm_air_dw.air_abc_fact_zw_pzxx t
                              where t.f_oldpzzbid is not null and t.f_voucher_id is not null and t.f_ywlb = '冲销凭证')
                        and t01.f_oldpzzbid is null
                        and substr(t01.f_account_code, 1, 2) = '64'
                        --and t01.f_ywlbid = '2'
                        and t01.inc_month = '${v_month}'
                        and regexp_replace(substr(t01.f_date, 1, 7), '-', '') =
                            '${v_month}'
                      group by regexp_replace(substr(t01.f_date, 1, 7),
                                              '-',
                                              ''),
                               t01.f_zdid,
                               t01.f_ywlbid,
                               t01.f_currency,
                               t01.inc_month) t02 where rn = 1;


drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01 stored as parquet as
  select t1.f_zdid, --账单ID
       t3.zdqj, --账单期间
       t1.hbh as flight_no, --航班号
       t1.hbrq as flight_date, --航班日期
       t1.qfsj as atd, --实际起飞时间
       t1.ddsj as ata, --实际到达时间
       t1.hx, --航线
       t1.hd, --航段
       t1.sfgz, --始发、过站、航后标识
       t1.ywbz, --延误标识
       t1.fsd, --费用发生地，机场名称
       t1.szm, --费用发生地，机场三字码
       t1.gys, --单位全称
       t1.fycj, --费用层级
       t1.fyfl, --费用分类
       t1.fymc, --费用名称
       t1.f_fymxid, --费用id
       t1.kmdm as acco_code, --会计科目
       t1.kmmc as acco_name, --会计科目名称
       t1.zdsl, --账单数量
       t1.zddj, --账单标准
       t1.zdje, --账单金额
       t1.xtsl, --试算账单数量
       t1.xtdj, --试算账单标准
       t1.xtje, --试算账单金额
       t1.sdsl, --最终审定账单数量
       t1.sddj, --最终申请账单标准
       t1.sdje, --最终审定账单金额
       t1.zzs, --作账的最终审定金额对应的增值税金
       t1.cb, --作账的最终审定金额对应的成本
       t1.f_bzid, --币种id
       t1.f_ytje, --预提金额
       t1.f_hbmc, --货币名称
       t1.f_hbdm, --货币代码
       t1.clzt,
       t1.shyj,
       t1.bz, --备注
       t1.hbh_rws, --航班号（任务书）
       t1.hbrq_rws, --航班日期（任务书）
       t1.hx_rws, --航线（任务书）
       t1.hd_rws, --航段（任务书）
       case
         when t2.exchange_rate is not null then
          t2.f_hbdm
         else
          t1.f_hbdm
       end as f_hbdm_pz_cb, --凭证货币代码
       case
         when t4.exchange_rate is not null then
          t4.f_hbdm
          when t5.f_hbdm is not null then t5.f_hbdm
         else
          t1.f_hbdm
       end as f_hbdm_pz_yt, --凭证货币代码
       nvl(t2.exchange_rate,1) exchange_rate_cb, --凭证汇率(发票业务)
       nvl(t4.exchange_rate,1) exchange_rate_yt, --凭证汇率(预提调整)
       t1.cb * nvl(t2.exchange_rate, 1) as cb_pz, --凭证成本（凭证币种）
       t1.f_ytje * nvl(t4.exchange_rate, 1) as f_ytje_pz --凭证预提金额（凭证币种）
  from   --dm_air_dw.v_bdp_fymx_bak1 t1   --临时方案 临时注释掉 20210705
            (--------select b01.*                                                                               --临时注释掉 20210608
             --------  from ods_air_fcm.v_bdp_fymx b01                                                          --临时注释掉 20210608
             --------  where case when '$[time(yyyyMM07)]'>='20220904' then b01.inc_day = '$[time(yyyyMM04)]'   --add by cwz 20220826
             --------             when '$[time(yyyyMM07)]'>='20210606' then b01.inc_day = '$[time(yyyyMM06)]'   --临时注释掉 20210608
             --------             when '$[time(yyyyMM07)]'>='20210307' then b01.inc_day = '$[time(yyyyMM07)]'   --临时注释掉 20210608
             --------        else b01.inc_day = '20210207' end             -- 20240104注释掉
        ------ inner join (select max(b02.inc_day) inc_day        废弃
        ------              from ods_air_fcm.v_bdp_fymx b02) b03
        ------    on b01.inc_day = b03.inc_day
        select b01.* from dwd_sh.dwd_sh_fin_cost_af_fymx_dtl_mf b01 where case when '$[time(yyyyMM04)]'>'20231204' then b01.inc_day = '$[time(yyyyMM04)]' else b01.inc_day = '20231204' end
            ) t1                                               --临时注释掉 20210608
 inner join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_01 t3
    on t1.f_zdid = t3.f_zdid
  left join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_02 t2
    on t1.f_zdid = t2.f_zdid
   and t2.f_ywlbid = '2'
   and t2.rn = 1
  left join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_02 t4
    on t1.f_zdid = t4.f_zdid
   and t4.f_ywlbid = '1'
   and t4.rn = 1
   left join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_03 t5
    on t1.f_zdid = t5.f_zdid
   and t5.f_ywlbid = '1'
 where t3.zdqj = '${v_month}';

--step2.FCM费用（发票业务明细、预提调整明细）按凭证总账的币种汇率转换为人民币
  drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp02 ;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp02 stored as Parquet as
 select t1.f_zdid, --账单ID
       t1.zdqj, --账单期间
       t1.flight_no, --航班号
       t1.flight_date, --航班日期
       t1.atd, --实际起飞时间
       t1.ata, --实际到达时间
       t1.hx, --航线
       t1.hd, --航段
       t1.sfgz, --始发、过站、航后标识
       t1.ywbz, --延误标识
       t1.fsd, --费用发生地，机场名称
       t1.szm, --费用发生地，机场三字码
       t1.gys, --单位全称
       t1.fycj, --费用层级
       t1.fyfl, --费用分类
       t1.fymc, --费用名称
       t1.f_fymxid, --费用id
       t1.acco_code, --会计科目
       t1.acco_name, --会计科目名称
       t1.zdsl, --账单数量
       t1.zddj, --账单标准
       t1.zdje, --账单金额
       t1.xtsl, --试算账单数量
       t1.xtdj, --试算账单标准
       t1.xtje, --试算账单金额
       t1.sdsl, --最终审定账单数量
       t1.sddj, --最终申请账单标准
       t1.sdje, --最终审定账单金额
       t1.zzs, --作账的最终审定金额对应的增值税金
       t1.cb, --作账的最终审定金额对应的成本
       t1.f_bzid, --币种id
       t1.f_ytje, --预提金额
       t1.f_hbmc, --货币名称
       t1.f_hbdm, --货币代码
       case
         when t1.f_hbdm_pz_cb = 'CNY' then
          1
         when d.fcurr = 'JPY' and d.ukurs > 0.3 then    --BDP汇率表日元转换率翻了10倍
          d.ukurs / 10
         else
          d.ukurs
       end as rate_cb, --汇率
       case
         when t1.f_hbdm_pz_yt = 'CNY' then
          1
         when c.fcurr = 'JPY' and c.ukurs > 0.3 then   --BDP汇率表日元转换率翻了10倍
          c.ukurs / 10
         else
          c.ukurs
       end as rate_yt, --汇率
       t1.clzt,
       t1.shyj,
       t1.bz, --备注
       t1.hbh_rws, --航班号（任务书）
       t1.hbrq_rws, --航班日期（任务书）
       t1.hx_rws, --航线（任务书）
       t1.hd_rws, --航段（任务书）
       t1.f_hbdm_pz_cb, --凭证货币代码
       t1.f_hbdm_pz_yt, --凭证货币代码
       t1.exchange_rate_cb, --凭证汇率
       t1.exchange_rate_yt, --凭证汇率
       t1.cb_pz, --凭证成本（凭证币种）
       t1.f_ytje_pz --凭证预提金额（凭证币种）
  from tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01 t1
  left join (select * from ods_sap.tcurr
                 where inc_day = '${v_date}'
                   and tcurr = 'CNY'
                   and kurst = 'M') d
    on t1.f_hbdm_pz_cb = d.fcurr
   and t1.zdqj = substr(cast(99999999 - d.gdatu as int), 1, 6)
  left join (select * from ods_sap.tcurr
                 where inc_day = '${v_date}'
                   and tcurr = 'CNY'
                   and kurst = 'M') c
    on t1.f_hbdm_pz_yt = c.fcurr
   and t1.zdqj = substr(cast(99999999 - c.gdatu as int), 1, 6);



--step3.FCM费用（发票业务明细、预提调整明细）对应航班ID
--与航班费用信息通过关联航班号、实际出发时间、实际到达时间唯一确定一个航班--
insert overwrite table dm_air_dw.air_abc_bsl_reso_base_fcm_cb partition
  (inc_month = '${v_month}')
 select trim(t1.zdqj) as month, --会计期间
       case when t3.flight_id='102478937' then '102476348'   -- add by cwz 20260408 修改内部订单
        when t3.flight_id='102487970' then '102487868'   -- add by cwz 20260508 修改内部订单
        when t3.flight_id='102494396' then '102490311'   -- add by cwz 20260605 修改内部订单
       else t3.flight_id end as flight_id, --航班ID
       t3.std, --航班计划起飞时间
       t3.departure_airport_3code, --起飞机场3字码
       t3.arrival_airport_3code, --落地机场3字码
       t1.f_zdid, --账单ID
       t1.zdqj, --账单期间
       t1.flight_no, --航班号
       t1.flight_date, --航班日期
       t1.atd, --实际起飞时间
       t1.ata, --实际到达时间
       t1.hx, --航线
       t1.hd, --航段
       t1.sfgz, --始发、过站、航后标识
       t1.ywbz, --延误标识
       t1.fsd, --费用发生地，机场名称
       case when t4.airport_3code is not null then t4.airport_3code_a
            else t1.szm end as szm, --费用发生地，机场三字码
       t1.gys, --单位全称
       t1.fycj, --费用层级
       t1.fyfl, --费用分类
       t1.fymc, --费用名称
       t1.f_fymxid, --费用id
       t1.acco_code, --会计科目
       t1.acco_name, --会计科目名称
       t1.zdsl, --账单数量
       t1.zddj, --账单标准
       t1.zdje, --账单金额
       t1.xtsl, --试算账单数量
       t1.xtdj, --试算账单标准
       t1.xtje, --试算账单金额
       t1.sdsl, --最终审定账单数量
       t1.sddj, --最终申请账单标准
       t1.sdje, --最终审定账单金额
       t1.zzs, --作账的最终审定金额对应的增值税金
       t1.cb, --作账的最终审定金额对应的成本
       t1.f_bzid, --币种id
       t1.f_ytje, --预提金额
       t1.f_hbmc, --货币名称
       t1.f_hbdm, --货币代码
       t1.rate_cb, --汇率
       t1.rate_yt, --汇率
       t1.clzt,
       t1.shyj,
       t1.bz, --备注
       t1.hbh_rws, --航班号（任务书）
       t1.hbrq_rws, --航班日期（任务书）
       t1.hx_rws, --航线（任务书）
       t1.hd_rws, --航段（任务书）
       t1.f_hbdm_pz_cb, --凭证货币代码
       t1.f_hbdm_pz_yt, --凭证货币代码
       t1.exchange_rate_cb, --凭证汇率
       t1.exchange_rate_yt, --凭证汇率
       t1.cb_pz, --凭证成本（凭证币种）
       t1.f_ytje_pz, --凭证预提金额（凭证币种）
       t1.f_ytje_pz * t1.rate_yt as f_ytje_cny, --预提人民币金额
       t1.cb_pz * t1.rate_cb as cb_cny, --成本人民币金额
       (nvl(t1.cb_pz, 0) * t1.rate_cb) - (nvl(t1.f_ytje_pz, 0) * t1.rate_yt)  as cny_atm, --人民币金额
       t3.fuel_on_time flight_type, --航班类型：A01航空自有航班,A02龙浩湿租,A03金鹏湿租,A04外部非5Y航班，A05外部5Y航班
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间
  from tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp02 t1
     left join tmp_dm_air_dw.air_abc_fact_flight_info_t7001 t4
            on t1.szm = t4.airport_3code
  left join (select t2.flight_id,
                    t2.flight_no,
                    t2.atd,
                    t2.ata,
                    t2.std,
                    t2.departure_airport_3code,
                    t2.arrival_airport_3code,
                    t2.fuel_on_time
               from (select t.flight_id,
                            t.flight_no,
                            trim(t.atd) atd,
                            trim(t.ata) ata,
                            t.std,
                            t.departure_airport_3code,
                            t.arrival_airport_3code,
                            t.fuel_on_time,
                            row_number() over(partition by t.flight_no, trim(t.atd), trim(t.ata) order by t.flight_id desc) rn
                       from dm_air_dw.air_abc_fact_flight_info t
                      where t.inc_month = '${v_month}'
                      and nvl(t.flg_cs, 'XXX') not in ('C', 'D')
                      and nvl(t.adjust_type, 'XXX') not in ('V', 'R') and t.flight_type <> 'H' ) t2  --add by cwz 20210709 剔除滑行航班 不计入成本
              where t2.rn = 1) t3
    on regexp_replace(trim(t1.hbh_rws), '[J]$', '') = trim(t3.flight_no)
   and trim(t1.atd) = trim(t3.atd)
   and trim(t1.ata) = trim(t3.ata)
   and t3.atd is not null
   and t3.ata is not null;


--step4.FCM费用明细（成本预提）按总账会计期间
--凭证总账没有转换汇率值，直接取明细币种,凭证总账有转换汇率值,按转换汇率把明细的币种转换为总账币种。
 drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp04 ;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp04 stored as Parquet as
select substr(t1.f_rq, 1, 10) as f_rq, --航班日期
       t3.zdqj, --账单期间
       t1.f_yrq, --预提日期
       t1.f_hbbh, --航班号
       t1.f_hbxz, --航班性质
       t1.f_fjjh, --飞机号
       t1.f_hxbh, --航线
       t1.f_hxlx, --航线类型
       t1.f_hdbh, --航段
       t1.f_hdlx, --航段类型
       t1.f_jxid, --机型ID
       t1.f_fyid, --费用ID
       t1.f_jsdwid, --单位ID
       t1.f_hbid, --货币ID
       t1.f_hbmc, --货币名称
       t1.f_hbdm, --货币代码
       t1.f_hbid_hl, --汇率
       t1.f_fsd, --发生地
       t1.f_fsdlx, --发生地类型
       t1.f_flg_vr1, --为备降和返航航班的区分标识VC和RC表示原航段V1/V2和R1/R2表示实际执行的两个航段。1表示第1段，2表示第2段
       t1.f_ytlb, --预提类别
       t1.f_ytsl, --预提数量
       t1.f_ytbz, --预提标准
       t1.f_zzsl, --增值税率
       t1.f_sjje, --实际不含税金额(原币)
       t1.f_ysdh, --原始单号(油单号)
       t1.f_rzbz, --表示本月预提需要生成凭证的数据(便于当月已结算的不通过预提凭证进成本)
       t1.f_ytfyfl, --预提费用分类
       t1.mxzd_id, --费用明细账单ID
       t1.f_zdmxid, --账单明细ID
       t1.f_ytmxid, --预提明细ID
       t1.fycj, --费用层级
       t1.fyfl, --费用分类
       t1.fymc, --费用名称
       t1.f_ywlb, --业务类别ID
       t1.f_ywlbmc, --业务类别名称
       t1.f_pzflid, --凭证分类ID
       t1.f_pzflmc, --凭证分类名称
       t1.cbyt_pz_id, --成本预提凭证ID
       t1.kmdm acco_code, --科目代码
       case
         when t2.exchange_rate is not null then
          t2.f_hbdm
         else
          t1.f_hbdm
       end as f_hbdm_pz, --凭证货币代码
       t2.exchange_rate, --凭证汇率
       t1.f_sjje * nvl(t2.exchange_rate, 1) as f_sjje_pz --凭证金额(原币)（凭证币种）
  from (----select b01.*
        ----  from ods_air_fcm.v_bdp_ytcbmx b01
        ----  where case when '$[time(yyyyMM07)]'>='20220904' then b01.inc_day = '$[time(yyyyMM04)]'   --add by cwz 20220826
        ----             when '$[time(yyyyMM07)]'>='20210606' then b01.inc_day = '$[time(yyyyMM06)]'
        ----             when '$[time(yyyyMM07)]'>='20210307' then b01.inc_day = '$[time(yyyyMM07)]'
        ----        else b01.inc_day = '20210207' end                   --20230410注释掉

   --      inner join (select max(b02.inc_day) inc_day
   --                   from ods_air_fcm.v_bdp_ytcbmx b02) b03
   --         on b01.inc_day = b03.inc_day
         select b01.* from dwd_sh.dwd_sh_fin_cost_af_ytcbmx_dtl_mf b01 where b01.inc_day = '$[time(yyyyMM04)]' and b01.etl_flag=1
            ) t1
 inner join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_01 t3
    on t1.cbyt_pz_id = t3.f_zdid
  left join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp01_02 t2
    on t1.cbyt_pz_id = t2.f_zdid
   and t2.f_ywlbid = '3'
   and t2.rn = 1
 where t3.zdqj = '${v_month}';

--step5.FCM费用明细（成本预提）按汇率转换为人民币
 drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp05 ;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp05 stored as Parquet as
select t1.f_rq, --航班日期
       t1.zdqj, --账单期间
       t1.f_yrq, --预提日期
       t1.f_hbbh, --航班号
       t1.f_hbxz, --航班性质
       t1.f_fjjh, --飞机号
       t1.f_hxbh, --航线
       t1.f_hxlx, --航线类型
       t1.f_hdbh, --航段
       t1.f_hdlx, --航段类型
       t1.f_jxid, --机型ID
       t1.f_fyid, --费用ID
       t1.f_jsdwid, --单位ID
       t1.f_hbid, --货币ID
       t1.f_hbmc, --货币名称
       t1.f_hbdm, --货币代码
       t1.f_hbid_hl, --汇率
       t1.f_fsd, --发生地
       t1.f_fsdlx, --发生地类型
       t1.f_flg_vr1, --为备降和返航航班的区分标识VC和RC表示原航段V1/V2和R1/R2表示实际执行的两个航段。1表示第1段，2表示第2段
       t1.f_ytlb, --预提类别
       t1.f_ytsl, --预提数量
       t1.f_ytbz, --预提标准
       t1.f_zzsl, --增值税率
       t1.f_sjje, --实际不含税金额(原币)
       case
         when t1.f_hbdm_pz = 'CNY' then
          1
         when d.fcurr = 'JPY' and d.ukurs > 0.3 then    --BDP汇率表日元转换率翻了10倍
          d.ukurs / 10
         else
          d.ukurs
       end as rate, --转换为人民币汇率
       t1.f_ysdh, --原始单号(油单号)
       t1.f_rzbz, --表示本月预提需要生成凭证的数据(便于当月已结算的不通过预提凭证进成本)
       t1.f_ytfyfl, --预提费用分类
       t1.mxzd_id, --费用明细账单ID
       t1.f_zdmxid, --账单明细ID
       t1.f_ytmxid, --预提明细ID
       t1.fycj, --费用层级
       t1.fyfl, --费用分类
       t1.fymc, --费用名称
       t1.f_ywlb, --业务类别ID
       t1.f_ywlbmc, --业务类别名称
       t1.f_pzflid, --凭证分类ID
       t1.f_pzflmc, --凭证分类名称
       t1.cbyt_pz_id, --成本预提凭证ID
       t1.f_hbdm_pz, --凭证货币代码
       t1.acco_code, --科目代码
       t1.exchange_rate, --凭证汇率
       t1.f_sjje_pz --凭证金额(原币)（凭证币种）
  from tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp04 t1
  left join (select * from ods_sap.tcurr
                 where inc_day = '${v_date}'
                   and tcurr = 'CNY'
                   and kurst = 'M') d
    on t1.f_hbdm_pz = d.fcurr
   and t1.zdqj = substr(cast(99999999 - d.gdatu as int), 1, 6);


 insert into table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp05
   select t1.flight_date f_rq, --航班日期
       t1.month zdqj, --账单期间
       cast(null as string) f_yrq, --预提日期
       t1.flight_no f_hbbh, --航班号
       cast(null as string) f_hbxz, --航班性质
       t1.ac_reg f_fjjh, --飞机号
       t1.flight_hx f_hxbh, --航线
       cast(null as string) f_hxlx, --航线类型
       t1.flight_sect f_hdbh, --航段
       cast(null as string) f_hdlx, --航段类型
       cast(null as string) f_jxid, --机型ID
       cast(null as string) f_fyid, --费用ID
       cast(null as string) f_jsdwid, --单位ID
       cast(null as string) f_hbid, --货币ID
       cast(null as string) f_hbmc, --货币名称
       cast(null as string) f_hbdm, --货币代码
       cast(null as string) f_hbid_hl, --汇率
       t1.dept_thr_code f_fsd, --发生地
       t1.dept_thr_type f_fsdlx, --发生地类型
       cast(null as string) f_flg_vr1, --为备降和返航航班的区分标识VC和RC表示原航段V1/V2和R1/R2表示实际执行的两个航段。1表示第1段，2表示第2段
       cast(null as string) f_ytlb, --预提类别
       cast(null as string) f_ytsl, --预提数量
       cast(null as string) f_ytbz, --预提标准
       cast(null as string) f_zzsl, --增值税率
       cast(null as string) f_sjje, --实际不含税金额(原币)
       1 rate, --转换为人民币汇率
       cast(null as string) f_ysdh, --原始单号(油单号)
       cast(null as string) f_rzbz, --表示本月预提需要生成凭证的数据(便于当月已结算的不通过预提凭证进成本)
       cast(null as string) f_ytfyfl, --预提费用分类
       cast(null as string) mxzd_id, --费用明细账单ID
       cast(null as string) f_zdmxid, --账单明细ID
       cast(null as string) f_ytmxid, --预提明细ID
       cast(null as string) fycj, --费用层级
       '线下手工冲减' fyfl, --费用分类
       t1.fcm_type fymc, --费用名称
       cast(null as string) f_ywlb, --业务类别ID
       cast(null as string) f_ywlbmc, --业务类别名称
       cast(null as string) f_pzflid, --凭证分类ID
       cast(null as string) f_pzflmc, --凭证分类名称
       cast(null as string) cbyt_pz_id, --成本预提凭证ID
       'CNY' f_hbdm_pz, --凭证货币代码
       t1.acti_code acco_code, --科目代码
       cast(null as string) exchange_rate, --凭证汇率
       -t1.reso_amt f_sjje_pz --凭证金额(原币)（凭证币种）
   from dm_air_dw.air_abc_fact_reso_fcm_upload t1
   where t1.inc_month = '${v_month}' and t1.month = '${v_month}';


--step6.FCM费用明细（成本预提）带出对应的航班ID
insert overwrite table dm_air_dw.air_abc_bsl_reso_base_fcm_yt partition
  (inc_month = '${v_month}')
select trim(t1.zdqj) as month, --会计期间
       case when t3.flight_id='101074896' then '101078879'   -- add by cwz 20211010 修改内部订单
            when t3.flight_id='101986863' then '101908884'   -- add by cwz 20230209 修改内部订单
       else t3.flight_id end as flight_id, --航班ID
       t3.std, --航班计划起飞时间
       t3.departure_airport_3code, --起飞机场3字码
       t3.arrival_airport_3code, --落地机场3字码
       t1.f_rq, --航班日期
       t1.zdqj, --账单期间
       t1.f_yrq, --预提日期
       t1.f_hbbh, --航班号
       t1.f_hbxz, --航班性质
       t1.f_fjjh, --飞机机号
       t1.f_hxbh, --航线(三字码)
       t1.f_hxlx, --航线类型(0-国内，1-国际，2-地区)
       --t1.f_hdbh, --航段(三字码)
       case when t5.airport_3code is not null and t6.airport_3code is not null then concat(t5.airport_3code_a,'-',t6.airport_3code_a)
            when t5.airport_3code is not null then concat(t5.airport_3code_a,'-',substr(t1.f_hdbh,-3))
            when t6.airport_3code is not null then concat(substr(t1.f_hdbh,1,3),'-',t6.airport_3code_a)
            else t1.f_hdbh end f_hdbh, --航段(三字码)
       t1.f_hdlx, --航段类型(0-国内，1-国际，2-地区)
       t1.f_jxid, --机型id
       t1.f_fyid, --费用id
       t1.f_jsdwid, --结算单位id
       t1.f_hbid, --货币id
       t1.f_hbmc, --货币名称
       t1.f_hbdm, --货币代码
       t1.f_hbid_hl, --货币id对应的汇率
           case when t4.airport_3code is not null then t4.airport_3code_a
            else t1.f_fsd end as f_fsd, --费用发生地，机场三字码
       t1.f_fsdlx, --发生地类型
       t1.f_flg_vr1, --为备降和返航航班的区分标识vc和rc表示原航段v1/v2和r1/r2表示实际执行的两个航段。1表示第1段，2表示第2段
       t1.f_ytlb, --预提类别(1预提计算、2当月结算(新增的)，3当月结算调整(update))
       t1.f_ytsl, --预提数量
       t1.f_ytbz, --预提标准
       t1.f_zzsl, --增值税率
       t1.f_sjje, --实际不含税金额(原币)
       t1.rate, --转换为人民币汇率
       t1.f_ysdh, --原始单号(油单号)
       t1.f_rzbz, --表示本月预提需要生成凭证的数据(便于当月已结算的不通过预提凭证进成本)
       t1.F_YTFYFL, --预提费用分类id
       t1.mxzd_id, --账单id
       t1.f_zdmxid, --账单明细id
       t1.f_ytmxid, --预提明细id
       t1.fycj, --费用层级
       t1.fyfl, --费用分类
       t1.fymc, --费用名称
       t1.f_ywlb, --业务类别
       t1.f_ywlbmc, --业务类别名称
       t1.f_pzflid, --凭证分类ID
       t1.f_pzflmc, --凭证分类名称
       t1.cbyt_pz_id, --账单ID
       t1.acco_code, --科目代码
       t1.f_hbdm_pz, --凭证货币代码
       t1.exchange_rate, --凭证汇率
       t1.f_sjje_pz, --凭证金额(原币)（凭证币种）
       t1.f_sjje_pz * t1.rate as cny_atm, --人民币金额
       t3.fuel_on_time flight_type, --航班类型：A01航空自有航班,A02龙浩湿租,A03金鹏湿租,A04外部非5Y航班，A05外部5Y航班
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间
  from tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp05 t1
     left join tmp_dm_air_dw.air_abc_fact_flight_info_t7001 t4
            on t1.f_fsd = t4.airport_3code
     left join tmp_dm_air_dw.air_abc_fact_flight_info_t7001 t5
            on substr(t1.f_hdbh,1,3) = t5.airport_3code
     left join tmp_dm_air_dw.air_abc_fact_flight_info_t7001 t6
            on substr(t1.f_hdbh,-3) = t6.airport_3code
  left join (select t2.flight_id,
                    t2.flight_date,
                    t2.flight_no,
                    t2.flight_sect,
                    t2.ac_reg,
                    t2.std,
                    t2.departure_airport_3code,
                    t2.arrival_airport_3code,
                    t2.fuel_on_time
               from (select t.flight_id,
                            substr(t.flight_date, 1, 10) flight_date,
                            t.flight_no,
                            t.flight_sect,
                            t.ac_reg,
                            t.std,
                            t.departure_airport_3code,
                            t.arrival_airport_3code,
                            t.fuel_on_time,
                            row_number() over(partition by substr(t.flight_date, 1, 10), t.flight_no, flight_sect, t.ac_reg order by t.flight_id desc) rn
                       from dm_air_dw.air_abc_fact_flight_info t
                      where t.inc_month = '${v_month}'
                      and nvl(t.flg_cs, 'XXX') not in ('C', 'D')
                      and nvl(t.adjust_type, 'XXX') not in ('V', 'R')
                      and t.flight_type <> 'H'     --add by cwz 20210709 剔除滑行航班 不计入成本
                      ) t2
              where t2.rn = 1) t3
    on t1.f_rq = t3.flight_date
   --and substr(regexp_replace(t1.f_hbbh, '[J]$', ''), -4) =substr(t3.flight_no, -4)  --20240315注释掉
   and case when length(regexp_replace(t1.f_hbbh, '[J]$', ''))=6 then substr(regexp_replace(t1.f_hbbh, '[J]$', ''),3,6) else regexp_replace(t1.f_hbbh, '[J]$', '') end= substr(t3.flight_no, 3,6)   --add by cwz 20240315 如果是Y87911 Y87912则从第3位取到最后 否则就替换掉J结尾直接取剩下的,目前都是4位长度 202403以后会存在3位长度
   and case when t5.airport_3code is not null and t6.airport_3code is not null then concat(t5.airport_3code_a,'-',t6.airport_3code_a)
            when t5.airport_3code is not null then concat(t5.airport_3code_a,'-',substr(t1.f_hdbh,-3))
            when t6.airport_3code is not null then concat(substr(t1.f_hdbh,1,3),'-',t6.airport_3code_a)
            else t1.f_hdbh end = t3.flight_sect
   and t1.f_fjjh = substr(t3.ac_reg, -4);

--step7.FCM费用明细合并（发票业务、预提调整、成本预提）
--FCM费用打标签(有航班ID并且在相同会计期间记AO1，有航班ID会计期间不同记AO2，无航班ID记A02)
   drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp07 ;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp07 stored as Parquet as
select trim(t1.zdqj) as month, --会计期间
       cast(null as string) upload_name,
       t1.fymc as fcm_type, --FCM成本费用要素类型
       t1.f_fymxid fcm_id, --FCM成本费用id
       t1.flight_id, --航班ID
       t1.std, --航班计划起飞时间
       t1.szm as dept_thr_code,
       t1.departure_airport_3code, --起飞机场3字码
       t1.arrival_airport_3code, --落地机场3字码
       t1.acco_code,
       t1.f_zdid,
       cast(null as string) flight_date,
       t1.flight_no,
       cast(null as string) flight_sect,
       cast(null as string) ac_reg,
       t1.atd,
       t1.ata,
       t1.cny_atm as reso_amt, --金额(成本人民币)
       t1.flight_type,
       case
         when t1.flight_id is not null and
              trim(t1.zdqj) =
              regexp_replace(substr(trim(t1.std), 1, 7), '-', '') then
          'A01'
         when t1.flight_id is not null and
              trim(t1.zdqj) <>
              regexp_replace(substr(trim(t1.std), 1, 7), '-', '') then
          'A02'
         when t1.flight_id is null then
          'A02'
         else
          'A02'
       end as reso_type, --资源标签
       case
         when t1.flight_id is not null and
              trim(t1.zdqj) =
              regexp_replace(substr(trim(t1.std), 1, 7), '-', '') then
          '1'
         when t1.flight_id is not null and
              trim(t1.zdqj) <>
              regexp_replace(substr(trim(t1.std), 1, 7), '-', '') then
          '0'
         when t1.flight_id is null then
          '0'
         else
          '0'
       end as is_cur_fly --是否当月航班
  from dm_air_dw.air_abc_bsl_reso_base_fcm_cb t1 where t1.inc_month = '${v_month}' and t1.month = '${v_month}'
union all
select trim(t2.zdqj) as month, --会计期间
       case when t2.fyfl = '线下手工冲减' then t2.fyfl else null end upload_name,
       t2.fymc as fcm_type, --FCM成本费用要素类型
       t2.f_fyid fcm_id, --FCM成本费用id
       t2.flight_id, --航班ID
       t2.std, --航班计划起飞时间
       t2.f_fsd as dept_thr_code,
       t2.departure_airport_3code, --起飞机场3字码
       t2.arrival_airport_3code, --落地机场3字码
       t2.acco_code,
       t2.cbyt_pz_id f_zdid,
       t2.f_rq flight_date,
       t2.f_hbbh flight_no,
       t2.f_hdbh flight_sect,
       t2.f_fjjh ac_reg,
       cast(null as string) atd,
       cast(null as string) ata,
       t2.cny_atm as reso_amt, --金额(成本人民币)
       t2.flight_type,
       case
         when t2.flight_id is not null and
              trim(t2.zdqj) =
              regexp_replace(substr(trim(t2.std), 1, 7), '-', '') then
          'A01'
         when t2.flight_id is not null and
              trim(t2.zdqj) <>
              regexp_replace(substr(trim(t2.std), 1, 7), '-', '') then
          'A02'
         when t2.flight_id is null then
          'A02'
         else
          'A02'
       end as reso_type, --资源标签
       case
         when t2.flight_id is not null and
              trim(t2.zdqj) =
              regexp_replace(substr(trim(t2.std), 1, 7), '-', '') then
          '1'
         when t2.flight_id is not null and
              trim(t2.zdqj) <>
              regexp_replace(substr(trim(t2.std), 1, 7), '-', '') then
          '0'
         when t2.flight_id is null then
          '0'
         else
          '0'
       end as is_cur_fly --是否当月航班
  from dm_air_dw.air_abc_bsl_reso_base_fcm_yt t2 where t2.inc_month = '${v_month}' and t2.month = '${v_month}';


----   drop table if exists tmp_dm_air_dw.air_abc_rel_v_fycbzx ;
----create table tmp_dm_air_dw.air_abc_rel_v_fycbzx stored as Parquet as
----    select b01.*
----          from ods_air_fcm.v_fycbzx b01
----         inner join (select max(b02.inc_day) inc_day
----                      from ods_air_fcm.v_fycbzx b02) b03
----            on b01.inc_day = b03.inc_day;
--add by cwz 20220729   FCM费用id对应成本中心关系表 ods_air_fcm.v_fycbzx 每次都是取最新的数据不满足  EX00011在20220729已经发现为EX00029,但跟用户确认202206还是属于EX00011的  比如ZY051_01
drop table if exists tmp_dm_air_dw.air_abc_rel_v_fycbzx;
create table tmp_dm_air_dw.air_abc_rel_v_fycbzx stored as Parquet as
    select b01.* from ods_air_fcm.v_fycbzx b01 where b01.inc_day='$[time(yyyyMM04)]'
;


--添加逻辑，处理湿租航班
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08 ;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08 stored as Parquet as
select t1.month, --会计期间
       t1.upload_name,
       t1.fcm_type, --FCM成本费用要素类型
       t1.fcm_id, --FCM成本费用id
       t1.flight_id, --航班ID
       t1.std, --航班计划起飞时间
       t1.dept_thr_code,
       t1.departure_airport_3code, --起飞机场3字码
       t1.arrival_airport_3code, --落地机场3字码
       t1.acco_code,
       t1.f_zdid,
       t1.flight_date,
       t1.flight_no,
       t1.flight_sect,
       t1.ac_reg,
       t1.atd,
       t1.ata,
       t1.reso_amt,
       case when t1.month>='201901' and t1.month<='202206' and t3.fm_reso_code is not null and t1.flight_type = 'A02' and trim(t3.sz_type_code) not like '%A02%' then 'A02'       --add by cwz 20230425 资源分摊逻辑设置成2019年1月1日-2022年6月只在自有航班分摊，22年7月开始不再对航班性质作限制
            ----when t3.fm_reso_code is not null and t1.flight_type = 'A03' and trim(t3.sz_type_code) not like '%A03%' then 'A02'   --add by cwz 20221009 FCM预提有金鹏航班的起降费用，并且可以分到航班ID，但9月ABC月结时金鹏航班的起降费用全部进到了FCM-无航班，导致金鹏航班成本有误，梳理逻辑，可能由于该段代码造成（以前金鹏航班不分摊起降费用
            when t1.flight_type = 'A99' then 'A02'
            else t1.reso_type end reso_type,
       case when t1.month>='201901' and t1.month<='202206' and t3.fm_reso_code is not null and t1.flight_type = 'A02' and trim(t3.sz_type_code) not like '%A02%' then '0'            --add by cwz 20230425
            ----when t3.fm_reso_code is not null and t1.flight_type = 'A03' and trim(t3.sz_type_code) not like '%A03%' then '0'     --add by cwz 20221009 胡洁
            when t1.flight_type = 'A99' then '0'
             else t1.is_cur_fly end is_cur_fly
from tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp07 t1
  left join (select a.fcm_type, a.reso_type, a.reso_code, b.reso_name,b.remark2
               from dm_air_dw.air_abc_rel_fcm_to_reso a
               left join dm_air_dw.air_abc_rel_reso b
               on a.reso_code = b.reso_code
              where a.mode_code = '${v_mode_code}'
                and to_date(a.start_tm) <= to_date('${v_fm_dt}')
                and to_date(a.end_tm) >= to_date('${v_fm_dt}')
              group by a.fcm_type, a.reso_type, a.reso_code, b.reso_name,b.remark2) t2
    on trim(t1.fcm_type) = trim(t2.fcm_type)
   and t1.reso_type = t2.reso_type
  left join dm_air_dw.air_abc_rel_fcm_change_reso t3 --FCM资源转化配置表
      on t2.reso_code = t3.fm_reso_code
      and trim(t3.remark1) = 'A01'
      and to_date(t3.start_tm) <= to_date('${v_fm_dt}')
      and to_date(t3.end_tm) >= to_date('${v_fm_dt}');

--20240315注释掉
-- drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08_01 ;
--create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08_01 stored as Parquet as
--select flight_no,flight_no_4 from
--(select flight_no,substr(flight_no,-4) flight_no_4,
--     row_number() over(partition by substr(flight_no,-4) order by t.flight_id desc) rn
--                       from dm_air_dw.air_abc_fact_flight_info t
--                      where t.inc_month = '${v_month}') a
--where a.rn = 1;

--add by cwz 20240315
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08_01 ;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08_01 stored as Parquet as
select flight_no,flight_no_4 from
(select flight_no,substr(flight_no,3,6) flight_no_4,
     row_number() over(partition by substr(flight_no,3,6) order by t.flight_id desc) rn
                       from dm_air_dw.air_abc_fact_flight_info t
                      where t.inc_month = '${v_month}') a
where a.rn = 1;


 --step8.关联（资源与FCM成本要素到作业关系）生成资源基表数据
insert overwrite table dm_air_dw.air_abc_bsl_reso_fcm_detailed partition
  (inc_month = '${v_month}')
select t1.month, --月份
        case
         when t1.acco_code = '6401620000' and t1.dept_thr_code = 'PEK' then
          'EX00020'
         when t1.acco_code = '6401620000' and nvl(t1.dept_thr_code, 'XXX') <> 'PEK' then
          'EX00009'
       else nvl(t5.f_xmvalue, 'EX000') end cost_code, --成本中心
       -- 2020-8-20 区分外部航班费用 - 非O3航班费用直接计入999999995,999999994地服自营成本中
       case
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and substr(t1.flight_no,1,2)='O3' then t2.reso_code
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and substr(t6.flight_no,1,2)='O3' then t2.reso_code
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and substr(t1.flight_no,1,2)<>'O3' then 'ZY031_03'
         else t2.reso_code end reso_code, --资源代码
       concat_ws('-',
                         t2.reso_name,
                         t1.upload_name) reso_name, --资源名称
       t1.f_zdid,
       t4.flight_date flight_date,
       t4.flight_no flight_no,
       t4.flight_sect flight_sect,
       t4.ac_reg ac_reg,
       t4.atd atd,
       t4.ata ata,
       -- 2020-8-20 区分外部航班费用 - 非O3航班费用直接计入999999995,999999994地服自营成本中
       case
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and substr(t1.flight_no,1,2)='O3' then t1.flight_id
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and substr(t6.flight_no,1,2)='O3' then t1.flight_id
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and t1.dept_thr_code = 'PEK'
          and substr(t1.flight_no,1,2)<>'O3' then '999999995'
         when t2.reso_code in ('ZY031_01','ZY031_02')
          and t1.acco_code = '6401620000'
          and t1.dept_thr_code <> 'PEK'
          and substr(t1.flight_no,1,2)<>'O3' then '999999994'
         else t1.flight_id end as intern_code, --内部订单
       t1.reso_amt as reso_amt, --金额
       t1.fcm_id source_code, --系统来源(SAP,FCM)
       t1.acco_code,
       t3.acco_name, --会计名称
       trim(t1.fcm_type) fcm_type, --FCM成本费用要素类型
       t1.departure_airport_3code as fm_thr_code, --起飞机场3字码
       t1.arrival_airport_3code as to_thr_code, --落地机场3字码
       t1.is_cur_fly, --是否当月航班
       t1.std, --计划起飞时间
       t1.dept_thr_code,
       case
         when t2.reso_code is not null then
          1
         when t1.acco_code in ('6401660200',
                          '6401660000',
                          '6401590900',
                          '6401660100',
                          '6401620000',
                          '6401520101',
                          '6401520102',
                          '6401660400') and t2.reso_code is null then
          -1
         else
          0
       end as flag_code, --标识(1:成功)
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间
  from tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08 t1
  left join (select a.fcm_type, a.reso_type, a.reso_code, b.reso_name
               from dm_air_dw.air_abc_rel_fcm_to_reso a
               left join dm_air_dw.air_abc_rel_reso b
               on a.reso_code = b.reso_code
              where a.mode_code = '${v_mode_code}'
                and to_date(a.start_tm) <= to_date('${v_fm_dt}')
                and to_date(a.end_tm) >= to_date('${v_fm_dt}')
              group by a.fcm_type, a.reso_type, a.reso_code, b.reso_name) t2
   on trim(t1.fcm_type) = trim(t2.fcm_type)
   and t1.reso_type = t2.reso_type
   and t1.acco_code in ('6401660200',
                   '6401660000',
                   '6401590900',
                   '6401660100',
                   '6401620000',
                   '6401520101',
                   '6401520102',
                   '6401660400')
left join (select trim(acco_code) acco_code, acco_name
               from dm_air_dw.air_abc_rel_acco
              group by trim(acco_code), acco_name) t3
    on t1.acco_code = t3.acco_code
left join dm_air_dw.air_abc_fact_flight_info t4
    on t1.flight_id = t4.flight_id
   and t4.inc_month = '${v_month}'
left join tmp_dm_air_dw.air_abc_rel_v_fycbzx t5
   on t1.fcm_id = t5.f_fyid
left join tmp_dm_air_dw.air_abc_bsl_reso_base_fcm_tmp08_01 t6
   --on substr(regexp_replace(t1.flight_no, '[J]$', ''), -4) = t6.flight_no_4
   on case when length(regexp_replace(t1.flight_no, '[J]$', ''))<=4 then regexp_replace(t1.flight_no, '[J]$', '')
   else substr(regexp_replace(t1.flight_no, '[J]$', ''), 3,6) end = t6.flight_no_4   --add by cwz 20240315 如果航班号为O3351 也符合取数逻辑    数据来源主要2部分 一部分主要是集中在4位长度dwd_sh_fin_cost_af_ytcbmx_dtl_mf  一部分集中在6位长度dwd_sh_fin_cost_af_fymx_dtl_mf
   ;

----step9： 写入资源结果基表
insert overwrite table dm_air_dw.air_abc_bsl_reso_base partition
  (inc_sys_src = 'FCM', inc_month = '${v_month}')
select t1.month, --月份
       t1.cost_code, --成本中心
       t1.dept_thr_code, --成本中心3字码
       cast(null as string) as zc_type, --资产成本要素
       cast(null as string) as asset_classify_code, --资产特级号
       ----cast(null as string) as asset_classify_desc, --资产特级号名称描述
       ----case when length(t4.ac_type)=4 then concat_ws('','T',substr(t4.ac_type,2,2),'7')  else NULL end as  asset_classify_desc,  --资产特级号名称描述   add by 20210929 cwz存储机型数据
       case when t4.ac_type='B777'  then 'T777'  else t4.mp_ac_type_t end as  asset_classify_desc,  --资产特级号名称描述 modify by cwz 20250109 有些是5Y航班B777也会产生费用 给它置为T777
       t1.acco_code, --会计科目
       t3.acco_name, --会计名称
       t1.reso_code, --资源代码
       t2.reso_name, --资源名称
       cast(null as string) fly_no, --飞机号
       nvl(t1.intern_code, 'ALL'), --内部订单
       t1.reso_amt, --金额
       'FCM' source_code, --系统来源(SAP,FCM)
       t1.fcm_type, --FCM成本费用要素类型
       cast(null as string) acti_code, --作业代码
       cast(null as string) acti_name, --作业名
       t1.fm_thr_code, --起飞机场3字码
       t1.to_thr_code, --落地机场3字码
       t1.is_cur_fly, --是否当月航班
       t1.std, --计划起飞时间
       t1.flag_code, --标识(1:成功)
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间
  from dm_air_dw.air_abc_bsl_reso_fcm_detailed t1
  left join dm_air_dw.air_abc_rel_reso t2
    on t1.reso_code = t2.reso_code
  left join (select trim(acco_code) acco_code, acco_name
               from dm_air_dw.air_abc_rel_acco
              group by trim(acco_code), acco_name) t3
    on t1.acco_code = t3.acco_code
left join dm_air_dw.air_abc_fact_flight_info t4    --add by 20210929 cwz
    on t1.intern_code = t4.flight_id
   and t4.inc_month = '${v_month}'
    where t1.inc_month = '${v_month}';