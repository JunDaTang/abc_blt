--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  ao分摊检测
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.p_air_abc_fact_ao_dist_check
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-17            刘直       ao分摊检测
                         
--#####################################################################

--##################################################################### 
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
set mapred.job.queue.name=SFAIR2;
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
--step1.理论发送方资源
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01;
create table tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01 stored as parquet as
select a.month,
       'AS01' dist_type,
       1 check_step,
       '理论发送方资源' check_name,
       sum(a.to_reso_amt) reso_amt
  from (select a01.mode_code,
               a01.month,
               a01.to_cost_code,
               a01.to_acti_code,
               a01.to_reso_code,
               a01.to_reso_amt
          from dm_air_dw.air_abc_fact_ra_dist_comp a01
         where a01.month = '${v_month}'
           and a01.mode_code = '${v_mode_code}'
           and a01.inc_month = '${v_month}'
           and a01.hq_dist_code = 'RA01'
        union all
        select a02.mode_code,
               a02.month,
               a02.to_cost_code,
               a02.to_acti_code,
               a02.to_reso_code,
               a02.to_reso_amt
          from dm_air_dw.air_abc_fact_aa_dist_comp a02
         where a02.month = '${v_month}'
           and a02.mode_code = '${v_mode_code}'
           and a02.inc_month = '${v_month}'
           and a02.hq_dist_code = 'AA01') a
  left semi
  join dm_air_dw.air_abc_rel_as_dist b
    on to_date(b.start_tm) <= to_date('${v_fm_dt}')
   and to_date(b.end_tm) >= to_date('${v_fm_dt}')
   and b.mode_code = '${v_mode_code}'
   and a.to_cost_code = b.fm_cost_code
   and a.to_acti_code = b.fm_acti_code
   and a.to_reso_code = b.fm_reso_code
 group by a.month;

--step2.实际发送方资源
insert into table tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01
  select t.month,
         'AS01' dist_type,
         2 check_step,
         '实际发送方资源' check_name,
         sum(2 * t.max_amt - t.min_amt) reso_amt
    from (select a.mode_code,
                 a.month,
                 a.fm_cost_code,
                 a.fly_no,
                 a.intern_code,
                 a.fm_acti_code,
                 a.fm_reso_code,
                 max(a.fm_reso_amt) max_amt,
                 min(a.fm_reso_amt) min_amt
            from dm_air_dw.air_abc_fact_as_dist_comp a
           where a.month = '${v_month}'
             and a.mode_code = '${v_mode_code}'
             and a.inc_month = '${v_month}'
             and a.hq_dist_code = 'AS01'
           group by a.mode_code,
                    a.month,
                    a.fm_cost_code,
                    a.fly_no,
                    a.intern_code,
                    a.fm_acti_code,
                    a.fm_reso_code) t
   group by t.month;

--step3.已分摊资源
insert into table tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01
  select a.month,
         'AS01' dist_type,
         3 check_step,
         '已分摊资源' check_name,
         sum(a.to_reso_amt) reso_amt
    from dm_air_dw.air_abc_fact_as_dist_comp a
   where a.month = '${v_month}'
     and a.mode_code = '${v_mode_code}'
     and a.inc_month = '${v_month}'
     and a.hq_dist_code = 'AS01'
   group by a.month;

--step4.末分摊资源
insert into table tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01
  select t.month,
       'AS01' dist_type,
       4 check_step,
       '末分摊资源' check_name,
       sum(2 * t.max_amt - t.min_amt) reso_amt
  from (select a.mode_code,
               a.month,
               a.fm_cost_code,
               a.fly_no,
               a.intern_code,
               a.fm_acti_code,
               a.fm_reso_code,
               max(a.fm_reso_amt) max_amt,
               min(a.fm_reso_amt) min_amt
          from dm_air_dw.air_abc_fact_as_dist_comp a
         where a.month = '${v_month}'
           and a.mode_code = '${v_mode_code}'
           and a.inc_month = '${v_month}'
           and a.hq_dist_code = 'AS01'
           and nvl(a.total_driv_qty, 0) = 0
         group by a.mode_code,
                  a.month,
                  a.fm_cost_code,
                  a.fly_no,
                  a.intern_code,
                  a.fm_acti_code,
                  a.fm_reso_code) t
 group by t.month;

--step5.重复分摊资源
insert into table tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01
select t.month,
       'AS01' dist_type,
       5 check_step,
       '重复分摊资源' check_name,
       sum(2 * t.max_amt - t.min_amt - t.to_reso_amt) reso_amt
  from (select a.mode_code,
               a.month,
               a.fm_cost_code,
               a.fly_no,
               a.intern_code,
               a.fm_acti_code,
               a.fm_reso_code,
               max(a.fm_reso_amt) max_amt,
               min(a.fm_reso_amt) min_amt,
               sum(nvl(a.to_reso_amt, 0)) to_reso_amt
          from dm_air_dw.air_abc_fact_as_dist_comp a
         where a.month = '${v_month}'
                 and a.mode_code = '${v_mode_code}'
                 and a.inc_month = '${v_month}'
                 and a.hq_dist_code = 'AS01'
                 and nvl(a.total_driv_qty, 0) <> 0
         group by a.mode_code,
                  a.month,
                  a.fm_cost_code,
                  a.fly_no,
                  a.intern_code,
                  a.fm_acti_code,
                  a.fm_reso_code) t
 group by t.month;

--step6.数据写入检查结果表
insert overwrite table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'AS01')
  select a.month,
         a.dist_type,
         a.check_step,
         a.check_name,
         a.reso_amt,
         from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
    from tmp_dm_air_dw.air_abc_fact_as_dist_check_sum_tmp01 a;
	
	
insert overwrite table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'ALL' dist_type,
  'D1' check_step,
  '总资源差异金额' check_name,
  round((a.reso_amt_all - a.reso_amt_as3 - a.reso_amt_as4 - a.reso_amt_ra4),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a;
  
 insert into table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'RA01' dist_type,
  'D1' check_step,
  '总资源 - RA理论发送 差异金额' check_name,
  round((a.reso_amt_all - a.reso_amt_ra1),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a;
  
  
 insert into table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'RA01' dist_type,
  'D2' check_step,
  'RA理论发送 - RA实际发送 差异金额' check_name,
  round((a.reso_amt_ra1 - a.reso_amt_ra2),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a;
  
  
   insert into table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'RA01' dist_type,
  'D3' check_step,
  'RA实际发送 - RA已分摊 - RA未分摊 差异金额' check_name,
  round((a.reso_amt_ra2 - a.reso_amt_ra3 - a.reso_amt_ra4),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a;

  
   insert into table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'AS01' dist_type,
  'D1' check_step,
  'RA已分摊 - AS理论发送 差异金额' check_name,
  round((a.reso_amt_ra3 - a.reso_amt_as1),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a;
  
  
 insert into table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'AS01' dist_type,
  'D2' check_step,
  'AS理论发送 - AS实际发送 差异金额' check_name,
  round((a.reso_amt_as1 - a.reso_amt_as2),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a;
  
  
   insert into table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'DIFF')	
  select 
  a.month,
  'AS01' dist_type,
  'D3' check_step,
  'AS实际发送 - AS已分摊 - AS未分摊 差异金额' check_name,
  round((a.reso_amt_as2 - a.reso_amt_as3 - a.reso_amt_as4),2) reso_amt,
  from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from (
         select
         month,
         sum(case when dist_type = 'ALL' and check_step = 0 then reso_amt else 0 end) reso_amt_all,
         sum(case when dist_type = 'RA01' and check_step = 1 then reso_amt else 0 end) reso_amt_ra1,
         sum(case when dist_type = 'RA01' and check_step = 2 then reso_amt else 0 end) reso_amt_ra2,
         sum(case when dist_type = 'RA01' and check_step = 3 then reso_amt else 0 end) reso_amt_ra3,
         sum(case when dist_type = 'RA01' and check_step = 4 then reso_amt else 0 end) reso_amt_ra4,
         sum(case when dist_type = 'RA01' and check_step = 5 then reso_amt else 0 end) reso_amt_ra5,
         sum(case when dist_type = 'AS01' and check_step = 1 then reso_amt else 0 end) reso_amt_as1,
         sum(case when dist_type = 'AS01' and check_step = 2 then reso_amt else 0 end) reso_amt_as2,
         sum(case when dist_type = 'AS01' and check_step = 3 then reso_amt else 0 end) reso_amt_as3,
         sum(case when dist_type = 'AS01' and check_step = 4 then reso_amt else 0 end) reso_amt_as4,
         sum(case when dist_type = 'AS01' and check_step = 5 then reso_amt else 0 end) reso_amt_as5 
           from dm_air_dw.air_abc_fct_dist_check_sum
          where inc_month = '${v_month}'
            and month = '${v_month}'
            and hq_dist_code in ('ALL', 'RA01', 'AS01')
          group by month) a; 
  
  
--#####################################################################