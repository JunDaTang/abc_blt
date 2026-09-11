--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  ra分摊检测
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.p_air_abc_fact_ra_dist_check
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-17            刘直       ra分摊检测
                         
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
--step1.总资源
insert overwrite table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'ALL')
  select a.month,
         'ALL' dist_type,
         0 check_step,
         '总资源' check_name,
         sum(a.reso_amt) reso_amt,
         from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
    from dm_air_dw.air_abc_fact_reso_list a
   where a.month = '${v_month}'
     and a.inc_month = '${v_month}'
   group by a.month;

--step2.理论发送方资源
drop table if exists tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01;
create table tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01 stored as parquet as
  select a.month,
         'RA01' dist_type,
         1 check_step,
         '理论发送方资源' check_name,
         sum(a.reso_amt) reso_amt
    from dm_air_dw.air_abc_fact_reso_list a
    left semi
    join dm_air_dw.air_abc_rel_ra_dist b
      on to_date(b.start_tm) <= to_date('${v_fm_dt}')
     and to_date(b.end_tm) >= to_date('${v_fm_dt}')
     and a.cost_code = b.fm_cost_code
     and a.reso_code = b.fm_reso_code
   where a.month = '${v_month}'
     and a.inc_month = '${v_month}'
   group by a.month;

--step3.实际发送方资源
insert into table tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01
  select t.month,
        'RA01' dist_type,
        2 check_step,
        '实际发送方资源' check_name,
        sum(2 * t.max_amt - t.min_amt) reso_amt
   from (select a.mode_code,
                a.month,
                a.fm_cost_code,
                a.fly_no,
                a.intern_code,
                a.fm_reso_code,
                max(a.fm_reso_amt) max_amt,
                min(a.fm_reso_amt) min_amt
           from dm_air_dw.air_abc_fact_ra_dist_comp a
          where a.month = '${v_month}'
            and a.mode_code = '${v_mode_code}'
            and a.inc_month = '${v_month}'
            and a.hq_dist_code = 'RA01'
          group by a.mode_code,
                   a.month,
                   a.fm_cost_code,
                   a.fly_no,
                   a.intern_code,
                   a.fm_reso_code) t
  group by t.month;

--step4.已分摊资源
insert into table tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01
  select a.month,
       'RA01' dist_type,
       3 check_step,
       '已分摊资源' check_name,
       sum(a.to_reso_amt) reso_amt
  from dm_air_dw.air_abc_fact_ra_dist_comp a
 where a.month = '${v_month}'
   and a.mode_code = '${v_mode_code}'
   and a.inc_month = '${v_month}'
   and a.hq_dist_code = 'RA01'
 group by a.month;

--step5.末分摊资源
insert into table tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01
  select t.month,
       'RA01' dist_type,
       4 check_step,
       '末分摊资源' check_name,
       sum(2 * t.max_amt - t.min_amt) reso_amt
  from (select a.mode_code,
               a.month,
               a.fm_cost_code,
               a.fly_no,
               a.intern_code,
               a.fm_reso_code,
               max(a.fm_reso_amt) max_amt,
               min(a.fm_reso_amt) min_amt
          from dm_air_dw.air_abc_fact_ra_dist_comp a
         where a.month = '${v_month}'
           and a.mode_code = '${v_mode_code}'
           and a.inc_month = '${v_month}'
           and a.hq_dist_code = 'RA01'
           and nvl(a.total_driv_qty, 0) = 0
         group by a.mode_code,
                  a.month,
                  a.fm_cost_code,
                  a.fly_no,
                  a.intern_code,
                  a.fm_reso_code) t
 group by t.month;

--step6.重复分摊资源
insert into table tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01
  select t.month,
       'RA01' dist_type,
       5 check_step,
       '重复分摊资源' check_name,
       sum(2 * t.max_amt - t.min_amt - t.to_reso_amt) reso_amt
  from (select a.mode_code,
               a.month,
               a.fm_cost_code,
               a.fly_no,
               a.intern_code,
               a.fm_reso_code,
               max(a.fm_reso_amt) max_amt,
               min(a.fm_reso_amt) min_amt,
               sum(nvl(a.to_reso_amt, 0)) to_reso_amt
          from dm_air_dw.air_abc_fact_ra_dist_comp a
         where a.month = '${v_month}'
           and a.mode_code = '${v_mode_code}'
           and a.inc_month = '${v_month}'
           and a.hq_dist_code = 'RA01'
           and nvl(a.total_driv_qty, 0) <> 0
         group by a.mode_code,
                  a.month,
                  a.fm_cost_code,
                  a.fly_no,
                  a.intern_code,
                  a.fm_reso_code) t
 group by t.month;

--step7.数据写入检查结果表
insert overwrite table dm_air_dw.air_abc_fct_dist_check_sum partition
  (inc_month = '${v_month}', hq_dist_code = 'RA01')
  select a.month,
         a.dist_type,
         a.check_step,
         a.check_name,
         a.reso_amt,
         from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
    from tmp_dm_air_dw.air_abc_fact_ra_dist_check_sum_tmp01 a;

--#####################################################################