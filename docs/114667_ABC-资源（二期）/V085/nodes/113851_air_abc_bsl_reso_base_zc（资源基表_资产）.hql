--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  资源基表_SAP资产
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_bsl_reso_base_zc
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--100: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       资源基表_SAP资产
--2022-11-25            chenweizhen         同一个资源 同一条型码 对应多种设备说明  只取最新1条数据
                         
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

drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp000;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp000 stored as parquet as
select distinct * from (
	   select a.*,b.tec_flag_no 
		from (select * from dm_air_dw.air_abc_rel_reso_asset_collect where nvl(comp_desc,'XXX') <> '专项作业车' and model_code is null and asset_classify_code is null 
			and mode_code = '${v_mode_code}'
   			and to_date(start_tm) <= to_date('${v_fm_dt}')
   			and to_date(end_tm) >= to_date('${v_fm_dt}') ) a
		   left join (select a02.tec_flag_no, a02.plant_desc
					   from dm_air_dw.air_abc_fact_plant_detail a02 
					  group by a02.tec_flag_no, a02.plant_desc) b
			on a.comp_desc = b.plant_desc and b.tec_flag_no is not null 
		union all
		select c.*,d.tec_flag_no 
		  from (select * from dm_air_dw.air_abc_rel_reso_asset_collect where model_code is not null  and asset_classify_code is null 
		  	and mode_code = '${v_mode_code}'
   			and to_date(start_tm) <= to_date('${v_fm_dt}')
   			and to_date(end_tm) >= to_date('${v_fm_dt}') ) c
		   left join (select a03.tec_flag_no, a03.plant_desc,a03.asset_type
					   from dm_air_dw.air_abc_fact_plant_detail a03  
					  group by a03.tec_flag_no, a03.plant_desc,a03.asset_type) d
			on c.comp_desc = d.plant_desc and c.model_code=d.asset_type  and d.tec_flag_no is not null 
		union all
		select e.*,f.tec_flag_no 
		  from (select * from dm_air_dw.air_abc_rel_reso_asset_collect where nvl(comp_desc,'XXX')='专项作业车' and reso_code='ZY043'
		  	and mode_code = '${v_mode_code}'
   			and to_date(start_tm) <= to_date('${v_fm_dt}')
   			and to_date(end_tm) >= to_date('${v_fm_dt}') ) e
		   left join (select a03.tec_flag_no, a03.plant_desc,a03.asset_type
					   from dm_air_dw.air_abc_fact_plant_detail a03 where asset_type not in (select model_code from dm_air_dw.air_abc_rel_reso_asset_collect where model_code is not null)
					  group by a03.tec_flag_no, a03.plant_desc,a03.asset_type) f
			on e.comp_desc = f.plant_desc and f.tec_flag_no is not null  
	) t01;
	
--add by  cwz  20221125-----start----
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp0000;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp0000 stored as parquet as
select 
t1.*
,case when t2.plant_desc is not null then 1 else 0 end as flag_value  --判断是否有空值
,row_number() over(partition by t1.reso_code,t1.tec_flag_no order by case when t2.plant_desc is not null then 1 else 0 end desc ) as rn --同一个资源 同一条型码 对应多种设备说明    (ZY163_01 ZY163_02 这两个会计算相同的条型码 最后再拆分)
from tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp000 t1
left join dm_air_dw.air_abc_fact_plant_detail t2 
on t1.comp_desc = t2.plant_desc      --设备说明
and t1.tec_flag_no=t2.tec_flag_no    --技术标识号
and nvl(t2.tec_flag_no,' ') <>' '    --有些值1个空格字符
and t2.inc_month='${v_month}'            --取最新的月份
;
--add by  cwz  20221125-----end------
--#####################################################################
----step1： 处理(SAP)资产成本要素数据（非ZY092、ZY093资源数据）      
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp001;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp001 stored as parquet as
select t3.month, --会计期间
       t1.comp_desc as zc_type, --资产成本要素(设备说明)
       t1.acti_code_lev3 as acti_code, --作业代码
       t1.acti_name_lev3 as acti_name, --作业名称
       t1.reso_code, --资源代码
       t1.reso_name, --资源名称
       'ALL' as intern_code, --内部订单
       t1.asset_classify_code, --资产特级号
       t1.asset_classify_desc, --资产特级号名称描述
       t3.stock_no, --存货号
       t3.asset_no, --资产卡片号
       -t3.depreciation_mon as reso_amt, --当月折旧
       t3.cost_code, --成本中心
       t3.sap_account, --科目代码
       case
         when t3.month is not null and t3.cost_code in ('EX00009', 'EX00020', 'EX00005', 'EX00002') and substr(t3.sap_account,1,7) = '6401110' then
          1
         else
          0
       end as flag_code --标识(1:成功)
  from tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp0000 t1   --tmp000修改为tmp000
   
  left join (select t03.month,
                    t03.depreciation_mon,
                    t03.stock_no,
                    t03.asset_no,
                    t03.cost_code,
                    t03.sap_account
               from (select t.month,
                            t.depreciation_mon,
                            t.stock_no,
                            t.asset_no,
                            t.cost_code,
                            t.sap_account
                       from dm_air_dw.air_abc_fact_asset_inspect t
                      where t.month = '${v_month}' and t.inc_month = '${v_month}') t03
               left join (select t02.stock_no
                           from dm_air_dw.air_abc_rel_reso_asset_collect t01
                          inner join dm_air_dw.air_abc_fact_asset_inspect t02
                             on t01.asset_classify_code =
                                t02.asset_classify_code
                          where t02.month = '${v_month}'
                            and t02.inc_month = '${v_month}'
                            and t01.asset_classify_code is not null 
                            and t02.stock_no is not null
                          group by t02.stock_no) t04
                 on t03.stock_no = t04.stock_no
              where t04.stock_no is null) t3
    on t1.tec_flag_no = t3.stock_no
 where t1.comp_desc is not null and trim(nvl(t1.comp_desc,'')) <> ''
   and t1.mode_code = '${v_mode_code}'
   and to_date(t1.start_tm) <= to_date('${v_fm_dt}')
   and to_date(t1.end_tm) >= to_date('${v_fm_dt}')
   and t1.rn=1  --add by cwz 20221125 过虑重复条型码
   ;

----step1： 处理(SAP)资产成本要素数据（ZY092、ZY093资源数据,内部订单为机队）               
insert into table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp001 
select t2.month, --会计期间
       t1.comp_desc as zc_type, --资产成本要素(设备说明)
       t1.acti_code_lev3 as acti_code, --作业代码
       t1.acti_name_lev3 as acti_name, --作业名称
       t1.reso_code, --资源代码
       t1.reso_name, --资源名称
       nvl(t2.fleet_code, 'ALL') as intern_code, --内部订单
       t1.asset_classify_code, --资产特级号
       t1.asset_classify_desc, --资产特级号名称描述
       t2.stock_no, --存货号
       t2.asset_no, --资产卡片号
       -t2.depreciation_mon as reso_amt, --当月折旧
       nvl(t2.cost_code, 'EX000') cost_code, --成本中心
       t2.sap_account, --科目代码
       case
         when t2.month is not null and substr(t2.sap_account,1,7) = '6401110' then
          1
         else
          0
       end as flag_code --标识(1:成功)
  from dm_air_dw.air_abc_rel_reso_asset_collect t1
  left join (select t02.month,
                    t02.asset_classify_code,
                    t02.intern_code,
                    t02.depreciation_mon,
                    t02.cost_code,
                    t02.sap_account,
                    t02.stock_no,
                    t02.asset_no,
                    t03.fleet_code
               from dm_air_dw.air_abc_fact_asset_inspect t02
              inner join dm_air_dw.air_abc_rel_fleet_list t03
                 on t02.intern_code = t03.fleet_code_lev1
              where t02.month = '${v_month}'
                and t02.inc_month = '${v_month}'
                and t02.intern_code is not null) t2
    on t1.asset_classify_code = t2.asset_classify_code
 where t1.asset_classify_code is not null 
   and t1.mode_code = '${v_mode_code}'
   and to_date(t1.start_tm) <= to_date('${v_fm_dt}')
   and to_date(t1.end_tm) >= to_date('${v_fm_dt}');

----step1： 处理(SAP)资产成本要素数据（ZY092、ZY093资源数据，内部订单为空）               
insert into table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp001
select t2.month, --会计期间
       t1.comp_desc as zc_type, --资产成本要素(设备说明)
       t1.acti_code_lev3 as acti_code, --作业代码
       t1.acti_name_lev3 as acti_name, --作业名称
       t1.reso_code, --资源代码
       t1.reso_name, --资源名称
       'ALL' as intern_code, --内部订单
       t1.asset_classify_code, --资产特级号
       t1.asset_classify_desc, --资产特级号名称描述
       t2.stock_no, --存货号
       t2.asset_no, --资产卡片号
       -t2.depreciation_mon as reso_amt, --当月折旧
       nvl(t2.cost_code, 'EX000') cost_code, --成本中心
       t2.sap_account, --科目代码
       case
         when t2.month is not null and substr(t2.sap_account,1,7) = '6401110' then
          1
         else
          0
       end as flag_code --标识(1:成功)
  from dm_air_dw.air_abc_rel_reso_asset_collect t1
 inner join dm_air_dw.air_abc_fact_asset_inspect t2
    on t1.asset_classify_code = t2.asset_classify_code
   and t2.intern_code is null
   and t2.month = '${v_month}'
   and t2.inc_month = '${v_month}'
 where t1.asset_classify_code is not null 
   and t1.mode_code = '${v_mode_code}'
   and to_date(t1.start_tm) <= to_date('${v_fm_dt}')
   and to_date(t1.end_tm) >= to_date('${v_fm_dt}');

----step2： (SAP)资产成本要素数据进行数据汇总（财务范忠民确认非ZY092、ZY093资产只取四个成本中心：地服EX00009、北京EX00020、杭州EX00005、保卫EX00002）
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp002;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp002 stored as parquet as
select t1.month, --月份
       t1.cost_code, --成本中心
       t2.airport_thr_code as dept_thr_code, --成本中心3字码
       t1.zc_type, --资产成本要素
       t1.sap_account acco_code, --会计科目
       t1.reso_code, --资源代码
       case
         when t3.fleet_code is null then
          t1.intern_code
         when t3.fleet_code is not null and nvl(t3.fleet_cnt, 0) > 0 then
          t1.intern_code
         else
          'ALL'
       end intern_code, --内部订单
       t1.asset_classify_code, --资产特级号
       t1.asset_classify_desc, --资产特级号名称描述
       sum(nvl(t1.reso_amt, 0)) as reso_amt, --金额
       'SAP_ZC' as source_code, --系统来源(SAP,FCM)
       cast(null as string) as fcm_type, --FCM成本费用要素类型
       cast(null as string) acti_code, --作业代码           
       cast(null as string) as fm_thr_code, --起飞机场3字码
       cast(null as string) as to_thr_code, --落地机场3字码
       '2' as is_cur_fly, --是否当月航班
       cast(null as string) as std, --计划起飞时间
       t1.flag_code --标识(1:成功)
  from tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp001 t1
  left join dm_air_dw.air_abc_rel_air_port_city_code t2
    on t1.cost_code = t2.cost_code
	and to_date(t2.start_tm) <= to_date('${v_fm_dt}')
	and to_date(t2.end_tm) >= to_date('${v_fm_dt}')
  left join (select c.fleet_code,
                    sum(case
                          when a.flight_id is null then
                           0
                          else
                           1
                        end) fleet_cnt
               from dm_air_dw.air_abc_fact_pilot_flight_info a
               left join dm_air_dw.air_abc_fact_pilot_upload_info b
                 on lpad(a.work_no, 8, '0') = lpad(b.work_no, 8, '0')
                and regexp_replace(substr(a.std, 1, 7), '-', '') = b.month
               left join dm_air_dw.air_abc_rel_fleet_list c
                 on regexp_replace(b.ac_type_crew, 'T', '') =
                    regexp_replace(c.fleet_code_lev1, 'T', '')
              where a.rank_no = 'A001'
                and b.month is not null
                and nvl(a.flight_type, 'XXX') in
                    ('N', 'J', 'A', 'T', 'B', 'X', 'D', 'S')
                and a.inc_month = '${v_month}'
                and b.inc_month = '${v_month}'
                and b.month = '${v_month}'
                and regexp_replace(substr(a.std, 1, 7), '-', '') =
                    '${v_month}'
              group by c.fleet_code) t3
    on substr(t1.intern_code, 1, 4) = t3.fleet_code
 group by t1.month,
          t1.cost_code,
          t2.airport_thr_code,
          t1.zc_type,
          t1.sap_account,
          t1.reso_code,
          case
            when t3.fleet_code is null then
             t1.intern_code
            when t3.fleet_code is not null and nvl(t3.fleet_cnt, 0) > 0 then
             t1.intern_code
            else
             'ALL'
          end,
          t1.asset_classify_code,
          t1.asset_classify_desc,
          t1.acti_code,
          t1.flag_code;
---代码添加
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp003;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp003 stored as parquet as
select t1.month, --月份
       t1.cost_code, --成本中心
       t1.dept_thr_code, --成本中心3字码
       t1.zc_type, --资产成本要素
       t1.acco_code, --会计科目
       t1.reso_code, --资源代码
       t1.intern_code, --内部订单
       t1.asset_classify_code, --资产特级号
       t1.asset_classify_desc, --资产特级号名称描述
       (t1.reso_amt * nvl(t2.zb_qty,1)) reso_amt, --金额
       t1.source_code, --系统来源(SAP,FCM)
       t1.fcm_type, --FCM成本费用要素类型
       t1.acti_code, --作业代码           
       t1.fm_thr_code, --起飞机场3字码
       t1.to_thr_code, --落地机场3字码
       t1.is_cur_fly, --是否当月航班
       t1.std, --计划起飞时间
       t1.flag_code --标识(1:成功)
from tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp002 t1
	left join (select * from dm_air_dw.air_abc_fact_own_bulk_zb where type_code='T02' and inc_month='${v_month}'  and to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')) t2
		on t1.dept_thr_code=t2.airport_thr_code and split(t1.reso_code,'_')[1]=substring(t2.zy_type_code,-2,2);


		  
----step3： 资源基表数据写入资源结果表（SAP_ZC）
insert overwrite table dm_air_dw.air_abc_bsl_reso_base partition
  (inc_sys_src = 'SAP_ZC', inc_month = '${v_month}')
select t1.month, --月份
       t1.cost_code, --成本中心
       t1.dept_thr_code, --成本中心3字码
       t1.zc_type, --资产成本要素
       t1.asset_classify_code, --资产特级号
       t1.asset_classify_desc, --资产特级号名称描述
       t1.acco_code, --会计科目
       t3.acco_name, --会计名称
       t1.reso_code, --资源代码
       t2.reso_name, --资源名称
       cast(null as string) fly_no, --飞机号
       t1.intern_code, --内部订单
       t1.reso_amt, --金额
       t1.source_code, --系统来源(SAP,FCM)
       t1.fcm_type, --FCM成本费用要素类型
       cast(null as string) acti_code, --作业代码     
       cast(null as string) acti_name, --作业名       
       t1.fm_thr_code, --起飞机场3字码
       t1.to_thr_code, --落地机场3字码
       t1.is_cur_fly, --是否当月航班
       t1.std, --计划起飞时间
       case
         when t1.flag_code = 1 and t1.reso_code in ('ZY092', 'ZY093') then
          1
         when t1.flag_code = 1 and t1.reso_code in ('ZY017', 'ZY043', 'ZY044', 'ZY130','ZY163_01','ZY163_02') and
              t1.cost_code in ('EX00009', 'EX00020', 'EX00005') then
          1
         when t1.flag_code = 1 and t1.reso_code in ('ZY163_02') and
              t1.cost_code in ('EX00009', 'EX00005') then
          1
         when t1.flag_code = 1 and t1.reso_code = 'ZY026' and
              t1.cost_code in ('EX00002', 'EX00005') then
          1
         else
          0
       end as flag_code, --标识(1:成功)
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间  
  from tmp_dm_air_dw.air_abc_bsl_reso_base_zc_tmp003 t1
  left join dm_air_dw.air_abc_rel_reso t2
    on t1.reso_code = t2.reso_code
  left join (select trim(acco_code) acco_code, acco_name
               from dm_air_dw.air_abc_rel_acco
              group by trim(acco_code), acco_name) t3
    on t1.acco_code = t3.acco_code;
	
insert overwrite table dm_air_dw.air_abc_bsl_reso_base partition
  (inc_sys_src = 'UPLOAD', inc_month = '${v_month}')
select t1.month, --月份
       t1.cost_code, --成本中心
       t1.dept_thr_code, --成本中心3字码
       cast(null as string) zc_type, --资产成本要素
       cast(null as string) asset_classify_code, --资产特级号
       cast(null as string) asset_classify_desc, --资产特级号名称描述
       t1.acco_code, --会计科目
       t3.acco_name, --会计名称
       t1.reso_code, --资源代码
       t2.reso_name, --资源名称
       t1.fly_no, --飞机号
       nvl(t1.intern_code, 'ALL') intern_code, --内部订单
       t1.reso_amt, --金额
       'UPLOAD' source_code, --系统来源(SAP,FCM)
       cast(null as string) fcm_type, --FCM成本费用要素类型
       cast(null as string) acti_code, --作业代码     
       cast(null as string) acti_name, --作业名       
       cast(null as string) fm_thr_code, --起飞机场3字码
       cast(null as string) to_thr_code, --落地机场3字码
       cast(null as string) is_cur_fly, --是否当月航班
       cast(null as string) std, --计划起飞时间
       nvl(t1.flag_code, 1) flag_code, --标识(1:成功)
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间  
  from dm_air_dw.air_abc_fact_reso_base_upload t1
  left join dm_air_dw.air_abc_rel_reso t2
    on t1.reso_code = t2.reso_code
  left join (select trim(acco_code) acco_code, acco_name
               from dm_air_dw.air_abc_rel_acco
              group by trim(acco_code), acco_name) t3
    on t1.acco_code = t3.acco_code
	where t1.inc_month = '${v_month}' and t1.month = '${v_month}';