--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  资源归集流程状态
--author:   xiagnkun

--parameters:
--${v_proc_name}: dm_air_dw.rpt_air_abc_workflow_monitor
--${v_month}:     统计月份(yyyymm)       
--${v_fm_dt}:     开始日期(yyyymmdd)
--${v_to_dt}:     结束日期(yyyymmdd)
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2019-03-27            xiangkun   资源归集流程状态
                         
--history
--date        author     version      modifications
--2019-03-27  xiangkun   v01          资源归集流程状态
--#####################################################################

--#####################################################################
--链接数据库
use dm_air_dw;

--#####################################################################


--#####################################################################
--step1 资源归集流程状态

insert overwrite table dm_air_dw.rpt_air_abc_workflow_monitor partition (inc_month = '${v_month}' , workflow = 'ZY_SUM' , status = '02')
select t1.month,
       t1.workflow_code,
	   t1.workflow_name,
	   'END' as workflow_status,
	   '资源归集完成' as workflow_status_name,
	   t1.start_time,
	   from_unixtime(unix_timestamp(),'yyyy-MM-dd HH:mm:ss') as end_time,
	   from_unixtime(unix_timestamp(),'yyyy-MM-dd HH:mm:ss') as load_tm
  from dm_air_dw.rpt_air_abc_workflow_monitor t1
 where inc_month = '${v_month}'
   and workflow = 'ZY_SUM'
   and status = '01';
