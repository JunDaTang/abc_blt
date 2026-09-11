-- ============================================================
-- 存储过程: p_abc_bsl_cost_base
-- 功能: 生成成本分析基表，是整个ABC系统的最终产出
--       将AO分摊结果按运单汇总，按资源代码拆分为五类成本：
--         设备成本(dive_amt)：资源代码=ZY0201
--         运输成本(car_amt)：资源代码=ZY0301
--         物料成本(metr_amt)：资源代码=ZY0401或ZY0402
--         管理成本(mgr_amt)：资源代码=ZY0101 且 功能中心=1040(管理)
--         人工成本(pep_amt)：资源代码=ZY0101 且 功能中心≠1040(非管理)
--       再与运单信息关联得到收入、区部、流向、客户、产品等维度信息
--       通过 ROW_NUMBER() 生成 rn 序号，rn=1 的记录才计入收入（避免运单重复计收入）
-- 输入参数: p_to_dt - 截止日期（用于计算统计月份）
-- 输入表: abc_fct_ao_dist（AO分摊结果）、abc_bsl_waybill（运单信息）
--         abc_rel_cust（客户维表）、abc_dim_dept（机构维表）
-- 输出表: abc_bsl_cost_base（成本分析基表，最终产出）、abc_bsl_cost_base_tmp01（临时表）
-- 执行顺序: 第12步-最终汇总产出（四级分摊全部完成后执行，是整条链路的终点）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : ABC成本分析基表
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-30  ABC成本分析基表

DROP PROCEDURE IF EXISTS p_abc_bsl_cost_base;
DELIMITER //
CREATE PROCEDURE p_abc_bsl_cost_base(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 初始化变量：计算统计月份
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_ra_dist';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01'); -- 月初第一天
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');                              -- 下月月初
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');                                -- 月份编码

  -- 清空临时表和当月成本基表数据（保证幂等性）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_bsl_cost_base_tmp01;  -- 作业资源成本临时表
  DELETE FROM abc_bsl_cost_base a WHERE a.month_code = v_month; -- 当月成本基表

  -- 步骤1: 生成作业资源成本临时表
  -- 将AO分摊结果按运单+作业类型维度汇总，并按资源代码拆分为五类成本：
  --   ZY0201(设备) → dive_amt    ZY0301(运输) → car_amt
  --   ZY0401/ZY0402(物料) → metr_amt
  --   ZY0101+1040(管理) → mgr_amt    ZY0101+非1040(人工) → pep_amt
  SET v_sqlstate = '生成作业资源成本';
  INSERT INTO abc_bsl_cost_base_tmp01
    SELECT a.waybill_no,
           a.fm_acti_type_code,
           a.fm_acti_type_name,
           SUM(CASE WHEN a.fm_reso_code = 'ZY0201' THEN a.to_amt ELSE 0 END) dive_amt,
           SUM(CASE WHEN a.fm_reso_code = 'ZY0301' THEN a.to_amt ELSE 0 END) car_amt,
           SUM(CASE WHEN a.fm_reso_code IN ('ZY0401', 'ZY0402') THEN a.to_amt ELSE 0 END) metr_amt,
           SUM(CASE WHEN a.fm_reso_code = 'ZY0101' AND a.fm_func_code = '1040' THEN a.to_amt ELSE 0 END) mgr_amt,
           SUM(CASE WHEN a.fm_reso_code = 'ZY0101' AND a.fm_func_code <> '1040' THEN a.to_amt ELSE 0 END) pep_amt,
           SUM(a.to_amt) all_amt
      FROM abc_fct_ao_dist a
     WHERE a.month_code = v_month
     GROUP BY a.waybill_no, a.fm_acti_type_code, a.fm_acti_type_name;

  -- 步骤2: 生成最终结果表
  -- 将运单信息与成本临时表关联，补充区部、流向、客户、产品等维度
  -- 关联说明：
  --   abc_bsl_waybill: 运单主表，提供收入、日期、城市、客户、产品等信息
  --   abc_bsl_cost_base_tmp01: 成本临时表，提供五类成本（LEFT JOIN，允许运单无成本）
  --   abc_rel_cust: 客户维表，补充客户名称
  --   abc_dim_dept: 机构维表（收端/派端各关联一次），补充业务区编码
  -- ROW_NUMBER() 按运单号分组、按收入降序排列，rn=1才计收入（避免重复计收入）
  SET v_sqlstate = '生成结果表数据';
  INSERT INTO abc_bsl_cost_base
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           a.rec_dept,
           d.level2_code rec_area_code,
           d.level2_name rec_area_name,
           a.send_dept,
           e.level2_code send_area_code,
           e.level2_name send_area_name,
           a.waybill_no,
           a.rec_city,
           a.send_city,
           a.cust_code,
           c.cust_name,
           a.prod_code,
           a.prod_name,
           a.amt income_amt,
           b.fm_acti_type_code,
           b.fm_acti_type_name,
           b.dive_amt,
           b.car_amt,
           b.metr_amt,
           b.mgr_amt,
           b.pep_amt,
           b.all_amt,
           ROW_NUMBER() OVER(PARTITION BY a.waybill_no ORDER BY a.amt DESC) AS rn,
           NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_bsl_cost_base_tmp01 b ON a.waybill_no = b.waybill_no
      LEFT JOIN abc_rel_cust c ON a.cust_code = c.cust_code
      LEFT JOIN abc_dim_dept d ON a.rec_dept = d.dept_code
       AND d.fm_tm <= v_fm_date AND d.to_tm >= v_to_date
      LEFT JOIN abc_dim_dept e ON a.send_dept = e.dept_code
       AND e.fm_tm <= v_fm_date AND e.to_tm >= v_to_date
     WHERE a.rec_dt >= v_fm_date
       AND a.rec_dt < v_to_date;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
