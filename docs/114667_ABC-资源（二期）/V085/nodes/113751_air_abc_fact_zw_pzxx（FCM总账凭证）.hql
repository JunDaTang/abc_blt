set mapreduce.job.name=fcmzhong;
--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  FCM总账凭证
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_zw_pzxx
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       FCM总账凭证
                         
--#####################################################################

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
----step1： 写入FCM总账凭证结果表
insert overwrite table dm_air_dw.air_abc_fact_zw_pzxx partition
  (inc_month = '${v_month}')
  select '正常凭证' f_pzlb,
         a.f_pzscsj,
         a.f_voucher_type,
         a.f_fiscal_year,
         a.f_accounting_period,
         a.f_attachment_number,
         a.f_date,
         a.f_enter,
         a.f_cashier,
         a.f_signature,
         a.f_voucher_id,
         a.f_ywlb,
         a.f_zdid,
         a.f_pzzfbz,
         a.f_ywlbid,
         a.f_pzflid,
         a.f_cdbz,
         a.f_scfs,
         a.f_je_maked_by,
         a.f_je_approved_by,
         a.request_id,
         a.journal_num,
         a.f_cdbz_time,
         a.f_oldpzzbid,
         b.f_pzzbid,
         b.f_entry_id,
         b.f_account_code,
         b.f_abstract,
         b.f_currency,
         b.f_unit_price,
         b.f_exchange_rate1,
         b.f_exchange_rate2,
         b.f_debit_quantity,
         b.f_primary_debit_amount,
         b.f_secondary_debit_amount,
         b.f_natural_debit_currency,
         b.f_credit_quantity,
         b.f_primary_credit_amount,
         b.f_secondary_credit_amount,
         b.f_natural_credit_currency,
         b.f_auxiliary_lb_1,
         b.f_auxiliary_item_1,
         b.f_auxiliary_lb_2,
         b.f_auxiliary_item_2,
         b.f_auxiliary_lb_3,
         b.f_auxiliary_item_3,
         b.f_auxiliary_lb_4,
         b.f_auxiliary_item_4,
         b.f_auxiliary_lb_5,
         b.f_auxiliary_item_5,
         b.f_auxiliary_lb_6,
         b.f_auxiliary_item_6,
         b.f_auxiliary_lb_7,
         b.f_auxiliary_item_7,
         b.f_auxiliary_lb_8,
         b.f_auxiliary_item_8,
         b.f_auxiliary_lb_9,
         b.f_auxiliary_item_9,
         b.f_auxiliary_lb_10,
         b.f_auxiliary_item_10,
         b.f_cdbz_oracle,
         b.f_pzh_oracle
  from (select t.*
          from ods_air_fcm.zw_pzmxb t
         inner join (select max(t1.inc_day) inc_day
                      from ods_air_fcm.zw_pzmxb t1) t2
            on t.inc_day = t2.inc_day) b
  left join (select t0.*
               from ods_air_fcm.zw_pzzb t0
              inner join (select max(t01.inc_day) inc_day
                           from ods_air_fcm.zw_pzzb t01) t02
                 on t0.inc_day = t02.inc_day) a
    on b.f_pzzbid = a.f_pzzbid
  union all
  select '冲销类凭证' f_pzlb,
         a.f_pzscsj,
         a.f_voucher_type,
         a.f_fiscal_year,
         a.f_accounting_period,
         a.f_attachment_number,
         a.f_date,
         a.f_enter,
         a.f_cashier,
         a.f_signature,
         a.f_voucher_id,
         a.f_ywlb,
         a.f_zdid,
         a.f_pzzfbz,
         a.f_ywlbid,
         a.f_pzflid,
         a.f_cdbz,
         a.f_scfs,
         a.f_je_maked_by,
         a.f_je_approved_by,
         a.request_id,
         a.journal_num,
         a.f_cdbz_time,
         a.f_oldpzzbid,
         b.f_pzzbid,
         b.f_entry_id,
         b.f_account_code,
         b.f_abstract,
         b.f_currency,
         b.f_unit_price,
         b.f_exchange_rate1,
         b.f_exchange_rate2,
         b.f_debit_quantity,
         b.f_primary_debit_amount,
         b.f_secondary_debit_amount,
         b.f_natural_debit_currency,
         b.f_credit_quantity,
         b.f_primary_credit_amount,
         b.f_secondary_credit_amount,
         b.f_natural_credit_currency,
         b.f_auxiliary_lb_1,
         b.f_auxiliary_item_1,
         b.f_auxiliary_lb_2,
         b.f_auxiliary_item_2,
         b.f_auxiliary_lb_3,
         b.f_auxiliary_item_3,
         b.f_auxiliary_lb_4,
         b.f_auxiliary_item_4,
         b.f_auxiliary_lb_5,
         b.f_auxiliary_item_5,
         b.f_auxiliary_lb_6,
         b.f_auxiliary_item_6,
         b.f_auxiliary_lb_7,
         b.f_auxiliary_item_7,
         b.f_auxiliary_lb_8,
         b.f_auxiliary_item_8,
         b.f_auxiliary_lb_9,
         b.f_auxiliary_item_9,
         b.f_auxiliary_lb_10,
         b.f_auxiliary_item_10,
         b.f_cdbz_oracle,
         b.f_pzh_oracle
  from (select t.*
          from ods_air_fcm.zw_pzmxb_cw1 t
         inner join (select max(t1.inc_day) inc_day
                      from ods_air_fcm.zw_pzmxb_cw1 t1) t2
            on t.inc_day = t2.inc_day) b
  left join (select t0.*
               from ods_air_fcm.zw_pzzb_cw1 t0
              inner join (select max(t01.inc_day) inc_day
                           from ods_air_fcm.zw_pzzb_cw1 t01) t02
                 on t0.inc_day = t02.inc_day) a
    on b.f_pzzbid = a.f_pzzbid;
	 