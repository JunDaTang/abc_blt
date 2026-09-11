--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  ao分摊资源到作业分摊
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_as_dist_comp
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-17            刘直       ao分摊资源到作业分摊
--2021-09-22            chenweizhen    新增AO动因测试数据写入202108bak分区 20210924注释掉
                         
--#####################################################################

--##################################################################### 
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
-- set mapred.job.queue.name=udp;
-- set mapred.job.name=${v_proc_name};
-- set hive.exec.reducers.max=400;
-- set mapred.task.timeout=1000000;
-- set hive.fetch.task.conversion=more;
-- set hive.exec.compress.output=false;
-- set hive.exec.compress.intermediate=true;
-- set mapred.max.split.size=1000000000;
-- set mapred.min.split.size.per.node=1000000000;
-- set mapred.min.split.size.per.rack=1000000000;
-- set hive.auto.convert.join=true;
-- set hive.groupby.skewindata=true;
-- set hive.exec.mode.local.auto=false;
-- set hive.mapjoin.smalltable.filesize=128000000;
-- set hive.exec.dynamic.partition.mode=nonstrict;
-- set hive.ignore.mapjoin.hint=true;
-- set hive.exec.parallel=true;
-- set hive.exec.parallel.thread.number=16;
-- set hive.mapjoin.smalltable.filesize=128000000;
-- 20210211 添加，解决GC报错
-- set hive.optimize.skewjoin=true;
set mapred.job.queue.name=SFAIR2;
--#####################################################################
--链接数据库
use dm_air_dw;

--#####################################################################
--step1.建立分摊标准
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_tmp01;
create table tmp_dm_air_dw.air_abc_fact_as_dist_tmp01 stored as parquet as
  select a.mode_code,
         a.start_tm,
         a.end_tm,
         a.fm_cost_code,
         a.fm_acti_code,
         a.fm_reso_code,
         a.driv_code
    from dm_air_dw.air_abc_rel_as_dist a
   where a.mode_code = '${v_mode_code}'
     and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}')
   group by a.mode_code,
            a.start_tm,
            a.end_tm,
            a.fm_cost_code,
            a.fm_acti_code,
            a.fm_reso_code,
            a.driv_code;
    
--step2.生成资源
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_tmp02;
create table tmp_dm_air_dw.air_abc_fact_as_dist_tmp02 stored as parquet as
 select t.mode_code,
        t.month,
        t.fm_cost_code,
        t.fm_acti_code,
        t.fm_reso_code,
        t.fly_no,
		t.cb_type_code,
        t.intern_code,
        sum(nvl(t.fm_reso_amt, 0)) fm_reso_amt
   from (select a.mode_code,
                a.month,
                a.to_cost_code fm_cost_code,
                a.to_acti_code fm_acti_code,
                a.to_reso_code fm_reso_code,
                a.fly_no,
				a.cb_type_code,
				a.intern_code,
                sum(nvl(a.to_reso_amt, 0)) fm_reso_amt
           from dm_air_dw.air_abc_fact_ra_dist_comp a
          where a.mode_code = '${v_mode_code}'
            and a.inc_month = '${v_month}'
            and a.month = '${v_month}'
            and a.hq_dist_code = 'RA01'
          group by a.mode_code,
                   a.month,
                   a.to_cost_code,
                   a.to_acti_code,
                   a.to_reso_code,
                   a.fly_no,
				   a.cb_type_code,
                   a.intern_code
         union all
         select b.mode_code,
                b.month,
                b.to_cost_code fm_cost_code,
                b.to_acti_code fm_acti_code,
                b.to_reso_code fm_reso_code,
                b.fly_no,
				b.cb_type_code,
                b.intern_code,
                sum(nvl(b.to_reso_amt, 0)) fm_reso_amt
           from dm_air_dw.air_abc_fact_aa_dist_comp b
          where b.mode_code = '${v_mode_code}'
            and b.inc_month = '${v_month}'
            and b.month = '${v_month}'
            and b.hq_dist_code = 'AA01'
          group by b.mode_code,
                   b.month,
                   b.to_cost_code,
                   b.to_acti_code,
                   b.to_reso_code,
                   b.fly_no,
				   b.cb_type_code,
                   b.intern_code) t
  group by t.mode_code,
           t.month,
           t.fm_cost_code,
           t.fm_acti_code,
           t.fm_reso_code,
           t.fly_no,
		   t.cb_type_code,
           t.intern_code;

 --step3.整理资源数据
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_tmp03;
create table tmp_dm_air_dw.air_abc_fact_as_dist_tmp03 stored as parquet as
 select a.mode_code,
       a.month,
       a.fm_cost_code,
       a.fm_acti_code,
       a.fm_reso_code,
       case
         when b.type_code = 0 then
          'ALL'
         else
          nvl(a.intern_code, 'ALL')
       end intern_code,
       a.fly_no,
	   a.cb_type_code,
       b.type_code,
       sum(a.fm_reso_amt) fm_reso_amt
  from (select a1.mode_code,
               a1.month,
               a1.fm_cost_code,
               a1.fm_acti_code,
               a1.fm_reso_code,
               a1.intern_code,
               a1.fly_no,
			   a1.cb_type_code,
               a2.driv_code,
               a1.fm_reso_amt
          from tmp_dm_air_dw.air_abc_fact_as_dist_tmp02 a1
          left join (select fm_reso_code,
                           fm_acti_code,
                           fm_cost_code,
                           driv_code
                      from tmp_dm_air_dw.air_abc_fact_as_dist_tmp01
                     group by fm_reso_code,
                              fm_acti_code,
                              fm_cost_code,
                              driv_code) a2
            on a1.fm_reso_code = a2.fm_reso_code
           and a1.fm_acti_code = a2.fm_acti_code
           and a1.fm_cost_code = a2.fm_cost_code) a
  left join (select t.reso_code, t.driv_code, t.type_code
               from dm_air_dw.air_abc_rel_intern t
              where t.mode_code = '${v_mode_code}'
                and t.dist_type = 'AS01'
                and to_date(t.start_tm) <= to_date('${v_fm_dt}')
                and to_date(t.end_tm) >= to_date('${v_fm_dt}')
              group by t.reso_code, t.driv_code, t.type_code) b
    on a.fm_reso_code = b.reso_code
   and a.driv_code = b.driv_code
 group by a.mode_code,
          a.month,
          a.fm_cost_code,
          a.fm_acti_code,
          a.fm_reso_code,
          case
            when b.type_code = 0 then
             'ALL'
            else
             nvl(a.intern_code, 'ALL')
          end,
          a.fly_no,
		  a.cb_type_code,
          b.type_code;
           
--step4.关联资源
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_tmp04;
create table tmp_dm_air_dw.air_abc_fact_as_dist_tmp04 stored as parquet as
  select 
        a.mode_code,
        a.start_tm,
        a.end_tm,
        a.fm_cost_code,
		b.fly_no,
		b.cb_type_code,
        b.intern_code,
        b.type_code,
        a.fm_acti_code,
        a.fm_reso_code,
        b.fm_reso_amt, 
        a.driv_code
    from tmp_dm_air_dw.air_abc_fact_as_dist_tmp01 a
    left join tmp_dm_air_dw.air_abc_fact_as_dist_tmp03 b
      on a.mode_code = b.mode_code
     and a.fm_cost_code = b.fm_cost_code
     and a.fm_acti_code = b.fm_acti_code
     and a.fm_reso_code = b.fm_reso_code
	 and nvl(b.fm_reso_amt,0) <> 0 ;

--step5.生成动因
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_tmp05;
create table tmp_dm_air_dw.air_abc_fact_as_dist_tmp05 stored as parquet as
  select a.month,
         a.cost_code,
         nvl(a.intern_code, 'ALL') intern_code,
         a.flight_id,
         a.driv_code,
         sum(a.driv_qty) driv_qty
    from dm_air_dw.air_abc_fact_as_driv a
   where a.month = '${v_month}'
   and a.inc_month = '${v_month}'
   and a.flight_id is not null
   group by a.month,
            a.cost_code,
            nvl(a.intern_code, 'ALL'),
            a.flight_id,
            a.driv_code;

--step6.生成分摊临时表
drop table if exists tmp_dm_air_dw.air_abc_fact_as_dist_tmp06;
create table tmp_dm_air_dw.air_abc_fact_as_dist_tmp06 stored as parquet as
select a.mode_code,
       a.start_tm,
       a.end_tm,
       a.fm_cost_code,
	   a.fly_no,
	   a.cb_type_code,
       a.intern_code,
       a.fm_acti_code,
       a.fm_reso_code,
       a.fm_reso_amt,
       a.driv_code,
       case
         when a.driv_code = 'AS001' then
          a.intern_code
         else
          b.flight_id
       end flight_id,
       case
         when a.driv_code in ('RA001', 'AA001', 'AS001') then
          1
         else
          nvl(b.driv_qty, 0)
       end driv_qty,
       case
         when a.driv_code in ('RA001', 'AA001', 'AS001') then
          1
         else
          sum(nvl(b.driv_qty, 0))
          over(partition by a.fm_cost_code,
               a.fly_no,
			   a.cb_type_code,
               a.intern_code,
               a.fm_acti_code,
               a.fm_reso_code)
       end total_driv_qty
  from tmp_dm_air_dw.air_abc_fact_as_dist_tmp04 a
  left join tmp_dm_air_dw.air_abc_fact_as_dist_tmp05 b
    on case when a.driv_code in ('AS070', 'AS071', 'AS072')
			then concat_ws('-',a.fm_reso_code,a.fm_cost_code)   --由于多个资源对应一个航班，导致资源无法区分，需逻辑处理
			else a.fm_cost_code 
			end = b.cost_code
   and case
         when a.type_code = 1 then
          'ALL'
         when a.type_code = 2 then
          a.fly_no
         else
          a.intern_code
       end = b.intern_code
   and a.driv_code = b.driv_code;

--step7.写入分摊结果表
insert overwrite table dm_air_dw.air_abc_fact_as_dist_comp partition
  (inc_month = '${v_month}', hq_dist_code = 'AS01')
--insert overwrite table dm_air_dw.air_abc_fact_as_dist_comp partition     --add by cwz 20210922
--  (inc_month = '202108bak', hq_dist_code = 'AS01')
  select a.mode_code,
         '${v_month}' month,
         a.fm_cost_code,
         a.fly_no,
		 a.cb_type_code,
         a.intern_code,
         a.fm_acti_code,
         c.acti_name_lev3 fm_acti_name,
         a.fm_reso_code,
         b.reso_name fm_reso_name,
         a.fm_reso_amt,
         a.driv_code,
         d.driv_name,
         a.flight_id,
         a.driv_qty,
         a.total_driv_qty,
         case
           when a.total_driv_qty = 0 then
            0
           else
            a.fm_reso_amt * (a.driv_qty / a.total_driv_qty)
         end to_reso_amt,
		 cast(null as string) remark1,    
         cast(null as string) remark2,    
         cast(null as string) remark3,  
         from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') load_tm
    from tmp_dm_air_dw.air_abc_fact_as_dist_tmp06 a
    left join dm_air_dw.air_abc_rel_reso b
      on a.fm_reso_code = b.reso_code
    left join dm_air_dw.air_abc_rel_acti c
      on a.fm_acti_code = c.acti_code_lev3
    left join dm_air_dw.air_abc_rel_dy d
      on a.driv_code = d.driv_code
   where a.fm_reso_amt is not null and a.flight_id is not null;
  -- and  a.driv_qty is not null
  -- and nvl(a.total_driv_qty, 0) <> 0;

--#####################################################################