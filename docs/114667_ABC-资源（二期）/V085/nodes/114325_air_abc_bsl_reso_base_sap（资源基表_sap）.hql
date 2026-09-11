--#####################################################################
--程序说明
--sysname:  货航ABC
--purpose:  资源基表_SAP
--author:   刘直

--parameters:
--${v_proc_name}: dm_air_dw.air_abc_bsl_reso_base_sap
--${v_month}:     统计月份(yyyymm)     --$[time(yyyyMM,-1M)]
--${v_date}:      统计日期(yyyymmdd)   --$[time(yyyyMMdd,-1d)]      
--${v_fm_dt}:     开始日期(yyyy-mm-dd) --$[time(yyyy-MM-01,-1M)]
--${v_to_dt}:     结束日期(yyyy-mm-dd) --$[time(yyyy-MM-01)]
--${v_mode_code}: 模型代码(100)

--description
--date                  author     drive
--2018-12-08            刘直       资源基表_SAP
                         
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
--step1.飞机号统计航班次数
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp00;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp00 stored as parquet as
select a.ac_reg,
       sum(case
             when a.flight_id is null then
              0
             else
              1
           end) fly_cnt
  from dm_air_dw.air_abc_fact_flight_info a
 where a.inc_month = '${v_month}'
   and regexp_replace(substr(trim(a.std),1,7),'-','') = '${v_month}'
   and nvl(a.flg_cs, 'XXX') not in ('C', 'D')
   and nvl(a.adjust_type, 'XXX') not in ('V', 'R')
   and nvl(a.flight_type, 'XXX') in
       ('N', 'J', 'A', 'T', 'B', 'X', 'D', 'S')
   and a.fuel_on_time in ('A01','A02','A03')
   and a.ac_reg is not null
 group by a.ac_reg;
 
--step1.部件履历基表按部件序号统计航班次数
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp01;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp01 stored as parquet as
select a.sn,
    --   a.pn_sn,
       sum(case
             when a.flight_id is null then
              0
             else
              1
           end) fly_cnt
  from dm_air_dw.air_abc_bsl_comp_info a
 where a.inc_month = '${v_month}'
   and a.month = '${v_month}'
  and (case when a.inc_month = '202102' and a.sn = '704630'
                then  a.pn_sn <> 'CF6-80C2B7F+704630'
            when a.inc_month = '202103' and a.sn = '706543'
                then  a.pn_sn <> 'CF6-80C2B7F+706543'
            when a.inc_month in ('202205','202206') and a.sn = '706892'
                then  a.pn_sn <> 'CF6-80C2B5F+706892' else 1=1 end )
 group by a.sn
 -- , a.pn_sn
 ;

--step2.机队统计航班次数
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp02;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp02 stored as parquet as
select c.fleet_code_lev1,
       sum(case
             when a.flight_id is null then
              0
             else
              1
           end) fleet_cnt
  from dm_air_dw.air_abc_fact_flight_info a
  left join dm_air_dw.air_abc_rel_fleet_list c --20190418修改机队直接取至航班，字段：ac_type航班机型
    ----on concat(substr(a.ac_type, 2, 2), '7') =regexp_replace(c.fleet_code_lev1, 'T', '')
	on a.mp_ac_type_t =c.fleet_code_lev1   --20250109 B73N任务改造
 where nvl(a.flg_cs, 'XXX') not in ('C', 'D')
   and nvl(a.adjust_type, 'XXX') not in ('V', 'R')
   and nvl(a.flight_type, 'XXX') in
       ('N', 'J', 'A', 'T', 'B', 'X', 'D', 'S')
   and a.fuel_on_time in ('A01','A02','A03')
   and a.inc_month = '${v_month}'
   and regexp_replace(substr(a.std, 1, 7), '-', '') = '${v_month}'
 group by c.fleet_code_lev1;
 
--step3.生成资源临时表
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp03;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp03 
(
profit_code string comment '',
company_code string comment '',
cost_center string comment '',
voucher_number string comment '',
voucher_type string comment '',
is_yn string comment '',
is_desc string comment '',
voucher_desc string comment '',
remark string comment '',
acco_code string comment '',
tran_acco_code string comment '',
func_code string comment '',
intern_code string comment '',
intern_code_fleet string comment '',
intern_code_new string comment '',
base_currency string comment '',
base_currency_amt string comment '',
post_date string comment '',
month_code string comment '',
pn_sn string comment '',
fly_no string comment '',
is_comp_info string comment '',
is_fly_cnt string comment '',
is_reg_cnt string comment '',
is_fleet_cnt string comment ''
)
stored as Parquet
;

drop table tmp_dm_air_dw.air_abc_dim_ac_reg_tmp1;
create table tmp_dm_air_dw.air_abc_dim_ac_reg_tmp1 as 
select t.ac_reg
  from dm_air_dw.air_abc_dim_ac_reg t
 group by t.ac_reg;

insert overwrite table  tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp03 
select a.profit_code,
       a.company_code,
       a.cost_center,
       a.voucher_number,
       a.voucher_type,
       case
         when a.voucher_type = 'YN' then
          1
         else
          0
       end is_yn,
       case  
         when a.month<'202008' and a.voucher_desc like '%航材%' then
          'A01_1'
         when a.month<'202008' and nvl(a.voucher_desc, 'XXX') not like '%航材%' then
		  'A01_0'
         when substr(a.alloc_nmbr,1,2)='ME' then
          'A01_0'
         else
		  'A01_1'
       end is_desc,
       a.voucher_desc,
       a.remark,
       a.acco_code,
       case
         when substr(a.acco_code, 1, 6) = '640101' then
          '640101*'
         else
          a.acco_code
       end tran_acco_code,
       a.func_code,
       a.intern_code,
       nvl(h.fleet_code_lev1, 'ALL') intern_code_fleet,
       coalesce(d.fleet_code_lev1, e.ac_reg, f.engi_code, 'ALL') as intern_code_new,
       a.base_currency,
       a.base_currency_amt,
       a.post_date,
       a.month month_code,
       b.sn, --发动机号
       e.ac_reg fly_no, --飞机号
       case
         when b.sn is not null then
          1
         when f.engi_code is not null and b.sn is null then
          0
         when substr(a.intern_code, 5, 1) = 'E' then
          0
         else
          2
       end is_comp_info, --是否存在部件履历表
       case
         when nvl(b.fly_cnt, 0) > 0 then
          1
         when f.engi_code is not null and b.sn is null then
          0
         when substr(a.intern_code, 5, 1) = 'E' then
          0
         else
          2
       end is_fly_cnt, --发动机航班ID数
       case
         when nvl(g.fly_cnt, 0) > 0 then
          1
         when substr(a.intern_code, 5, 1) in ('M', 'B') then
          0
         else
          2
       end is_reg_cnt, --飞机号航班ID数
       case
         when nvl(c.fleet_cnt, 0) > 0 then
          1
         when h.fleet_code_lev1 is not null then
          0
         else
          2
       end is_fleet_cnt --机队航班ID数
  from dm_air_dw.air_abc_fact_acco_sap a
  left join tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp01 b
    on case when substr(a.intern_code, 5, 3) = 'ESN' THEN substr(a.intern_code, 8)
   WHEN substr(a.intern_code, 5, 1) = 'E' THEN substr(a.intern_code, 6) END = b.sn
  left join dm_air_dw.air_abc_rel_fleet_list h
    on substr(a.intern_code, 1, 4) = h.fleet_code_lev1
  left join tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp02 c
    on substr(a.intern_code, 1, 4) = c.fleet_code_lev1
  left join dm_air_dw.air_abc_rel_fleet_list d
    on a.intern_code = d.fleet_code_lev1
  left join tmp_dm_air_dw.air_abc_dim_ac_reg_tmp1 e
    on case
         when substr(a.intern_code, 5, 3) = 'MSN' then
          regexp_replace(substr(a.intern_code, 5), '-', '')
         when substr(a.intern_code, 5, 1) = 'B' then
          regexp_replace(substr(a.intern_code, 5), '-', '')
         when substr(a.intern_code, 5, 1) = 'M' and
              substr(a.intern_code, 5, 3) <> 'MSN' then
          regexp_replace(regexp_replace(substr(a.intern_code, 5), 'M', 'MSN'),
                         '-',
                         '')
         else
          regexp_replace(substr(a.intern_code, 5), '-', '')
       end = regexp_replace(e.ac_reg, '-', '')
   and substr(a.intern_code, 5, 1) in ('M', 'B')
  left join dm_air_dw.air_abc_dim_engi_code f
    on case when substr(a.intern_code, 5, 3) = 'ESN' THEN substr(a.intern_code, 8)
   WHEN substr(a.intern_code, 5, 1) = 'E' THEN substr(a.intern_code, 6) END = f.sn
   and f.inc_month = '${v_month}'
  left join tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp00 g
    on case
         when substr(a.intern_code, 5, 3) = 'MSN' then
          regexp_replace(substr(a.intern_code, 5), '-', '')
         when substr(a.intern_code, 5, 1) = 'B' then
          regexp_replace(substr(a.intern_code, 5), '-', '')
         when substr(a.intern_code, 5, 1) = 'M' and
              substr(a.intern_code, 5, 3) <> 'MSN' then
          regexp_replace(regexp_replace(substr(a.intern_code, 5), 'M', 'MSN'),
                         '-',
                         '')
         else
          regexp_replace(substr(a.intern_code, 5), '-', '')
       end = regexp_replace(g.ac_reg, '-', '')
   and substr(a.intern_code, 5, 1) in ('M', 'B')
 where case
         when '${v_month}' >= '201901' then
          a.inc_type = 'SYSTEM' and a.gb_type >= 1 and
          a.inc_month = '${v_month}'
         else
          a.inc_type = 'UPLOAD' and a.inc_month = '201812'
       end --UPLOAD分区，线下全量手工数据（201801-201812），SYSTEM分区，线上数据,201901以后
   and a.month = '${v_month}';


--step4.生成资源SAP基表
drop table if exists tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp04;
create table tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp04 stored as parquet as
select t1.month_code,
       t1.profit_code,
       t1.company_code,
       t1.cost_center,
       t1.acco_code,
       t1.voucher_number,
       t1.voucher_type,
	   t1.voucher_desc,
	   t1.remark,
       t1.intern_code,
       case
         when t1.tran_acco_code = '640101*' then
          t1.intern_code_new
         else
          nvl(t2.intern_code_new, 'ALL')
       end intern_code_new,
       t1.is_yn, --凭证是否YN
	   t1.is_desc,  --是否行文本
       t1.is_comp_info, --是否存在部件履历表
       t1.is_fly_cnt, --发动机航班ID数
	   t1.is_reg_cnt, --飞机号航班ID数
       t1.is_fleet_cnt, --机队航班ID数
       t1.pn_sn,
       t1.fly_no,
       t1.base_currency,
       t1.base_currency_amt,   
       case
         when t1.tran_acco_code = '640101*' and t1.cost_center = 'EX00004' and
              (t1.intern_code <> '' and t1.intern_code <> ' ' and t1.intern_code is not null) then
          'ZY001'
         when t1.tran_acco_code = '640101*' and t1.cost_center = 'EX00004' and
              (t1.intern_code = '' or t1.intern_code = ' ' or t1.intern_code is null) then
          'ZY011'
         when t1.tran_acco_code = '640101*' and t1.cost_center <> 'EX00004' then
          'ZY011'
		 when substr(t1.tran_acco_code, 1, 6) = '640115' and t1.cost_center in ('EX00011AA', 'EX00029AA') then
          'ZY144'
		 when substr(t1.tran_acco_code, 1, 6) = '640163' and t1.cost_center in ('EX00011AA', 'EX00029AA') then
          'ZY145'
		 when substr(t1.tran_acco_code, 1, 6) = '640164' and t1.cost_center in ('EX00011AA', 'EX00029AA') then
          'ZY146'
		 when substr(t1.tran_acco_code, 1, 6) in ('640111', '640112', '640114') and t1.cost_center in ('EX00011AA', 'EX00029AA') then
          'ZY147'
		 when substr(t1.tran_acco_code, 1, 1) = '6' and t1.cost_center in ('EX00011AA', 'EX00029AA') and substr(t1.tran_acco_code, 1, 4) not in ('6402','6051')  then
          'ZY143'
         else
          t2.reso_code
       end as reso_code
  from tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp03 t1
  left join (select t.month_code,
                    t.profit_code,
                    t.company_code,
                    t.cost_center,
                    t.acco_code,
                    t.tran_acco_code,
					t.voucher_number,
                    t.voucher_type,
					t.voucher_desc,
					t.remark,
                    t.intern_code,
                    t.intern_code_new,
                    t.reso_code,
                    t.is_yn, --凭证是否YN
					t.is_desc, --是否行文本
                    t.is_comp_info, --是否存在部件履历表
                    t.is_fly_cnt, --航班ID数(发动机)
                    t.is_fleet_cnt, --机队航班ID数
                    t.is_reg_cnt, --飞机号航班ID数
                    t.intern_code_fleet, --机队内部订单
                    row_number() over(partition by t.partition_col order by t.order_comp) rn
               from (select a.profit_code,
                            a.company_code,
			                a.cost_center,
			                a.voucher_number,
                            a.voucher_type,
							a.voucher_desc,
							a.remark,
                            a.is_yn, --凭证是否YN
							a.is_desc, --是否行文本
                            a.acco_code,
                            a.tran_acco_code,
                            a.intern_code,
                            case
                              when e.type_code is not null and
                                   a.is_fly_cnt = 1 then
                               a.intern_code_new
                              when e.type_code is not null and
                                   a.is_reg_cnt = 1 then
                               a.intern_code_new
                              when e.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when e.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when e.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when e.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'  
                              when e.type_code is not null and
                                   a.is_fly_cnt = 2 and a.is_reg_cnt = 2 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when g.type_code is not null and
                                   a.is_fly_cnt = 1 then
                               a.intern_code_new
                              when g.type_code is not null and
                                   a.is_reg_cnt = 1 then
                               a.intern_code_new
                              when g.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when g.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when g.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when g.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when g.type_code is not null and
                                   a.is_fly_cnt = 2 and a.is_reg_cnt = 2 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when c1.type_code is not null and
                                   a.is_fly_cnt = 1 then
                               a.intern_code_new
                              when c1.type_code is not null and
                                   a.is_reg_cnt = 1 then
                               a.intern_code_new
                              when c1.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when c1.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when c1.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when c1.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when c1.type_code is not null and
                                   a.is_fly_cnt = 2 and a.is_reg_cnt = 2 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when b1.type_code is not null and
                                   a.is_fly_cnt = 1 then
                               a.intern_code_new
                              when b1.type_code is not null and
                                   a.is_reg_cnt = 1 then
                               a.intern_code_new
                              when b1.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when b1.type_code is not null and
                                   a.is_fly_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when b1.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 1 then
                               a.intern_code_fleet
                              when b1.type_code is not null and
                                   a.is_reg_cnt = 0 and a.is_fleet_cnt = 0 then
                               'ALL'
                              when b1.type_code is not null and
                                   a.is_fly_cnt = 2 and a.is_reg_cnt = 2 and a.is_fleet_cnt = 0 then
                               'ALL'
                              else
                               a.intern_code_new
                            end intern_code_new,
                            a.month_code,
                            a.is_comp_info, --是否存在部件履历表
                            a.is_fly_cnt, --航班ID数
                            a.is_fleet_cnt, --机队航班ID数
                            a.is_reg_cnt, --航班ID数(飞机号)
                            a.intern_code_fleet, --机队内部订单
                            case
                              when e.reso_code is not null then
                               e.reso_code
                              when d.reso_code is not null then
                               d.reso_code
                              when f.reso_code is not null then
                               f.reso_code
                              when g.reso_code is not null then
                               g.reso_code
                              when c1.reso_code is not null then
                               c1.reso_code
                              when c.reso_code is not null then
                               c.reso_code
                              when b1.reso_code is not null then
                               b1.reso_code
                              when b.reso_code is not null then
                               b.reso_code
                            end reso_code,
                            concat(nvl(a.profit_code, ''),
							       nvl(a.company_code, ''),
							       nvl(a.cost_center, ''),
							       nvl(a.voucher_number, ''),
                                   nvl(a.voucher_type, ''),
								   nvl(a.voucher_desc, ''),
								   nvl(a.remark, ''),
                                   nvl(a.is_yn, ''),
								   nvl(a.is_desc, ''),
                                   nvl(a.acco_code, ''),
                                   nvl(a.tran_acco_code, ''),
                                   nvl(a.intern_code, ''),
                                   nvl(a.intern_code_new, ''),
                                   nvl(a.month_code, ''),
                                   nvl(a.is_comp_info, ''),
                                   nvl(a.is_fly_cnt, ''),
                                   nvl(a.is_fleet_cnt, ''),
                                   nvl(a.is_reg_cnt, ''),
                                   nvl(a.intern_code_fleet, '')) partition_col,
                            case
                              when e.type_code is not null then
                               e.type_code
                              when d.type_code is not null then
                               d.type_code
                              when f.type_code is not null then
                               f.type_code
                              when g.type_code is not null then
                               g.type_code
                              when c1.type_code is not null then
                               c1.type_code
                              when c.type_code is not null then
                               c.type_code
                              when b1.type_code is not null then
                               b1.type_code
                              when b.type_code is not null then
                               b.type_code
                            end order_comp
                       from tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp03 a
                       left join dm_air_dw.air_abc_rel_reso_cfg b
                         on a.acco_code = b.acco_code
                        and to_date(b.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(b.end_tm) >= to_date('${v_fm_dt}')
                        and b.type_code = '1' --科目
                       left join dm_air_dw.air_abc_rel_reso_cfg b1
                         on a.acco_code = b1.acco_code
                        and to_date(b1.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(b1.end_tm) >= to_date('${v_fm_dt}')
                        and b1.type_code = '6' --科目(内部订单无航班处理)
                       left join dm_air_dw.air_abc_rel_reso_cfg c
                         on a.acco_code = c.acco_code
                        and a.is_yn = c.voucher_type
                        and to_date(c.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(c.end_tm) >= to_date('${v_fm_dt}')
                        and c.type_code = '2' --科目+凭证
                       left join dm_air_dw.air_abc_rel_reso_cfg c1
                         on a.acco_code = c1.acco_code
                        and a.is_yn = c1.voucher_type
                        and to_date(c1.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(c1.end_tm) >= to_date('${v_fm_dt}')
                        and c1.type_code = '4' --科目+凭证(内部订单无航班处理)
                       left join dm_air_dw.air_abc_rel_reso_cfg d
                         on a.acco_code = d.acco_code
                        and a.cost_center = d.cost_code
                        and a.is_yn = d.voucher_type
                        and to_date(d.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(d.end_tm) >= to_date('${v_fm_dt}')
                        and d.type_code = '3' --科目+成本中心+凭证
                       left join dm_air_dw.air_abc_rel_reso_cfg f
                         on a.acco_code = f.acco_code
                        and a.cost_center = f.cost_code
                        and a.is_yn = f.voucher_type
                        and to_date(f.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(f.end_tm) >= to_date('${v_fm_dt}')
                        and f.type_code = '7' --科目+剔除部分成本中心+凭证
                       left join dm_air_dw.air_abc_rel_reso_cfg g
                         on a.acco_code = g.acco_code
                        and a.is_desc = g.voucher_desc_c
                        and a.is_yn = g.voucher_type
                        and to_date(g.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(g.end_tm) >= to_date('${v_fm_dt}')
                        and g.type_code = '8' --科目+行文本+凭证(内部订单无航班处理)
                       left join dm_air_dw.air_abc_rel_reso_cfg e
                         on a.acco_code = e.acco_code
                        and case when a.is_fly_cnt = 2 then 0 else a.is_fly_cnt end = e.flight_range
                        and to_date(e.start_tm) <= to_date('${v_fm_dt}')
                        and to_date(e.end_tm) >= to_date('${v_fm_dt}')
                        and e.type_code = '5' --科目+航班ID数(内部订单无航班处理)
                     ) t) t2
    on t1.month_code = t2.month_code
   and t1.acco_code = t2.acco_code
   and nvl(t1.profit_code, 'XXX') = nvl(t2.profit_code, 'XXX')
   and nvl(t1.company_code, 'XXX') = nvl(t2.company_code, 'XXX')
   and nvl(t1.cost_center, 'XXX') = nvl(t2.cost_center, 'XXX')
   and nvl(t1.voucher_number, 'XXX') = nvl(t2.voucher_number, 'XXX')
   and nvl(t1.voucher_type, 'XXX') = nvl(t2.voucher_type, 'XXX')
   and nvl(t1.voucher_desc, 'XXX') = nvl(t2.voucher_desc, 'XXX')
   and nvl(t1.remark, 'XXX') = nvl(t2.remark, 'XXX')
   and nvl(t1.intern_code, 'XXX') = nvl(t2.intern_code, 'XXX')
   and nvl(t1.is_yn, 'XXX') = nvl(t2.is_yn, 'XXX')
   and nvl(t1.is_desc, 'XXX') = nvl(t2.is_desc, 'XXX')
   and nvl(t1.is_comp_info, 'XXX') = nvl(t2.is_comp_info, 'XXX')
   and nvl(t1.is_fly_cnt, 'XXX') = nvl(t2.is_fly_cnt, 'XXX')
   and nvl(t1.is_fleet_cnt, 'XXX') = nvl(t2.is_fleet_cnt, 'XXX')
   and nvl(t1.is_reg_cnt, 'XXX') = nvl(t2.is_reg_cnt, 'XXX')
   and nvl(t1.intern_code_fleet, 'XXX') = nvl(t2.intern_code_fleet, 'XXX')
   and t2.rn = 1;
   
----step5： 资源基表数据写入SAP资源基表 
 insert overwrite table dm_air_dw.air_abc_bsl_reso_base_sap partition
  (inc_month = '${v_month}')
 select t1.month_code month, --月份
       t1.profit_code, --利润中心
       t1.company_code, --公司代码
       t1.cost_center, --成本中心
       t1.acco_code, --科目
	   t1.voucher_number, --凭证号
       t1.voucher_type, --凭证类型
       t1.voucher_desc, --行文本
       t1.remark, --备注 
       t1.intern_code, --内部订单
       t1.intern_code_new, --转换后的内部订单
       t1.is_yn, --凭证是否YN
       t1.is_comp_info, --是否存在部件履历表
       t1.is_fly_cnt, --发动机航班ID数
	   t1.is_reg_cnt, --飞机号航班ID数
       t1.is_fleet_cnt, --机队航班ID数
       t1.pn_sn, --发动机号
       t1.fly_no, --飞机号
       t1.base_currency, --币种
       t1.base_currency_amt, --金额
       t1.reso_code, --资源代码
       t2.reso_name, --资源名
       case
         when substr(t1.acco_code, 1, 4) = '6301' and t1.cost_center in ('EX00011AA', 'EX00029AA')  then
          0
         when substr(t1.acco_code, 1, 4) in ('6131','6801','6999') and t1.cost_center in ('EX00011AA', 'EX00029AA')  then  --add cwz 20210709
          0
         when substr(t1.acco_code, 1, 2)='67' and t1.cost_center in ('EX00011AA', 'EX00029AA')  then
          0
         when t1.reso_code is not null then
          1
         else
          0
       end as flag_code, --标识(1:成功)
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间
  from tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp04 t1
  left join dm_air_dw.air_abc_rel_reso t2
  on t1.reso_code = t2.reso_code;
 
 ----step6： 资源基表数据写入资源基表（SAP）
 insert overwrite table dm_air_dw.air_abc_bsl_reso_base partition
  (inc_sys_src = 'SAP', inc_month = '${v_month}')
select t1.month_code as month, --月份
       t1.cost_center as cost_code, --成本中心
       t2.airport_thr_code as dept_thr_code, --成本中心3字码
       cast(null as string) as zc_type, --资产成本要素
       cast(null as string) as asset_classify_code, --资产特级号
       cast(null as string) as asset_classify_desc, --资产特级号名称描述
       t1.acco_code, --会计科目
       t4.acco_name, --会计科目名称
       t1.reso_code, --资源代码
       t3.reso_name, --资源名称
	    case
         when t5.reso_code is not null then
          t1.fly_no
         else
          cast(null as string)
       end fly_no,
       t1.intern_code_new as intern_code, --内部订单
       sum(nvl(t1.base_currency_amt, 0)) as reso_amt, --金额
       'SAP' as source_code, --系统来源(SAP,FCM)
       cast(null as string) as fcm_type, --FCM成本费用要素类型
       cast(null as string) as acti_code, --作业代码     
       cast(null as string) as acti_name, --作业名       
       cast(null as string) as fm_thr_code, --起飞机场3字码
       cast(null as string) as to_thr_code, --落地机场3字码
       '2' as is_cur_fly, --是否当月航班
       cast(null as string) as std, --计划起飞时间
       case
         when substr(t1.acco_code, 1, 4) = '6301' and t1.cost_center in ('EX00011AA', 'EX00029AA')  then
          0
        when substr(t1.acco_code, 1, 4) in ('6131','6801','6999') and t1.cost_center in ('EX00011AA', 'EX00029AA')  then  --add cwz 20210709
          0
        when substr(t1.acco_code, 1, 2)='67' and t1.cost_center in ('EX00011AA', 'EX00029AA')  then
          0
         when t1.reso_code is not null then
          1
         else
          0
       end as flag_code, --标识(1:成功)
       from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_time --加载时间  
  from tmp_dm_air_dw.air_abc_bsl_reso_base_sap_tmp04 t1
  left join dm_air_dw.air_abc_rel_air_port_city_code t2
    on t1.cost_center = t2.cost_code
	and to_date(t2.start_tm) <= to_date('${v_fm_dt}')
	and to_date(t2.end_tm) >= to_date('${v_fm_dt}')
  left join dm_air_dw.air_abc_rel_reso t3
    on t1.reso_code = t3.reso_code
  left join (select trim(acco_code) acco_code, acco_name
               from dm_air_dw.air_abc_rel_acco
              group by trim(acco_code), acco_name) t4
    on t1.acco_code = t4.acco_code
 left join (select reso_code
               from dm_air_dw.air_abc_rel_intern
              where dist_type = 'RA01'
                and type_code = 2
                and mode_code = '${v_mode_code}'
                and to_date(start_tm) <= to_date('${v_fm_dt}')
                and to_date(end_tm) >= to_date('${v_fm_dt}')
              group by reso_code) t5
    on t1.reso_code = t5.reso_code
 group by t1.month_code,
          t1.cost_center,
          t2.airport_thr_code,
          t4.acco_name,
          t1.acco_code,
          t1.reso_code,
          t3.reso_name,
           case
         when t5.reso_code is not null then
          t1.fly_no
         else
          cast(null as string)
       end,
          t1.intern_code_new,
          case
           when substr(t1.acco_code, 1, 4) = '6301' and t1.cost_center in ('EX00011AA', 'EX00029AA') then
             0
           when substr(t1.acco_code, 1, 4) in ('6131','6801','6999') and t1.cost_center in ('EX00011AA', 'EX00029AA')  then  --add cwz 20210709
             0
           when substr(t1.acco_code, 1, 2)='67' and t1.cost_center in ('EX00011AA', 'EX00029AA')  then
             0
            when t1.reso_code is not null then
             1
            else
             0
          end;
