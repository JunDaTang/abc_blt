drop table if EXISTS tmp_dm_air_dw.air_abc_fact_reso_diff_tmp001;
create table tmp_dm_air_dw.air_abc_fact_reso_diff_tmp001 as
select month,cost_code,acco_code,acco_name,source_code,SUM(reso_amt) amt from  dm_air_dw.air_abc_fact_reso_list where inc_month = '${v_month}' and  month = '${v_month}' GROUP BY month,cost_code,acco_code,acco_name,source_code;

drop table if EXISTS tmp_dm_air_dw.air_abc_fact_reso_diff_tmp002;
create table tmp_dm_air_dw.air_abc_fact_reso_diff_tmp002 as
select month,cost_code,acco_code,acco_name,
str_to_map(concat_ws(',',collect_set(concat_ws(':',source_code,cast(amt as string)))))['SAP'] as SAP,
str_to_map(concat_ws(',',collect_set(concat_ws(':',source_code,cast(amt as string)))))['FCM'] as FCM,
str_to_map(concat_ws(',',collect_set(concat_ws(':',source_code,cast(amt as string)))))['UPLOAD'] as UPLOAD
from tmp_dm_air_dw.air_abc_fact_reso_diff_tmp001 group by month,cost_code,acco_code,acco_name;

drop table if EXISTS tmp_dm_air_dw.air_abc_fact_reso_diff_tmp003;
create table tmp_dm_air_dw.air_abc_fact_reso_diff_tmp003 as
select month,cost_code,account_code,account_name,sum(amt) amt from dm_air_dw.air_abc_fact_reso_upload where inc_month='${v_month}' and month='${v_month}' group by month,cost_code,account_code,account_name;

drop table if EXISTS tmp_dm_air_dw.air_abc_fact_reso_diff;
create table tmp_dm_air_dw.air_abc_fact_reso_diff as
select (case when a.month is null then b.month else a.month end) month
,(case when a.cost_code is null then b.cost_code else a.cost_code end) cost_code
,(case when a.acco_code is null then b.account_code else a.acco_code end) account_code
,(case when a.acco_name is null then b.account_name else a.acco_name end) account_name
,a.SAP SAP_amt
,a.FCM FCM_amt
,a.UPLOAD UPLOAD_amt
,b.amt db_amt
,nvl(b.amt,0)-(nvl(a.SAP,0)+nvl(a.FCM,0)+nvl(a.UPLOAD,0)) DIFF_amt
,from_unixtime(unix_timestamp(), 'yyyy-MM-dd HH:mm:ss') as load_tm
,(case when a.cost_code is null or b.cost_code is null then 0 else 1 end) flag_code
from tmp_dm_air_dw.air_abc_fact_reso_diff_tmp002 a
FULL JOIN tmp_dm_air_dw.air_abc_fact_reso_diff_tmp003 b
on a.month=b.month and a.cost_code=b.cost_code and a.acco_code=b.account_code;

insert overwrite  table dm_air_dw.air_abc_fact_reso_diff PARTITION(inc_month='${v_month}')
select month,cost_code,account_code,account_name,SAP_amt,FCM_amt,UPLOAD_amt,db_amt,DIFF_amt,'' remark1,'' remark2,'' remark3,load_tm from tmp_dm_air_dw.air_abc_fact_reso_diff;
