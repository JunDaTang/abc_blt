-- ============================================================
-- 存储过程: p_abc_fct_ao_driv
-- 功能: 生成AO（作业→运单）阶段的动因数据，是四级分摊的最终环节
--       包含9种动因代码，分别按不同维度统计运单级别的动因量：
--       AO002: 收端按票数（qty=1），将作业成本按运单票数分摊到收端运单
--       AO003: 派端按票数（qty=1），将作业成本按运单票数分摊到派端运单
--       AO004: 收端+派端按票数（qty=1），同时覆盖收派两端
--       AO005: 按线路重量（qty=waybill_wt），将运输作业成本按重量分摊
--       AO006/AO007: 按包裹状态(is_pkg)统计票数，区分包裹/非包裹
--       AO008/AO009: 按操作代码(op_code)+包裹状态(is_pkg)统计票数
--       AO010: 按产品代码(prod_code)统计票数，按产品类型分摊
-- 输入参数: p_to_dt - 截止日期（默认当前日期），自动推算月份范围
-- 输入表: abc_bsl_waybill（运单信息）、abc_bsl_op_waybill（运单操作基础表）、
--         abc_dim_dept（机构维表）、abc_dim_line（线路维表）、
--         abc_rel_driv_logic（动因逻辑配置）
-- 输出表: abc_fct_ao_driv（AO动因事实表）
-- 执行顺序: 第5步-动因计算（AO动因），在AA动因之后执行，是动因生成的最后一步
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成AO动因
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-27  生成AO动因

DROP PROCEDURE IF EXISTS p_abc_fct_ao_driv;
DELIMITER //
CREATE PROCEDURE p_abc_fct_ao_driv(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 初始化变量：参数为空则取当前日期，计算月份范围
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_ao_driv';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  -- 清理当月已有的AO002-AO010动因数据，保证幂等重跑
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_ao_driv a
   WHERE a.month_code = v_month
     AND a.driv_code IN ('AO002','AO003','AO004','AO005','AO006','AO007','AO008','AO009','AO010');

  -- 生成AO动因
  SET v_sqlstate = '生成动因';

  -- AO002: 收端按票数分摊
  -- 动因量 = 1（每票运单等权），将作业成本按运单票数均摊到收端机构
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.rec_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.acti_code, c.acti_name, NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO002'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO003: 派端按票数分摊
  -- 动因量 = 1，将作业成本按运单票数均摊到派端机构
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.send_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.acti_code, c.acti_name, NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.send_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO003'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO004: 收端按票数分摊（第二组作业）
  -- 逻辑同AO002，但对应不同的动因代码（覆盖不同作业类型）
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.rec_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.acti_code, c.acti_name, NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO004'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO004: 派端按票数分摊（第二组作业）
  -- 逻辑同AO003，但对应不同的动因代码（覆盖不同作业类型）
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.send_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.acti_code, c.acti_name, NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.send_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO004'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO005: 按线路重量分摊
  -- 动因量 = waybill_wt（运单重量），将运输作业成本按重量比例分摊到运单
  -- 作业代码拼接线路代码(acti_code + '_' + line_code)，实现按线路细分
  -- JOIN条件：线路类型(line_type)匹配动因逻辑的线路级别(line_leve)
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           CONCAT(d.acti_code, '_', a.line_code), d.acti_name,
           a.car_no, d.driv_code, d.driv_name,
           a.waybill_wt qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_line b ON DATE_FORMAT(a.op_dt, '%Y%m') = b.month_code AND a.line_code = b.line_code
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON b.line_type = d.line_leve AND c.dept_type = d.dept_type
       AND d.driv_code = 'AO005' AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO006/AO007: 按包裹状态(is_pkg)分摊
  -- 动因量 = 1（每票运单等权），按包裹/非包裹分别统计票数
  -- 通过is_pkg匹配动因逻辑的pkg_state，区分不同包裹状态的分摊比例
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           d.acti_code, d.acti_name, NULL car_no, d.driv_code, d.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state AND c.dept_type = d.dept_type
       AND d.driv_code IN ('AO006', 'AO007') AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO008/AO009: 按操作代码(op_code)+包裹状态(is_pkg)分摊
  -- 动因量 = 1，按操作类型和包裹状态两个维度细分
  -- 比AO006/AO007更细粒度：同时匹配操作代码和包裹状态
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           d.acti_code, d.acti_name, NULL car_no, d.driv_code, d.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state AND a.op_code = d.op_code AND c.dept_type = d.dept_type
       AND d.driv_code IN ('AO008', 'AO009') AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO010: 按产品代码(prod_code)分摊
  -- 动因量 = 1，按产品类型统计运单票数
  -- 通过产品代码匹配动因逻辑，实现按产品线分摊作业成本
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.rec_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.acti_code, c.acti_name, NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON a.prod_code = c.prod_code AND b.dept_type = c.dept_type AND c.driv_code = 'AO010'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- 提交事务
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
