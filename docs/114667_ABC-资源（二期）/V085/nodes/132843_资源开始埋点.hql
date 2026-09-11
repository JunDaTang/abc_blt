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
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
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


--#####################################################################
--step1 资源归集流程状态

insert overwrite table dm_air_dw.rpt_air_abc_workflow_monitor partition (inc_month = '${v_month}' , workflow = 'ZY_SUM' , status = '01')
select '${v_month}' as month,
       'ZY_SUM' as workflow_code,
	   '资源归集' as workflow_name,
	   'START' as workflow_status,
	   '开始进行资源归集' as workflow_status_name,
	   from_unixtime(unix_timestamp(),'yyyy-MM-dd HH:mm:ss') as start_time,
	   null as end_time,
	   from_unixtime(unix_timestamp(),'yyyy-MM-dd HH:mm:ss') as load_tm
  from dm_air_dw.dual;
