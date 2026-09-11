--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  资源结果表
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_reso_list
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       资源结果表
--add by cwz 20211014 FCM_无航班资源（02）分摊规则重述   修改为在对应机型的FCM_有航班（01）资源的航班范围内按航班量均摊                         
--#####################################################################

--##################################################################### 
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
--set mapred.job.queue.name=udp;
--set mapred.job.name=${v_proc_name};
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
----step1：FCM、资产资源基表数据写入资源结果表
drop table if exists tmp_dm_air_dw.air_abc_fact_reso_list_tmp01;
create table tmp_dm_air_dw.air_abc_fact_reso_list_tmp01 stored as parquet as
select t.month, --月份
       t.cost_code, --成本中心
       t.reso_code, --资源代码
       t.reso_name, --资源名称
       t.fly_no,
       t.intern_code, --内部订单
       t.acco_code, --会计科目
       t.acco_name, --会计科目名称
       t.source_code,
       sum(nvl(t.reso_amt, 0)) as reso_amt, --金额 
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time, --加载时间  
       '${v_month}' inc_month
  from (select t1.month, --月份
               t1.cost_code, --成本中心
               t1.reso_code, --资源代码
               t1.reso_name, --资源名称
               t1.fly_no,
               case
                 when t1.is_cur_fly = 1 then
                  t1.intern_code
                when t1.reso_code in ('ZY031_03')
                then t1.intern_code
                when t1.asset_classify_desc is not null and substr(t1.reso_code,-3)='_02' then asset_classify_desc  --add by cwz 20210929  里面存储T737机队数据
                 else
                  'ALL'
               end as intern_code, --内部订单
               t1.acco_code,
               t1.acco_name,
               t1.source_code,
               t1.reso_amt --金额     
          from dm_air_dw.air_abc_bsl_reso_base t1
         where t1.inc_month = '${v_month}'
           and t1.month = '${v_month}'
           and t1.inc_sys_src = 'FCM'
           and t1.flag_code = 1
        union all
        select t2.month, --月份
               t2.cost_code, --成本中心
               t2.reso_code, --资源代码
               t2.reso_name, --资源名称
               t2.fly_no,         
               t2.intern_code, --内部订单
               t2.acco_code,
               t2.acco_name,
               t2.source_code,
               t2.reso_amt --金额      
          from dm_air_dw.air_abc_bsl_reso_base t2
         where t2.inc_month = '${v_month}'
           and t2.month = '${v_month}'
           and t2.inc_sys_src = 'SAP_ZC'
           and t2.flag_code = 1
           union all
        select t3.month, --月份
               t3.cost_code, --成本中心
               t3.reso_code, --资源代码
               t3.reso_name, --资源名称
               t3.fly_no,         
               t3.intern_code, --内部订单
               t3.acco_code,
               t3.acco_name,
               t3.source_code,
               t3.reso_amt --金额      
          from dm_air_dw.air_abc_bsl_reso_base t3
         where t3.inc_month = '${v_month}'
           and t3.month = '${v_month}'
           and t3.inc_sys_src = 'UPLOAD'
           and t3.flag_code = 1) t
 group by t.month,
          t.cost_code,
          t.reso_code,
          t.reso_name,
          t.fly_no,
          t.intern_code,
          t.acco_code,
          t.acco_name,
          t.source_code;
 
----step1：SAP总账资源基表数据写入资源结果表（SAP总账减去资产）
insert into table tmp_dm_air_dw.air_abc_fact_reso_list_tmp01
select t.month, --月份
       t.cost_code, --成本中心
       t.reso_code, --资源代码
       t.reso_name, --资源名称
       case
         when b.reso_code is not null then
          t.fly_no
         else
          cast(null as string)
       end fly_no,
       t.intern_code, --内部订单
       t.acco_code, --会计科目
       t.acco_name, --会计科目名称
       t.source_code,
       sum(nvl(t.reso_amt, 0)) as reso_amt, --金额 
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time, --加载时间 
       '${v_month}' inc_month      
  from (select t1.month, --月份
               t1.cost_code, --成本中心
               case
                 when t1.reso_code = 'ZY011' then
                  a.reso_code
                 else
                  t1.reso_code
               end reso_code, --资源代码
               case
                 when t1.reso_code = 'ZY011' then
                  a.reso_name
                 else
                  t1.reso_name
               end reso_name, --资源名称
               t1.fly_no,
               case
                 when t1.reso_code = 'ZY011' then
                  a.intern_code
                 else
                  t1.intern_code
               end intern_code,
               t1.acco_code,
               t1.acco_name,
               t1.source_code,
               case
                 when t1.reso_code = 'ZY011' then
                  t1.reso_amt * a.driv_qty
                 else
                  t1.reso_amt
               end reso_amt --金额     
          from dm_air_dw.air_abc_bsl_reso_base t1
          left join (select cost_code, reso_code, reso_name, intern_code, sum(nvl(driv_qty, 0)) driv_qty from dm_air_dw.air_abc_fact_indirect_labor where inc_month = '${v_month}' and month = '${v_month}' group by cost_code, reso_code, reso_name, intern_code) a
            on t1.cost_code = a.cost_code
            and t1.reso_code = 'ZY011'
         where t1.inc_month = '${v_month}'
           and t1.month = '${v_month}'
           and t1.inc_sys_src = 'SAP'
           and t1.flag_code = 1
        union all
        select t2.month, --月份
               t2.cost_code, --成本中心
               'ZY099' reso_code, --资源代码
               '折旧摊销' reso_name, --资源名称
               t2.fly_no,
               t2.intern_code, --内部订单
               t2.acco_code,
               t2.acco_name,
               'SAP' source_code,
               -t2.reso_amt reso_amt --金额      
          from dm_air_dw.air_abc_bsl_reso_base t2
         where t2.inc_month = '${v_month}'
           and t2.month = '${v_month}'
           and t2.inc_sys_src = 'SAP_ZC'
           and t2.reso_code in
               ('ZY017', 'ZY130', 'ZY026', 'ZY043','ZY044', 'ZY092', 'ZY093', 'ZY163_01', 'ZY163_02')
           and t2.flag_code = 1) t
  left join (select reso_code
               from dm_air_dw.air_abc_rel_intern
              where dist_type = 'RA01'
                and type_code = 2
                and mode_code = '${v_mode_code}'
                and to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')
              group by reso_code) b
    on t.reso_code = b.reso_code
 group by t.month,
          t.cost_code,
          t.reso_code,
          t.reso_name,
          case
            when b.reso_code is not null then
             t.fly_no
            else
             cast(null as string)
          end,
          t.intern_code,
          t.acco_code,
          t.acco_name,
          t.source_code;
   

insert overwrite table dm_air_dw.air_abc_fact_reso_list partition
  (inc_month = '${v_month}')
select  
       t1.month, --月份
       t1.cost_code, --成本中心
       t1.reso_code, --资源代码
       t1.reso_name, --资源名称
       t1.fly_no,
       t1.intern_code, --内部订单
       t1.acco_code, --会计科目
       t1.acco_name, --会计科目名称
       coalesce(t2.type_code, t3.type_code, t4.type_code, t5.type_code) cb_type_code,
       t1.source_code,
       t1.reso_amt, --金额 
       cast(null as string) remark1,
       cast(null as string) remark2,
       cast(null as string) remark3,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间 
 from  tmp_dm_air_dw.air_abc_fact_reso_list_tmp01 t1
 left join dm_air_dw.air_abc_rel_reso_type t2
 on t1.reso_code = t2.reso_code
 and t1.acco_code = t2.acco_code
  and to_date(t2.start_tm) <= to_date('${v_fm_dt}')
 and to_date(t2.end_tm) >= to_date('${v_fm_dt}')
  left join dm_air_dw.air_abc_rel_reso_type t3
 on t1.reso_code = t3.reso_code
 and substr(t1.acco_code,1,7) = regexp_replace(t3.acco_code,'\\*','')
 and to_date(t3.start_tm) <= to_date('${v_fm_dt}')
 and to_date(t3.end_tm) >= to_date('${v_fm_dt}')
   left join dm_air_dw.air_abc_rel_reso_type t4
 on t1.reso_code = t4.reso_code
 and substr(t1.acco_code,1,6) = regexp_replace(t4.acco_code,'\\*','')
  and to_date(t4.start_tm) <= to_date('${v_fm_dt}')
 and to_date(t4.end_tm) >= to_date('${v_fm_dt}')
   left join dm_air_dw.air_abc_rel_reso_type t5
 on t1.reso_code = t5.reso_code
 and substr(t1.acco_code,1,1) = regexp_replace(t5.acco_code,'\\*','')
  and to_date(t5.start_tm) <= to_date('${v_fm_dt}')
 and to_date(t5.end_tm) >= to_date('${v_fm_dt}');