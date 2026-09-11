--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  间接人工资源拆分
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_fact_indirect_labor
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--100: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       间接人工资源拆分
--2022-08-03            chenweizhen  鄂州武汉拆库区作业和站坪服务和管理支持
--20220-09-09           chenweizhen  鄂州项目的这个是之前说的都有航班 但是8月没有航班运控 所以保守起见 今年先不启用新规则 明年航班量稳定之后再切换      先注释EX00030相关代码 等2023启用
                         
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
----将深圳北京杭州的拖头车数据单独取出
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor0001;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor0001 stored as parquet as
select cost_code,acti_code_lev3,sum(acti_lev3_zb) driv_qty
  from dm_air_dw.air_abc_fact_detp_upload_info
where cost_code in ('EX00005','EX00009','EX00020') and posi_name='特种车司机' and month='${v_month}' and inc_month='${v_month}'
group by cost_code,acti_code_lev3;

----拆分拖头车司机数据为库区作业和站坪服务
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor0002;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor0002 stored as parquet as
select a.cost_code
    ,b.airport_thr_code
    ,nvl(c.after_acti_code,a.acti_code_lev3) acti_code_lev3
    ,a.driv_qty * nvl(c.zb_qty,1) driv_qty
from tmp_dm_air_dw.air_abc_fact_indirect_labor0001 a
    left join dm_air_dw.air_abc_rel_air_port_city_code b 
        on a.cost_code=b.cost_code
    and to_date(b.start_tm) <= to_date('${v_fm_dt}')
    and to_date(b.end_tm) >= to_date('${v_fm_dt}')
    left join (select * from dm_air_dw.AIR_ABC_FACT_KQ_ZP_ZB where inc_month='${v_month}' and to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')) c
        on b.airport_thr_code=c.airport_thr_code and a.acti_code_lev3=c.bef_acti_code;

--关联自有散航占比表
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor0003;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor0003 stored as parquet as
select c.cost_code
    ,e.reso_code
    ,c.airport_thr_code
    ,c.acti_code_lev3
    ,c.driv_qty * d.zb_qty driv_qty
from tmp_dm_air_dw.air_abc_fact_indirect_labor0002 c
    left join (select * from dm_air_dw.air_abc_fact_own_bulk_zb where type_code='T01' and inc_month='${v_month}' and to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')) d
        on c.acti_code_lev3=d.acti_code and c.airport_thr_code=d.airport_thr_code
    left join (select b.reso_code,b.own_free_code,a.fm_cost_code cost_code,a.to_acti_code
                from dm_air_dw.AIR_ABC_REL_RESO b
               left join dm_air_dw.air_abc_rel_ra_dist a
                    on a.fm_reso_code=b.reso_code
                where fm_cost_code in('EX00005','EX00009','EX00020') and a.mode_code = '${v_mode_code}'
                    and to_date(a.start_tm) <= to_date('${v_fm_dt}')
                    and to_date(a.end_tm) >= to_date('${v_fm_dt}')
                    ) e 
        on d.zy_type_code=e.own_free_code and c.cost_code=e.cost_code and e.to_acti_code=c.acti_code_lev3
    inner join (select reso_code
                from dm_air_dw.air_abc_rel_reso_cfg
               where substr(acco_code, 1, 6) = '640101'
                 and nvl(reso_code, 'ZY001') <> 'ZY001'
                 and trim(mode_code) = '${v_mode_code}'
               group by reso_code) m
        on e.reso_code = m.reso_code;   
        
----占比表去除拖头车数据
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor0004;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor0004 stored as parquet as
select * ,row_number() over () rank
 from dm_air_dw.air_abc_fact_detp_upload_info a 
where a.inc_month='${v_month}' and a.month='${v_month}';


--鄂州武汉拆库区作业和站坪服务和管理支持  add by cwz 20220803
--20220909注释掉 待2023启用
--------drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_wuh_labor0004;
--------create table tmp_dm_air_dw.air_abc_fact_indirect_wuh_labor0004 stored as parquet as
--------select c.cost_code      as cost_code     --成本中心
--------    ,e.reso_code        as reso_code     --资源代码
--------    ,c.airport_thr_code as intern_code   --内部订单
--------    ,c.acti_code_lev3   as acti_code     --作业代码
--------    ,c.driv_qty         as driv_qty      --动因量
--------from (select cost_code,acti_code_lev3,load_tm as airport_thr_code,sum(acti_lev3_zb) as driv_qty from tmp_dm_air_dw.air_abc_fact_indirect_labor0004 t where cost_code='EX00030' group by cost_code,acti_code_lev3,load_tm) c 
--------    left join (select b.reso_code,a.fm_cost_code cost_code,a.to_acti_code,b.remark2 as airport_thr_code
--------                from dm_air_dw.AIR_ABC_REL_RESO b
--------               left join dm_air_dw.air_abc_rel_ra_dist a
--------                    on a.fm_reso_code=b.reso_code
--------                where fm_cost_code in('EX00030') and a.mode_code = '${v_mode_code}'
--------                    and to_date(a.start_tm) <= to_date('${v_fm_dt}')
--------                    and to_date(a.end_tm) >= to_date('${v_fm_dt}')
--------                    ) e 
--------        on c.cost_code=e.cost_code and e.to_acti_code=c.acti_code_lev3 and c.airport_thr_code=e.airport_thr_code
--------    inner join (select reso_code
--------                from dm_air_dw.air_abc_rel_reso_cfg
--------               where substr(acco_code, 1, 6) = '640101'
--------                 and nvl(reso_code, 'ZY001') <> 'ZY001'
--------                 and trim(mode_code) = '${v_mode_code}'
--------               group by reso_code) m
--------        on e.reso_code = m.reso_code; 


drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor0005;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor0005 stored as parquet as
select b.month, 
        split(b.cost_code,'_')[0] cost_code,
        split(b.cost_code,'_')[1] reso_code,
        b.intern_code,
        b.acti_code,
        b.driv_qty
  from dm_air_dw.air_abc_fact_ra_driv b
  where b.driv_code ='RA010'
      and b.acti_code in('B010070004','C010030004')
      and b.inc_month = '${v_month}'
      and b.month = '${v_month}';
----step0: 计算作业占比
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor000;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor000 stored as parquet as
 select a.month, 
        a.cost_code,
        'ALL' as intern_code,
        a.acti_code_lev3 acti_code,
        'RA007' as driv_code,
        sum(a.acti_lev3_zb) as driv_qty,
        from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm,
        a.month as inc_month,
        'RA007' as inc_driv_code
  from (select t1.* from tmp_dm_air_dw.air_abc_fact_indirect_labor0004 t1
            where nvl(rank,'XXX') not in (select rank from tmp_dm_air_dw.air_abc_fact_indirect_labor0004 t2 where t2.cost_code in ('EX00005','EX00009','EX00020') and t2.posi_name='特种车司机')
            --------and cost_code <> 'EX00030'   --add by cwz 20220803   --20220909注释掉 待2023启用
        ) a -- 部门作业占比表
  group by a.month,
           a.cost_code,
           a.acti_code_lev3
union all 
 select b.month, 
        b.cost_code,
        b.intern_code,
        b.acti_code,
        b.driv_code,
        b.driv_qty,
        b.load_tm,
        b.inc_month,
        b.inc_driv_code
  from dm_air_dw.air_abc_fact_ra_driv b
  where b.driv_code ='RA010'
      and nvl(b.acti_code,'XXX') not in('B010070004','C010030004')
      and b.inc_month = '${v_month}'
      and b.month = '${v_month}';
      
----step1： 处理间接人工作业占比
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor001;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor001 stored as parquet as
    select a.month,
           a.cost_code,
           a.acti_code,
           nvl(a.intern_code,'ALL') intern_code,
           sum(case
                 ----when a.cost_code in ('EX00011','EX00029') and a.driv_code = 'RA007' then --20220708临时修改，增加EX00029
                 when a.month<='202205' and a.cost_code in ('EX00011') and a.driv_code = 'RA007' then                   
                  0
                 when a.month>='202206' and a.cost_code in ('EX00029') and a.driv_code = 'RA007' then         --add by cwz 20220708
                  0
                 else
                  a.driv_qty
               end) driv_qty
      from tmp_dm_air_dw.air_abc_fact_indirect_labor000 a
     group by a.month, a.cost_code, a.acti_code, nvl(a.intern_code,'ALL');


----step2： 处理间接人工作业资源关系
drop table if exists tmp_dm_air_dw.air_abc_fact_indirect_labor002;
create table tmp_dm_air_dw.air_abc_fact_indirect_labor002 stored as parquet as
 select a.fm_cost_code cost_code, b.reso_code, a.to_acti_code acti_code
   from dm_air_dw.air_abc_rel_ra_dist a
  inner join (select reso_code
                from dm_air_dw.air_abc_rel_reso_cfg
               where substr(acco_code, 1, 6) = '640101'
                 and nvl(reso_code, 'ZY001') <> 'ZY001'
                 and trim(mode_code) = '${v_mode_code}'
               group by reso_code) b
     on a.fm_reso_code = b.reso_code
  where a.mode_code = '${v_mode_code}'
    and to_date(a.start_tm) <= to_date('${v_fm_dt}')
    and to_date(a.end_tm) >= to_date('${v_fm_dt}')
  group by a.fm_cost_code, b.reso_code, a.to_acti_code;


----step3： 间接人工资源拆分
insert overwrite table dm_air_dw.air_abc_fact_indirect_labor partition(inc_month = '${v_month}')
select '${v_month}' month,
       a.cost_code,
       d.cost_name,
       'ZY011' initial_reso_code,
       a.reso_code,
       c.reso_name,
       a.acti_code,
       e.acti_name_lev3 acti_name,
       b.intern_code,
       sum(nvl(b.driv_qty, 0)) driv_qty,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm
  from tmp_dm_air_dw.air_abc_fact_indirect_labor002 a
  inner join tmp_dm_air_dw.air_abc_fact_indirect_labor001 b
    on a.cost_code = b.cost_code
   and a.acti_code = b.acti_code
  left join dm_air_dw.air_abc_rel_reso c  --关联资源代码文字名
    on a.reso_code = c.reso_code
  left join dm_air_dw.air_abc_rel_air_port_city_code d  --关联成本中心信息
  on a.cost_code = d.cost_code
    and to_date(d.start_tm) <= to_date('${v_fm_dt}')
    and to_date(d.end_tm) >= to_date('${v_fm_dt}')      
  left join dm_air_dw.air_abc_rel_acti e
  on a.acti_code = e.acti_code_lev3
  where a.reso_code not in (select nvl(reso_code,'XXX') from tmp_dm_air_dw.air_abc_fact_indirect_labor0003
                           union ALL
                            select nvl(reso_code,'XXX') from tmp_dm_air_dw.air_abc_fact_indirect_labor0005
                           )
 group by a.cost_code, d.cost_name, a.reso_code, c.reso_name, a.acti_code, e.acti_name_lev3, b.intern_code
union all
select '${v_month}' month,
       a.cost_code,
       d.cost_name,
       'ZY011' initial_reso_code,
       a.reso_code,
       c.reso_name,
       a.acti_code_lev3 acti_code,
       e.acti_name_lev3 acti_name,
       'ALL' intern_code,
       sum(nvl(a.driv_qty, 0)) driv_qty,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm
  from tmp_dm_air_dw.air_abc_fact_indirect_labor0003 a
  inner join tmp_dm_air_dw.air_abc_fact_indirect_labor002 b
    on a.cost_code = b.cost_code
   and a.acti_code_lev3 = b.acti_code
   and a.reso_code = b.reso_code
  left join dm_air_dw.air_abc_rel_reso c  --关联资源代码文字名
    on a.reso_code = c.reso_code
  left join dm_air_dw.air_abc_rel_air_port_city_code d  --关联成本中心信息
  on a.cost_code = d.cost_code
    and to_date(d.start_tm) <= to_date('${v_fm_dt}')
    and to_date(d.end_tm) >= to_date('${v_fm_dt}')
  left join dm_air_dw.air_abc_rel_acti e
  on a.acti_code_lev3 = e.acti_code_lev3
 group by a.cost_code, d.cost_name, a.reso_code, c.reso_name, a.acti_code_lev3, e.acti_name_lev3 
 union all
select '${v_month}' month,
       a.cost_code,
       d.cost_name,
       'ZY011' initial_reso_code,
       a.reso_code,
       c.reso_name,
       a.acti_code acti_code,
       e.acti_name_lev3 acti_name,
       a.intern_code,
       sum(nvl(a.driv_qty, 0)) driv_qty,
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm
  from tmp_dm_air_dw.air_abc_fact_indirect_labor0005 a
  inner join tmp_dm_air_dw.air_abc_fact_indirect_labor002 b
    on a.cost_code = b.cost_code
   and a.acti_code = b.acti_code
   and a.reso_code = b.reso_code
  left join dm_air_dw.air_abc_rel_reso c  --关联资源代码文字名
    on a.reso_code = c.reso_code
  left join dm_air_dw.air_abc_rel_air_port_city_code d  --关联成本中心信息
  on a.cost_code = d.cost_code
    and to_date(d.start_tm) <= to_date('${v_fm_dt}')
    and to_date(d.end_tm) >= to_date('${v_fm_dt}')
  left join dm_air_dw.air_abc_rel_acti e
  on a.acti_code = e.acti_code_lev3
 group by a.cost_code, d.cost_name, a.reso_code, c.reso_name, a.acti_code, e.acti_name_lev3, a.intern_code
--------  union all                         --add by cwz 20220803 武汉鄂州拆分     --20220909注释掉 待2023启用
--------select '${v_month}' month,
--------       a.cost_code,
--------       d.cost_name,
--------       'ZY011' initial_reso_code,
--------       a.reso_code,
--------       c.reso_name,
--------       a.acti_code acti_code,
--------       e.acti_name_lev3 acti_name,
--------       a.intern_code,
--------       sum(nvl(a.driv_qty, 0)) driv_qty,
--------       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm
--------  from tmp_dm_air_dw.air_abc_fact_indirect_wuh_labor0004 a
--------  inner join tmp_dm_air_dw.air_abc_fact_indirect_labor002 b
--------    on a.cost_code = b.cost_code
--------   and a.acti_code = b.acti_code
--------   and a.reso_code = b.reso_code
--------  left join dm_air_dw.air_abc_rel_reso c  --关联资源代码文字名
--------    on a.reso_code = c.reso_code
--------  left join dm_air_dw.air_abc_rel_air_port_city_code d  --关联成本中心信息
--------  on a.cost_code = d.cost_code
--------    and to_date(d.start_tm) <= to_date('${v_fm_dt}')
--------    and to_date(d.end_tm) >= to_date('${v_fm_dt}')
--------  left join dm_air_dw.air_abc_rel_acti e
--------  on a.acti_code = e.acti_code_lev3
-------- group by a.cost_code, d.cost_name, a.reso_code, c.reso_name, a.acti_code, e.acti_name_lev3, a.intern_code
 ;