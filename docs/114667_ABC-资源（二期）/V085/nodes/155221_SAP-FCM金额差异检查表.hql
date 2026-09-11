--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  SAP-FCM金额差异检查表
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_reso_sap_fcm_change
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       SAP-FCM金额差异检查表
                         
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
insert overwrite table dm_air_dw.air_abc_fact_reso_sap_fcm_change partition
  (inc_month = '${v_month}')
select 
t.month,
t.acco_code,
t.f_zdid,
round(t.reso_amt_sap,6) reso_amt_sap,
round(t.reso_amt_fcm,6) reso_amt_fcm,
round(t.reso_amt_change,6) reso_amt_change,
cast(null as string) as remark,
from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm --加载时间 
from
(  
  select a.month,
       a.acco_code,
       a.f_zdid,
       b.reso_amt reso_amt_sap,
       c.reso_amt reso_amt_fcm,
       b.reso_amt - c.reso_amt reso_amt_change
  from (select t.month, t.acco_code, t.f_zdid
          from (select month, acco_code, substr(ref_key3, 3, 11) f_zdid
                  from dm_air_dw.air_abc_fact_acco_sap_initial
                 where inc_month = '${v_month}'
                   and month = '${v_month}'
                   and acco_code in ('6401660200',
                                     '6401660000',
                                     '6401590900',
                                     '6401660100',
                                     '6401620000',
                                     '6401520101',
                                     '6401520102',
                                     '6401660400')
                   and voucher_type = 'YN'
                union all
                select month, acco_code, f_zdid
                  from dm_air_dw.air_abc_bsl_reso_fcm_detailed
                 where inc_month = '${v_month}'
                   and month = '${v_month}'
				   and flag_code = '1'
                   and acco_code in ('6401660200',
                                     '6401660000',
                                     '6401590900',
                                     '6401660100',
                                     '6401620000',
                                     '6401520101',
                                     '6401520102',
                                     '6401660400')) t
         group by t.month, t.acco_code, t.f_zdid) a
  left join (select month,
                    acco_code,
                    substr(ref_key3, 3, 11) f_zdid,
                    sum(nvl(base_currency_amt, 0)) reso_amt
               from dm_air_dw.air_abc_fact_acco_sap_initial
              where inc_month = '${v_month}'
                and month = '${v_month}'
                and acco_code in ('6401660200',
                                  '6401660000',
                                  '6401590900',
                                  '6401660100',
                                  '6401620000',
                                  '6401520101',
                                  '6401520102',
                                  '6401660400')
                and voucher_type = 'YN'
              group by month, acco_code, substr(ref_key3, 3, 11)) b
    on a.month = b.month
   and a.acco_code = b.acco_code
   and a.f_zdid = b.f_zdid
  left join (select month, acco_code, f_zdid, sum(nvl(reso_amt, 0)) reso_amt
               from dm_air_dw.air_abc_bsl_reso_fcm_detailed
              where inc_month = '${v_month}'
                and month = '${v_month}'
				and flag_code = '1'
                and acco_code in ('6401660200',
                                  '6401660000',
                                  '6401590900',
                                  '6401660100',
                                  '6401620000',
                                  '6401520101',
                                  '6401520102',
                                  '6401660400')
              group by month, acco_code, f_zdid) c
    on a.month = c.month
   and a.acco_code = c.acco_code
   and a.f_zdid = c.f_zdid) t
   where t.reso_amt_change >= 0.1 or t.reso_amt_change <= -0.1;
