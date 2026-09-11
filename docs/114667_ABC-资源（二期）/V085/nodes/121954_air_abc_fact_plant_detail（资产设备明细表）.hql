--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  资产设备明细表
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_plant_detail
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       资产设备明细表
                         
--#####################################################################

--##################################################################### 
--设置参数
--set mapred.queue.name=${queue};
--set mapred.job.queue.name=${queue};
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
----step1： 资产设备明细表数据写入结果表
insert overwrite table dm_air_dw.air_abc_fact_plant_detail partition
  (inc_month = '${v_month}')
select t1.equnr plant_no, --设备
       t1.tidnr tec_flag_no, --技术标识号
       t1.eqktx plant_desc, --设备说明
       t1.kostl cost_code, --成本中心
       t1.ltext cost_name, --成本中心描述
       t1.tplnr use_localtion, --功能位置
       t1.pltxt use_loal_desc, --功能位置描述
       t1.parnr2 work_no, --负责人 
       cast(null as string) work_name, --负责人名称
       t1.anlnr asset_no, --资产
       t1.bukrs company_code, --公司代码
       t1.aedat modify_date, --更改日期
       t1.ansdt buy_date, --购置日期
       t1.answt buy_price, --购置价值
       t1.herst manufacturer, --资产制造商
       t1.typbz asset_type, --型号
       t1.z_tx_078 asset_upper_type, --资产大类
       t1.z_tx_079 asset_midd_type, --资产中类
       t1.z_tx_003 location, --位置
       t1.chpai plate_no, --车牌号
       t1.eqfnr classify_type, --分类字段
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间  
  from ods_sap_pm.ztpm_ds_dsj t1
 where case
         when '${v_month}' <= '201806' then
          t1.inc_day = '20180701'
         else
          t1.inc_day = '${v_date}'
       end
   and t1.mandt = '800'
   and t1.bukrs = 'EX01'
   and nvl(t1.sttxt,'XXX') not like '%删除标记%';
