-- ============================================================
-- 存储过程: p_abc_fct_aa_driv
-- 功能: 生成AA（作业→作业）阶段的动因数据
--       AA002动因：按线路重量分摊，区分大货(≥3000)和小货(<3000)
--                  大货作业(活动代码第5-6位=10): 动因量=MIN(重量,3000)
--                  小货作业(活动代码第5-6位=20): 动因量=MAX(3000-重量,0)
--       AA003动因：按包裹状态(is_pkg)统计票数，动因量=COUNT(1)
--       AA004动因：按操作代码(op_code)+包裹状态(is_pkg)统计票数，动因量=COUNT(1)
-- 输入参数: p_to_dt - 截止日期（默认当前日期），自动推算月份范围
-- 输入表: abc_bsl_op_waybill（运单操作基础表）、abc_dim_line（线路维表）、
--         abc_dim_dept（机构维表）、abc_rel_driv_logic（动因逻辑配置）
-- 输出表: abc_fct_aa_driv（AA动因事实表）
-- 执行顺序: 第5步-动因计算（AA动因），在RA动因之后执行
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成AA动因
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-27  生成AA动因

DROP PROCEDURE IF EXISTS p_abc_fct_aa_driv;
DELIMITER //
CREATE PROCEDURE p_abc_fct_aa_driv(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 初始化变量：参数为空则取当前日期，计算月份范围
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_aa_driv';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  -- 清理当月已有的AA002/AA003/AA004动因数据，保证幂等重跑
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_aa_driv a
   WHERE a.month_code = v_month
     AND a.driv_code IN ('AA002', 'AA003', 'AA004');

  -- 生成AA动因
  SET v_sqlstate = '生成动因';

  -- AA002动因：按线路重量分摊，区分大货和小货
  -- 先按(日期, 操作机构, 车牌, 线路)汇总运单重量
  -- 分摊公式（通过活动代码第5-6位区分大货/小货作业）：
  --   大货作业(acti_code第5-6位='10'): 动因量 = 重量>=3000则取3000, 否则取实际重量
  --   小货作业(acti_code第5-6位='20'): 动因量 = 重量>=3000则取0, 否则取(3000-重量)
  -- 含义：大货作业按实际重量（上限3000）分摊，小货作业按剩余重量（3000-实际重量）分摊
  INSERT INTO abc_fct_aa_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code,
           a.op_dept_code,
           c.dept_type,
           c.dept_type_name,
           d.func_code,
           d.func_name,
           CONCAT(d.acti_code, '_', a.line_code),
           d.acti_name,
           a.car_no,
           d.driv_code,
           d.driv_name,
           SUM(CASE
                 WHEN SUBSTRING(d.acti_code, 5, 2) = '10' AND a.wt >= 3000 THEN 3000  -- 大货：封顶3000
                 WHEN SUBSTRING(d.acti_code, 5, 2) = '10' AND a.wt < 3000 THEN a.wt   -- 大货：取实际重量
                 WHEN SUBSTRING(d.acti_code, 5, 2) = '20' AND a.wt >= 3000 THEN 0     -- 小货：超重不分摊
                 WHEN SUBSTRING(d.acti_code, 5, 2) = '20' AND a.wt < 3000 THEN 3000 - a.wt  -- 小货：取剩余重量
               END) qty,
           NOW() load_tm
      FROM (SELECT DATE(a.op_dt) op_dt, a.op_dept_code, a.car_no, a.line_code,
                   SUM(a.waybill_wt) wt
              FROM abc_bsl_op_waybill a
             WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month
             GROUP BY DATE(a.op_dt), a.op_dept_code, a.car_no, a.line_code) a
      LEFT JOIN abc_dim_line b ON DATE_FORMAT(a.op_dt, '%Y%m') = b.month_code AND a.line_code = b.line_code
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON b.line_type = d.line_leve AND c.dept_type = d.dept_type
       AND d.driv_code = 'AA002' AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE d.driv_code IS NOT NULL
     GROUP BY DATE_FORMAT(a.op_dt, '%Y%m'), a.op_dept_code, c.dept_type, c.dept_type_name,
              d.func_code, d.func_name, CONCAT(d.acti_code, '_', a.line_code),
              d.acti_name, a.car_no, d.driv_code, d.driv_name;

  -- AA003动因：按包裹状态(is_pkg)统计票数
  -- 动因量 = COUNT(1)，即该包裹状态下的操作票数
  -- 通过is_pkg匹配动因逻辑的pkg_state，区分包裹/非包裹的分摊比例
  INSERT INTO abc_fct_aa_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           d.acti_code, d.acti_name, NULL car_no, d.driv_code, d.driv_name,
           COUNT(1) qty, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state AND c.dept_type = d.dept_type
       AND d.driv_code = 'AA003' AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL
     GROUP BY DATE_FORMAT(a.op_dt, '%Y%m'), a.op_dept_code, c.dept_type, c.dept_type_name,
              d.func_code, d.func_name, d.acti_code, d.acti_name, d.driv_code, d.driv_name;

  -- AA004动因：按操作代码(op_code)+包裹状态(is_pkg)统计票数
  -- 动因量 = COUNT(1)，即该操作代码+包裹状态组合下的操作票数
  -- 比AA003更细粒度：同时按操作类型和包裹状态两个维度分摊
  INSERT INTO abc_fct_aa_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           d.acti_code, d.acti_name, NULL car_no, d.driv_code, d.driv_name,
           COUNT(1) qty, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state AND a.op_code = d.op_code AND c.dept_type = d.dept_type
       AND d.driv_code = 'AA004' AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL
     GROUP BY DATE_FORMAT(a.op_dt, '%Y%m'), a.op_dept_code, c.dept_type, c.dept_type_name,
              d.func_code, d.func_name, d.acti_code, d.acti_name, d.driv_code, d.driv_name;

  -- 提交事务
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
