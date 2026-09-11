set mapred.job.name=sh_119406;
--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  分摊结果宽表
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_dist_relust
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       分摊结果宽表
--2025-01-10            陈维镇     新增3个方案机型字段
                         
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

----step1： 分摊结果数据写入分摊结果宽表
 insert overwrite table dm_air_dw.air_abc_fact_dist_relust partition
  (inc_month = '${v_month}')
select a.mode_code, --模型代码
       a.month, --月份
       c.acti_code_lev1, --一级作业代码
       c.acti_name_lev1, --一级作业名称
       c.acti_code_lev2, --二级作业代码
       c.acti_name_lev2, --二级作业名称
       c.acti_code_lev3, --三级作业代码
       c.acti_name_lev3, --三级作业名称
       a.fm_cost_code,
       a.fm_reso_code,
       a.fm_reso_name,  
       a.intern_code,
       a.cb_type_code,
       a.driv_code,
       a.driv_name,
       a.driv_qty,
       a.total_driv_qty,
       a.fly_no, --飞机号(原始)
       a.ac_type ac_type_ys, --机型(原始)
       round(a.acti_amt, 4) acti_amt, --作业成本
       a.flight_id, --航班ID
       b.flight_no, --航班号
       b.flight_type, --航班性质
       b.flight_type_name, --航班性质全写
       b.ac_type, --机型(分摊)
       b.ac_reg, --机号(分摊)
       regexp_replace(b.flight_date, '-', '') flight_date, --航班日期
       b.std, --计划起飞时间
       b.sta, --计划到达时间
       b.atd, --实际起飞时间
       b.ata, --实际到达时间
       b.air_time, --空中时间
       b.block_time, --空地时间
       b.departure_airport_3code, --起飞机场（三字码）
       b.departure_ch_name, --起飞机场名称
       b.arrival_airport_3code, --降落机场（三字码）
       b.arrival_ch_name, --降落机场名称
       b.flight_season, --航季，S夏秋W冬春
       b.flight_season_name, --航季中文名称冬春/夏秋
       b.adjust_type, --调整类型
       b.adjust_type_name, --调整类型名称
       b.expect_load, --预计业载
       b.real_load, --实际业载
       b.limit_load, --预载限值
       b.flight_sect, --航段
       b.total_weight, --实际货量（毛重）
       b.suttle, --实际货量净重
       b.pc, --快递件数
       b.standard_load, --机型标准载货量
       b.carrying_rate, --载运率
       b.vr_fuel_list_count, --航班油单数量
       b.old_fuel, --航班飞机原存油
       b.new_fuel, --航班飞机累积新加油
       b.fuel_total_fqi, --航班飞机加油后油表读数
       b.left_fuel, --航班飞机落地后油表读数
       round(b.flight_fuel_consume, 6) flight_fuel_consume, --航班耗油计算
       b.fly_hours, --飞行时间
       b.remark, --备注
       b.touchgo, --复飞次数
       b.flight_seg_distance, --航距
       from_unixtime(unix_timestamp(concat(a.month, '01'), 'yyyyMMdd'),
                     'yyyy-MM-dd') as load_month, --数据加载月份
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time, --加载时间
     b.mp_ac_type_b,       --方案大机型B add by cwz 20250110 B73N任务改造
     b.mp_ac_type_t,       --方案大机型T
     regexp_replace(b.mp_ac_type_t,'T','') as mp_ac_type_7  --方案大机型737 747 73N 757 767 NULL 
  from (select t.mode_code,
               t.month,
               t.fm_cost_code,
               t.fm_reso_code,
               t.fm_reso_name,  
               t.intern_code,              
               t.fm_acti_code,
               sum(nvl(t.to_reso_amt, 0)) acti_amt,
               t.fly_no,
               t.cb_type_code,
               t0.ac_type,
               t.flight_id,
               t.driv_code,
               t.driv_name,
               t.driv_qty,
               t.total_driv_qty
          from dm_air_dw.air_abc_fact_as_dist_comp t
          left join 
          (select ac_reg, ac_type
               from (select ac_reg,
                            ac_type,
                            row_number() over(partition by ac_reg order by flight_date desc) as rn
                       from dm_air_dw.air_abc_fact_flight_info where inc_month = '${v_month}') t1
              where t1.rn = 1) t0
         on t.fly_no = t0.ac_reg
         where t.inc_month = '${v_month}'
           and t.month = '${v_month}'
           and t.mode_code = '${v_mode_code}'
           and t.hq_dist_code = 'AS01'
         group by t.mode_code, t.month, t.fm_cost_code, t.fm_reso_code, t.fm_reso_name, t.intern_code, t.fm_acti_code, t.fly_no, t.cb_type_code, t0.ac_type, t.flight_id,
               t.driv_code,
               t.driv_name,
               t.driv_qty,
               t.total_driv_qty
         ) a
  left join dm_air_dw.air_abc_fact_flight_info b
    on a.flight_id = b.flight_id
   and b.inc_month = '${v_month}'
  left join dm_air_dw.air_abc_rel_acti c
    on a.fm_acti_code = c.acti_code_lev3
   and c.mode_code = '${v_mode_code}'
   and to_date(c.start_tm) <= to_date('${v_fm_dt}')
   and to_date(c.end_tm) >= to_date('${v_fm_dt}');

