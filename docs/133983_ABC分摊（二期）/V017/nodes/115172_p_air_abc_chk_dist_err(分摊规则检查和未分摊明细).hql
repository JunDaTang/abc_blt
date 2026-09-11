set mapred.job.name=sh_115172;
set hive.jobname.length=10;
--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  分摊规则检查和未分摊明细
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_chk_dist_err
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-20            刘直       分摊规则检查和未分摊明细
                         
--#####################################################################

--##################################################################### 
--设置参数
set mapred.job.queue.name=SFAIR2;
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
--step1.分摊规则检验
drop table if exists tmp_dm_air_dw.air_abc_chk_dist_err_tmp01;
create table tmp_dm_air_dw.air_abc_chk_dist_err_tmp01 stored as parquet as
select t1.month,
       t1.cost_code,
       t1.reso_code,
       '' acti_code,
       '核算有资源没做RA规则' remark
  from (select a.month, a.cost_code, a.reso_code
          from dm_air_dw.air_abc_fact_reso_list a
         where a.inc_month = '${v_month}' and a.month = '${v_month}'
         group by a.month, a.cost_code, a.reso_code) t1
  left join dm_air_dw.air_abc_rel_ra_dist t2
    on t1.cost_code = t2.fm_cost_code
   and t1.reso_code = t2.fm_reso_code
   and to_date(t2.start_tm) <= to_date('${v_fm_dt}')
   and to_date(t2.end_tm) >= to_date('${v_fm_dt}')
 where t2.fm_cost_code is null;

insert into tmp_dm_air_dw.air_abc_chk_dist_err_tmp01
  select '${v_month}' month,
         a.to_cost_code,
         a.to_reso_code,
         a.to_acti_code,
         'RA规则后没有AA,AS规则' remark
    from dm_air_dw.air_abc_rel_ra_dist a
    left join dm_air_dw.air_abc_rel_aa_dist b
      on a.to_cost_code = b.fm_cost_code
     and a.to_acti_code = b.fm_acti_code
     and a.to_reso_code = b.fm_reso_code
     and to_date(b.start_tm) <= to_date('${v_fm_dt}')
     and to_date(b.end_tm) >= to_date('${v_fm_dt}')
    left join dm_air_dw.air_abc_rel_as_dist c
      on a.to_cost_code = c.fm_cost_code
     and a.to_acti_code = c.fm_acti_code
     and a.to_reso_code = c.fm_reso_code
     and to_date(c.start_tm) <= to_date('${v_fm_dt}')
     and to_date(c.end_tm) >= to_date('${v_fm_dt}')
   where a.mode_code = '${v_mode_code}'
     and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}')
     and b.fm_cost_code is null
     and c.fm_cost_code is null;

insert into tmp_dm_air_dw.air_abc_chk_dist_err_tmp01
  select '${v_month}' month,
         a.to_cost_code,
         a.to_reso_code,
         a.to_acti_code,
         'AA规则后没有AS规则' remark
    from dm_air_dw.air_abc_rel_aa_dist a
    left join dm_air_dw.air_abc_rel_as_dist b
      on a.to_cost_code = b.fm_cost_code
     and a.to_acti_code = b.fm_acti_code
     and a.to_reso_code = b.fm_reso_code
     and to_date(b.start_tm) <= to_date('${v_fm_dt}')
     and to_date(b.end_tm) >= to_date('${v_fm_dt}')
   where a.mode_code = '${v_mode_code}' and b.fm_cost_code is null;
   
   
insert into tmp_dm_air_dw.air_abc_chk_dist_err_tmp01
  select '${v_month}' month,
         a.to_cost_code,
         a.to_reso_code,
         a.to_acti_code,
         'RA、AA的TO规则重复，导致AS重复取数' remark
    from dm_air_dw.air_abc_rel_ra_dist a
	inner join dm_air_dw.air_abc_rel_aa_dist b
      on a.to_cost_code = b.to_cost_code
     and a.to_acti_code = b.to_acti_code
     and a.to_reso_code = b.to_reso_code
     and a.mode_code = '${v_mode_code}' 
	 and to_date(b.start_tm) <= to_date('${v_fm_dt}')
     and to_date(b.end_tm) >= to_date('${v_fm_dt}')
	 and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}') ;   
	 
	 
insert into tmp_dm_air_dw.air_abc_chk_dist_err_tmp01
  select '${v_month}' month,
         a.fm_cost_code,
         a.fm_reso_code,
         a.to_acti_code,
         'RA规则配置重复' remark
    from dm_air_dw.air_abc_rel_ra_dist a
   where a.mode_code = '${v_mode_code}' and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}')
   group by a.fm_cost_code, a.fm_reso_code, a.to_acti_code
  having count(1) > 1;

insert into tmp_dm_air_dw.air_abc_chk_dist_err_tmp01
  select '${v_month}' month,
         a.fm_cost_code,
         a.fm_reso_code,
         a.fm_acti_code,
         'AA规则配置重复' remark
    from dm_air_dw.air_abc_rel_aa_dist a
   where a.mode_code = '${v_mode_code}' and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}')
   group by a.fm_cost_code, a.fm_reso_code, a.fm_acti_code, a.to_acti_code
  having count(1) > 1;

insert into tmp_dm_air_dw.air_abc_chk_dist_err_tmp01
  select '${v_month}' month,
         a.fm_cost_code,
         a.fm_reso_code,
         a.fm_acti_code,
         'AS规则配置重复' remark
    from dm_air_dw.air_abc_rel_as_dist a
   where a.mode_code = '${v_mode_code}' and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}')
   group by a.fm_cost_code, a.fm_reso_code, a.fm_acti_code
  having count(1) > 1;   
   

--step2.末分摊明细
drop table if exists tmp_dm_air_dw.air_abc_chk_no_dist_tmp01;
create table tmp_dm_air_dw.air_abc_chk_no_dist_tmp01 stored as parquet as
select t1.month,
       t1.cost_code,
	   t1.fly_no,
       t1.intern_code,
       t1.reso_code,
       '' acti_code,
       '' driv_code,
       'NO_DIST' dist_type,
       t1.reso_amt
  from (select a.month,
               a.cost_code,
               a.reso_code,
			   a.fly_no,
               a.intern_code,
               sum(a.reso_amt) reso_amt
          from dm_air_dw.air_abc_fact_reso_list a
         where a.month = '${v_month}' and a.inc_month = '${v_month}'
         group by a.month,
                  a.cost_code,
                  a.reso_code,
				  a.fly_no,
                  a.intern_code) t1
  left join dm_air_dw.air_abc_rel_ra_dist t2
    on t1.cost_code = t2.fm_cost_code
   and t1.reso_code = t2.fm_reso_code
   and to_date(t2.start_tm) <= to_date('${v_fm_dt}')
   and to_date(t2.end_tm) >= to_date('${v_fm_dt}')
 where t2.fm_cost_code is null;

insert into table tmp_dm_air_dw.air_abc_chk_no_dist_tmp01
  select t.month,
         t.fm_cost_code,
         t.fly_no,
         t.intern_code,
         t.fm_reso_code,
         '' acti_code,
         t.driv_code,
         'RA01' dist_type,
         2 * t.max_amt - t.min_amt reso_amt
    from (select a.mode_code,
                 a.month,
                 a.fm_cost_code,
                 a.fly_no,
                 a.intern_code,
                 a.fm_reso_code,
                 a.driv_code,
                 max(a.fm_reso_amt) max_amt,
                 min(a.fm_reso_amt) min_amt
            from dm_air_dw.air_abc_fact_ra_dist_comp a
           where a.month = '${v_month}' and a.mode_code = '${v_mode_code}' and a.inc_month = '${v_month}' and a.hq_dist_code = 'RA01'
             and nvl(a.total_driv_qty, 0) = 0 and nvl(a.fm_reso_amt,1) <> 0
           group by a.mode_code,
                    a.month,
                    a.fm_cost_code,
                    a.fly_no,
                    a.intern_code,
                    a.fm_reso_code,
                    a.driv_code) t;

insert into table tmp_dm_air_dw.air_abc_chk_no_dist_tmp01
  select t.month,
         t.fm_cost_code,
         t.fly_no,
         t.intern_code,
         t.fm_reso_code,
         t.fm_acti_code,
         t.driv_code,
         'AA01' dist_type,
         2 * t.max_amt - t.min_amt reso_amt
    from (select a.mode_code,
                 a.month,
                 a.fm_cost_code,
                 a.fly_no,
                 a.intern_code,
                 a.fm_acti_code,
                 a.fm_reso_code,
                 a.driv_code,
                 max(a.fm_reso_amt) max_amt,
                 min(a.fm_reso_amt) min_amt
            from dm_air_dw.air_abc_fact_aa_dist_comp a
           where a.month = '${v_month}' and a.inc_month = '${v_month}' and a.hq_dist_code = 'AA01'
             and a.mode_code = '${v_mode_code}'
             and nvl(a.total_driv_qty, 0) = 0 and nvl(a.fm_reso_amt,0) <> 0
           group by a.mode_code,
                    a.month,
                    a.fm_cost_code,
                    a.fly_no,
                    a.intern_code,
                    a.fm_acti_code,
                    a.fm_reso_code,
                    a.driv_code) t;

insert into table tmp_dm_air_dw.air_abc_chk_no_dist_tmp01
  select t.month,
         t.fm_cost_code,
         t.fly_no,
         t.intern_code,
         t.fm_reso_code,
         t.fm_acti_code,
         t.driv_code,
         'AS01' dist_type,
         2 * t.max_amt - t.min_amt reso_amt
    from (select a.mode_code,
                 a.month,
                 a.fm_cost_code,
                 a.fly_no,
                 a.intern_code,
                 a.fm_acti_code,
                 a.fm_reso_code,
                 a.driv_code,
                 max(a.fm_reso_amt) max_amt,
                 min(a.fm_reso_amt) min_amt
            from dm_air_dw.air_abc_fact_as_dist_comp a
           where a.month = '${v_month}' and a.inc_month = '${v_month}' and a.hq_dist_code = 'AS01'
             and a.mode_code = '${v_mode_code}'
             and nvl(a.total_driv_qty, 0) = 0 and nvl(a.fm_reso_amt,0) <> 0
           group by a.mode_code,
                    a.month,
                    a.fm_cost_code,
                    a.fly_no,
                    a.intern_code,
                    a.fm_acti_code,
                    a.fm_reso_code,
                    a.driv_code) t;
					
insert into table tmp_dm_air_dw.air_abc_chk_no_dist_tmp01					
select t.month,
       t.fm_cost_code,
       cast(null as string) fly_no,
       cast(null as string) intern_code,
       t.fm_reso_code,
       t.fm_acti_code,
       cast(null as string) driv_code,
       'AS01' dist_type,
       t.reso_amt_change reso_amt
  from (select a.month,
               a.to_cost_code fm_cost_code,
               a.to_acti_code fm_acti_code,
               a.to_reso_code fm_reso_code,
               a.reso_amt reso_amt_ra,
               b.reso_amt reso_amt_ao,
               a.reso_amt - b.reso_amt reso_amt_change
          from (select month,
                       to_cost_code,
                       to_acti_code,
                       to_reso_code,
                       sum(nvl(to_reso_amt, 0)) reso_amt
                  from dm_air_dw.air_abc_fact_ra_dist_comp
                 where month = '${v_month}'
                   and mode_code = '${v_mode_code}'
                   and inc_month = '${v_month}'
                   and hq_dist_code = 'RA01'
                 group by month, to_cost_code, to_acti_code, to_reso_code) a
          left join
         (select month,
                fm_cost_code,
                fm_acti_code,
                fm_reso_code,
                sum(nvl(to_reso_amt, 0)) reso_amt
           from dm_air_dw.air_abc_fact_as_dist_comp
          where month = '${v_month}'
            and inc_month = '${v_month}'
            and hq_dist_code = 'AS01'
            and mode_code = '${v_mode_code}'
          group by month, fm_cost_code, fm_acti_code, fm_reso_code) b
            on a.month = b.month
           and a.to_cost_code = b.fm_cost_code
           and a.to_acti_code = b.fm_acti_code
           and a.to_reso_code = fm_reso_code
         where a.reso_amt <> 0) t where t.reso_amt_change >= 0.1 or t.reso_amt_change <= -0.1;
                    
 --step3.分摊规则未配置明细写入结果表
 alter table dm_air_dw.air_abc_chk_dist_err drop partition(inc_month = '${v_month}'); 
insert overwrite table dm_air_dw.air_abc_chk_dist_err partition
  (inc_month = '${v_month}') 
select t1.month,
       t1.cost_code,
       t1.reso_code,
       t1.acti_code,
       t1.remark,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from tmp_dm_air_dw.air_abc_chk_dist_err_tmp01 t1;


 --step4.未分摊明细数据写入结果表
  alter table dm_air_dw.air_abc_chk_no_dist drop partition(inc_month = '${v_month}'); 
insert overwrite table dm_air_dw.air_abc_chk_no_dist partition
  (inc_month = '${v_month}') 
select t1.month,
       t1.cost_code,
       t1.fly_no,
       t1.intern_code,
       t1.reso_code,
       '' reso_name,
       t1.acti_code,
       '' acti_name,
       t1.driv_code,
       '' driv_name,
       t1.dist_type,
       t1.reso_amt,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
  from tmp_dm_air_dw.air_abc_chk_no_dist_tmp01 t1;