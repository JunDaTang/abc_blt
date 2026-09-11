#!/bin/sh

v_month=$1
   
  check_1=`hive -e "
SET mapreduce.job.queuename=SFAIR2;
select count(*) name  from 
(select cost_code,sum(driv_qty) driv_qty from dm_air_dw.air_abc_fact_indirect_labor t where inc_month = '${v_month}' and month = '${v_month}'  group by cost_code) t1
where round(driv_qty,4) <> 1
"`

echo "参数处理前$check_1";
    
check_1=$(echo ${check_1//+/ })
check_1=$(echo ${check_1//-/ })
check_1=$(echo ${check_1//name/})
check_1=$(echo ${check_1//| /})
check_1=$(echo ${check_1//|/ })

echo "参数处理后$check_1";

if [ $check_1 -eq 0 ]; then
  echo "全部计算完成";
  else
  echo "存在计算失败";
  exit 1
fi


end_time=`date "+%Y-%m-%d %H:%M:%S"`
 
echo "占比数据正常 $end_time"