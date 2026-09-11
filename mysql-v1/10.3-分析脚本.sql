-- ============================================================
-- 文件名: 10.3-分析脚本.sql
-- 说明: 基于成本分析基表（ABC_BSL_COST_BASE）的多维度利润分析
--       成本分析基表是最终产出表，已将运单粒度的收入与五类成本匹配
--       相比 9.1 的分析脚本，本脚本直接使用基表，查询更高效
--       支持区部利润、流向利润、客户利润的下钻分析
-- 执行顺序: 第7步（最终汇总分析），在四级分摊完成后、先调用 p_abc_bsl_cost_base 汇总
-- ============================================================

-- MySQL 版本
-- 源文件: 10.3-分析脚本.sql
USE abc_blt;

-- 第0步：调用成本分析基表生成存储过程
-- 将 AO 分摊结果按运单汇总，匹配收入，生成五类成本（设备/运输/物料/管理/人工）
-- 结果写入 ABC_BSL_COST_BASE，是后续所有利润分析的数据基础
CALL p_abc_bsl_cost_base('2019-06-01 00:00:00');

-- ============================================================
-- 查询1：区部利润分析
-- 按区部（rec_area_code）汇总收入和成本，计算利润和利润率
-- 注意：rn=1 的记录才计入收入，避免同一运单在多次分摊中重复计收入
-- 利润率 = (收入 - 总成本) / 收入
-- ============================================================
select t.rec_area_code,
       t.rec_area_name,
       t.income_amt,
       t.cost_all_amt,
       t.income_amt - t.cost_all_amt prof_amt,
       (t.income_amt - t.cost_all_amt) / t.income_amt prof_rt
  from (select a.rec_area_code,
               a.rec_area_name,
               sum(case when a.rn = 1 then a.income_amt else 0 end) income_amt,
               sum(a.cost_all_amt) cost_all_amt
          from abc_bsl_cost_base a
         where a.month_code = '201905'
         group by a.rec_area_code, a.rec_area_name) t;

-- ============================================================
-- 查询2：北京区部流向利润分析
-- 对北京区部（010Y）按流向（收件城市-派件城市）下钻，分析各流向的盈利能力
-- 用于发现哪些线路盈利、哪些线路亏损
-- ============================================================
select t.rec_area_code,
       t.rec_area_name,
       t.city_flow,
       t.income_amt,
       t.cost_all_amt,
       t.income_amt - t.cost_all_amt prof_amt,
       (t.income_amt - t.cost_all_amt) / t.income_amt prof_rt
  from (select a.rec_area_code,
               a.rec_area_name,
               CONCAT(a.rec_city, '-', a.send_city) city_flow,
               sum(case when a.rn = 1 then a.income_amt else 0 end) income_amt,
               sum(a.cost_all_amt) cost_all_amt
          from abc_bsl_cost_base a
         where a.month_code = '201905'
           and a.rec_area_code = '010Y'
         group by a.rec_area_code, a.rec_area_name, CONCAT(a.rec_city, '-', a.send_city)) t;

-- ============================================================
-- 查询3：北京区部 010-021 流向下的客户利润分析
-- 对北京→上海（010-021）流向进一步按客户下钻，分析该流向下各客户的盈利情况
-- 用于精准识别亏损客户，支撑定价和客户策略调整
-- ============================================================
select t.rec_area_code,
       t.rec_area_name,
       t.city_flow,
       t.cust_code,
       t.cust_name,
       t.income_amt,
       t.cost_all_amt,
       t.income_amt - t.cost_all_amt prof_amt,
       (t.income_amt - t.cost_all_amt) / t.income_amt prof_rt
  from (select a.rec_area_code,
               a.rec_area_name,
               CONCAT(a.rec_city, '-', a.send_city) city_flow,
               a.cust_code,
               a.cust_name,
               sum(case when a.rn = 1 then a.income_amt else 0 end) income_amt,
               sum(a.cost_all_amt) cost_all_amt
          from abc_bsl_cost_base a
         where a.month_code = '201905'
           and a.rec_area_code = '010Y'
           and CONCAT(a.rec_city, '-', a.send_city) = '010-021'
         group by a.rec_area_code, a.rec_area_name, CONCAT(a.rec_city, '-', a.send_city),
                  a.cust_code, a.cust_name) t;
