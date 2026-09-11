--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  ra分摊资源到作业分摊
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_ra_dist_comp
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-17            刘直       ra分摊资源到作业分摊
                         
--#####################################################################

--##################################################################### 
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
set mapred.job.queue.name=SFAIR2;
set hive.exec.dynamic.partition=true;
set hive.exec.dynamic.partition.mode=nostrict;
--#####################################################################
--链接数据库
use dm_air_dw;

--#####################################################################
--step1.建立分摊标准
drop table if exists tmp_dm_air_dw.air_abc_fact_ra_dist_tmp01;
create table tmp_dm_air_dw.air_abc_fact_ra_dist_tmp01 stored as parquet as
  select a.mode_code,
         a.start_tm,
         a.end_tm,
         a.fm_cost_code,
         a.fm_reso_code,
         a.to_cost_code,
         a.to_acti_code,
         a.to_reso_code,
         a.driv_code
    from dm_air_dw.air_abc_rel_ra_dist a
   where a.mode_code = '${v_mode_code}'
     and to_date(a.start_tm) <= to_date('${v_fm_dt}')
     and to_date(a.end_tm) >= to_date('${v_fm_dt}')
   group by a.mode_code,
            a.start_tm,
            a.end_tm,
            a.fm_cost_code,
            a.fm_reso_code,
            a.to_cost_code,
            a.to_acti_code,
            a.to_reso_code,
            a.driv_code;

--step2.生成资源
drop table if exists tmp_dm_air_dw.air_abc_fact_ra_dist_tmp02;
create table tmp_dm_air_dw.air_abc_fact_ra_dist_tmp02 stored as parquet as
select a.month,
       a.cost_code,
       a.reso_code,
       case
         when b.type_code = 0 then
          'ALL'
         else
          nvl(a.intern_code, 'ALL')
       end intern_code,
	   a.cb_type_code,
       a.fly_no,
       b.type_code,
       sum(a.reso_amt) reso_amt
  from (select a1.month,
               a1.cost_code,
               a1.reso_code,
               a1.intern_code,
               a1.fly_no,
			   a1.cb_type_code,
               a2.driv_code,
               a1.reso_amt
          from dm_air_dw.air_abc_fact_reso_list a1
          left join (select fm_reso_code, fm_cost_code, driv_code
                      from tmp_dm_air_dw.air_abc_fact_ra_dist_tmp01
                     group by fm_reso_code, fm_cost_code, driv_code) a2
            on a1.reso_code = a2.fm_reso_code
           and a1.cost_code = a2.fm_cost_code
         where a1.inc_month = '${v_month}'
           and a1.month = '${v_month}') a
  left join (select t.reso_code, t.driv_code, t.type_code
               from dm_air_dw.air_abc_rel_intern t
              where t.mode_code = '${v_mode_code}'
                and t.dist_type = 'RA01'
                and to_date(t.start_tm) <= to_date('${v_fm_dt}')
                and to_date(t.end_tm) >= to_date('${v_fm_dt}')
              group by t.reso_code, t.driv_code, t.type_code) b
    on a.reso_code = b.reso_code
   and a.driv_code = b.driv_code
 group by a.month,
          a.cost_code,
          a.reso_code,
          case
            when b.type_code = 0 then
             'ALL'
            else
             nvl(a.intern_code, 'ALL')
          end,
          a.fly_no,
		  a.cb_type_code,
          b.type_code;

--step3.关联资源
drop table if exists tmp_dm_air_dw.air_abc_fact_ra_dist_tmp03;
create table tmp_dm_air_dw.air_abc_fact_ra_dist_tmp03 stored as parquet as
  select a.mode_code,
         a.start_tm,
         a.end_tm,
         a.fm_cost_code,
         b.intern_code,
		 b.fly_no,
		 b.cb_type_code,
		 b.type_code,
         a.fm_reso_code,
         b.reso_amt fm_reso_amt,
         a.to_cost_code,
         a.to_acti_code,
         a.to_reso_code,
         a.driv_code
    from tmp_dm_air_dw.air_abc_fact_ra_dist_tmp01 a
    left join tmp_dm_air_dw.air_abc_fact_ra_dist_tmp02 b
      on a.fm_cost_code = b.cost_code
     and a.fm_reso_code = b.reso_code;

--step4.生成动因
drop table if exists tmp_dm_air_dw.air_abc_fact_ra_dist_tmp04;
create table tmp_dm_air_dw.air_abc_fact_ra_dist_tmp04 stored as parquet as
  select a.month,
         a.cost_code,
         nvl(a.intern_code, 'ALL') intern_code,
         a.acti_code,
         a.driv_code,
         sum(a.driv_qty) driv_qty
    from dm_air_dw.air_abc_fact_ra_driv a
   where a.inc_month = '${v_month}'
   and a.month = '${v_month}'
   group by a.month,
            a.cost_code,
            nvl(a.intern_code, 'ALL'),
            a.acti_code,
            a.driv_code;

--step5.生成分摊临时表
drop table if exists tmp_dm_air_dw.air_abc_fact_ra_dist_tmp05;
create table tmp_dm_air_dw.air_abc_fact_ra_dist_tmp05 stored as parquet as
select
  a.mode_code,
  a.start_tm,
  a.end_tm,
  a.fm_cost_code,
  a.fly_no,
  a.cb_type_code,
  a.intern_code,
  a.fm_reso_code,
  a.fm_reso_amt,
  a.to_cost_code,
  a.to_acti_code,
  a.to_reso_code,
  a.driv_code,
  case
    when a.driv_code in ('RA001', 'AA001', 'AS001') then 1
    else nvl(b.driv_qty, 0)
  end driv_qty,
  case
    when a.driv_code in ('RA001', 'AA001', 'AS001') then 1
    else sum(nvl(b.driv_qty, 0)) over(
      partition by a.fm_cost_code,
      a.intern_code,
      a.fly_no,
	  a.cb_type_code,
      a.fm_reso_code
    )
  end total_driv_qty
from
  tmp_dm_air_dw.air_abc_fact_ra_dist_tmp03 a
  left join tmp_dm_air_dw.air_abc_fact_ra_dist_tmp04 b on case
    when a.driv_code in ('RA006', 'RA009') then concat(a.fm_reso_code, '-', a.fm_cost_code)  --由于多个资源对应一个作业，导致资源无法区分，需逻辑处理
    when a.to_acti_code in('B010070004', 'C010030004') and a.driv_code = 'RA010' then concat(a.fm_cost_code, '_', a.fm_reso_code)  --由于多个资源对应一个作业，导致资源无法区分，需逻辑处理
    else a.fm_cost_code
  end = b.cost_code
  and case
    when a.type_code = 1 then 'ALL'  --RA时动因内部订单为ALL，需要保留内部订单AO分摊时进行关联
    when a.type_code = 2 then nvl(a.fly_no, a.intern_code)  --RA时动因内部订单为飞机号，需要保留内部订单AO分摊时进行关联
    else a.intern_code
  end = b.intern_code
  and case
    when a.driv_code in ('RA004', 'RA009', 'RA013', 'RA014', 'RA015', 'RA018', 'RA019', 'RA021') then substr(a.to_acti_code, 1, 3)  --航前航后作业分摊时，为了通用逻辑动因里作业代码用B01,C01替代
    else a.to_acti_code
  end = b.acti_code
  and a.driv_code = b.driv_code;

--step6.写入分摊结果表
insert overwrite table dm_air_dw.air_abc_fact_ra_dist_comp partition
  (inc_month = '${v_month}', hq_dist_code = 'RA01')
  select a.mode_code,
         '${v_month}' month,
         a.fm_cost_code,
         a.fly_no,
		 a.cb_type_code,
         a.intern_code,
         a.fm_reso_code,
         b.reso_name fm_reso_name,
         a.fm_reso_amt,
         a.to_cost_code,
         a.to_acti_code,
         d.acti_name_lev3 to_acti_name,
         a.to_reso_code,
         c.reso_name to_reso_name,
         a.driv_code,
         e.driv_name,
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
    from tmp_dm_air_dw.air_abc_fact_ra_dist_tmp05 a
    left join dm_air_dw.air_abc_rel_reso b
      on a.fm_reso_code = b.reso_code
    left join dm_air_dw.air_abc_rel_reso c
      on a.to_reso_code = c.reso_code
    left join dm_air_dw.air_abc_rel_acti d
      on a.to_acti_code = d.acti_code_lev3
    left join dm_air_dw.air_abc_rel_dy e
      on a.driv_code = e.driv_code
   where a.fm_reso_amt is not null;
  -- and  a.driv_qty is not null
  -- and nvl(a.total_driv_qty, 0) <> 0;

--#####################################################################