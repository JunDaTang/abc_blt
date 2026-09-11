-- ============================================================
-- 文件名: 9.1-分析脚本.sql
-- 说明: 多维度利润分析查询脚本，基于运单表和 AO 分摊结果进行利润分析
--       从产品、流向、客户、成本项、作业等维度分析收入和利润
--       数据来源：ABC_BSL_WAYBILL（运单表）+ ABC_FCT_AO_DIST（AO 分摊结果）
-- 执行顺序: 第7步（分析），在四级分摊（7.3/8.3）完成之后执行
-- ============================================================

-- MySQL 版本
USE abc_blt;

-- ============================================================
-- 查询1：产品利润分析
-- 按产品类型（标快/电商/即日/次日）汇总收入和成本，计算各产品的利润
-- 注意：收入直接来自运单表，成本来自 AO 分摊结果按运单号关联
-- ============================================================
select DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
       a.prod_code,
       a.prod_name,
       sum(a.amt) income_amt,
       sum(b.amt) cost_amt
  from abc_bsl_waybill a
  left join (select a.waybill_no, sum(a.to_amt) amt
               from abc_fct_ao_dist a
              where a.month_code = '201905'
              group by a.waybill_no) b
    on a.waybill_no = b.waybill_no
 where a.rec_dt >= '2019-05-01 00:00:00'
   and a.rec_dt < '2019-06-01 00:00:00'
 group by DATE_FORMAT(a.rec_dt, '%Y%m'), a.prod_code, a.prod_name;

-- ============================================================
-- 查询2：流向利润分析
-- 按收件城市-派件城市的流向汇总收入和成本，计算各流向的利润
-- 用于分析不同线路的盈利能力（如深圳→上海 vs 北京→广州）
-- ============================================================
select DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
       CONCAT(a.rec_city, '-', a.send_city) city_flow,
       sum(a.amt) income_amt,
       sum(b.amt) cost_amt,
       sum(a.amt) - sum(b.amt) proj_amt
  from abc_bsl_waybill a
  left join (select a.waybill_no, sum(a.to_amt) amt
               from abc_fct_ao_dist a
              where a.month_code = '201905'
              group by a.waybill_no) b
    on a.waybill_no = b.waybill_no
 where a.rec_dt >= '2019-05-01 00:00:00'
   and a.rec_dt < '2019-06-01 00:00:00'
 group by DATE_FORMAT(a.rec_dt, '%Y%m'), CONCAT(a.rec_city, '-', a.send_city);

-- ============================================================
-- 查询3：客户利润分析
-- 按客户维度汇总收入和成本，计算各客户的利润
-- 关联客户维表（ABC_REL_CUST）获取客户名称
-- 用于识别高价值客户和亏损客户
-- ============================================================
select DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
       a.cust_code,
       c.cust_name,
       sum(a.amt) income_amt,
       sum(b.amt) cost_amt,
       sum(a.amt) - sum(b.amt) proj_amt
  from abc_bsl_waybill a
  left join (select a.waybill_no, sum(a.to_amt) amt
               from abc_fct_ao_dist a
              where a.month_code = '201905'
              group by a.waybill_no) b
    on a.waybill_no = b.waybill_no
  left join abc_rel_cust c
    on a.cust_code = c.cust_code
 where a.rec_dt >= '2019-05-01 00:00:00'
   and a.rec_dt < '2019-06-01 00:00:00'
 group by DATE_FORMAT(a.rec_dt, '%Y%m'), a.cust_code, c.cust_name;

-- ============================================================
-- 查询4：成本项分析
-- 按资源类型拆分成本，分析五类成本的占比：
--   dive_amt = 设备成本（ZY0201）
--   car_amt  = 运输成本（ZY0301）
--   metr_amt = 物料成本（ZY0401 + ZY0402）
--   mgr_amt  = 管理成本（ZY0101 + func=1040）
--   pep_amt  = 人工成本（ZY0101 + func≠1040）
-- ============================================================
select DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
       sum(a.amt) income_amt,
       sum(b.dive_amt) dive_amt,
       sum(b.car_amt) car_amt,
       sum(b.mgr_amt) mgr_amt,
       sum(b.pep_amt) pep_amt
  from abc_bsl_waybill a
  left join (select a.waybill_no,
                    sum(case
                          when a.fm_reso_code = 'ZY0201' then
                           a.to_amt
                          else
                           0
                        end) dive_amt,
                    sum(case
                          when a.fm_reso_code = 'ZY0301' then
                           a.to_amt
                          else
                           0
                        end) car_amt,
                    sum(case
                          when a.fm_reso_code in ('ZY0401', 'ZY0402') then
                           a.to_amt
                          else
                           0
                        end) metr_amt,
                    sum(case
                          when a.fm_reso_code = 'ZY0101' and
                               a.fm_func_code = '1040' then
                           a.to_amt
                          else
                           0
                        end) mgr_amt,
                    sum(case
                          when a.fm_reso_code = 'ZY0101' and
                               a.fm_func_code <> '1040' then
                           a.to_amt
                          else
                           0
                        end) pep_amt
               from abc_fct_ao_dist a
              where a.month_code = '201905'
              group by a.waybill_no) b
    on a.waybill_no = b.waybill_no
 where a.rec_dt >= '2019-05-01 00:00:00'
   and a.rec_dt < '2019-06-01 00:00:00'
 group by DATE_FORMAT(a.rec_dt, '%Y%m');


-- ============================================================
-- 查询5：作业成本项分析
-- 按作业类型汇总成本，分析各作业环节（收件/派件/运输/装卸/中转/管理）的成本占比
-- 用于识别成本最高的作业环节，支撑作业优化决策
-- ============================================================
select a.month_code,
       b.fm_acti_type_code,
       b.fm_acti_type_name,
       a.income_amt,
       b.amt
  from (select DATE_FORMAT(a.rec_dt, '%Y%m') month_code, sum(a.amt) income_amt
          from abc_bsl_waybill a
         where a.rec_dt >= '2019-05-01 00:00:00'
           and a.rec_dt < '2019-06-01 00:00:00'
         group by DATE_FORMAT(a.rec_dt, '%Y%m')) a
  left join (select a.fm_acti_type_code,
                    a.fm_acti_type_name,
                    sum(a.to_amt) amt
               from abc_fct_ao_dist a
              where a.month_code = '201905'
              group by a.fm_acti_type_code, a.fm_acti_type_name) b
    on 1 = 1;
