-- ============================================================
-- 存储过程: p_abc_fct_ao_driv
-- 功能: 生成AO（作业→运单）动因事实表，为AO分摊提供分摊依据
--       每个动因代码对应不同的业务场景，每条动因记录表示一个运单在某作业上的动因量
--       与6.3版本的区别：
--         (1) AO004 增加了按业务区(level2_code)和总部(level1_code)维度的记录
--         (2) 新增 AO011 分拨区操作动因
-- 动因代码说明:
--   AO002 - 收端操作：按收端机构(rec_dept)生成动因，qty=1（每单1次）
--   AO003 - 派端操作：按派端机构(send_dept)生成动因，qty=1
--   AO004 - 综合操作：按机构/业务区/总部三个维度分别生成动因，qty=1
--   AO005 - 线路重量：按操作运单的线路重量(waybill_wt)生成动因
--   AO006/AO007 - 包裹状态：按包裹状态(is_pkg)区分整包/散件
--   AO008/AO009 - 操作代码：按操作代码(op_code)+包裹状态区分
--   AO010 - 产品：按产品代码(prod_code)生成动因
--   AO011 - 分拨区操作：按业务区(level2_code)+操作代码+包裹状态生成动因（8.2新增）
-- 输入参数: p_to_dt - 截止日期（用于计算动因月份）
-- 输入表: abc_bsl_waybill（运单信息）、abc_bsl_op_waybill（操作运单明细）
--         abc_dim_dept（机构维表）、abc_dim_line（线路维表）
--         abc_rel_driv_logic（动因逻辑配置表）
-- 输出表: abc_fct_ao_driv（AO动因事实表）
-- 执行顺序: 第5步-动因计算（AO动因，8.2增强版，在基础数据准备之后、分摊之前执行）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成AO动因 (8.2版本，增加业务区/总部/分拨区)
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
  
  -- 初始化变量：计算动因月份
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_ao_driv';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01'); -- 月初第一天
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');                              -- 下月月初
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');                                -- 月份编码

  -- 清空当月AO动因数据（仅删除AO002~AO010，AO001为直接计入不动）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_ao_driv a
   WHERE a.month_code = v_month
     AND a.driv_code IN ('AO002', 'AO003', 'AO004', 'AO005',
                         'AO006', 'AO007', 'AO008', 'AO009', 'AO010');

  SET v_sqlstate = '生成动因';

  -- AO002: 收端操作动因
  -- 每票运单在收端机构产生1次操作，qty=1
  -- 通过abc_rel_driv_logic配置收端机构类型对应的作业和动因
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           a.rec_dept, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO002'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO003: 派端操作动因
  -- 每票运单在派端机构产生1次操作，qty=1
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           a.send_dept, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.send_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO003'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO004: 收端机构级别操作动因（按部门维度）
  -- 每票运单在收端机构产生1次操作，dept_code=rec_dept（具体部门）
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           a.rec_dept, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO004'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO004: 收端业务区级别操作动因（8.2新增，按业务区level2维度）
  -- 将运单按收端所属业务区汇总，使作业成本能分摊到业务区级别
  -- dept_code=level2_code（业务区代码），同一业务区下多个部门的运单共享该动因
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           b.level2_code dept_code, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO004'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO004: 总部级别操作动因（8.2新增，按总部level1维度）
  -- 将所有运单按总部汇总，使作业成本能分摊到总部级别
  -- dept_code=level1_code（总部代码），实现成本从总部→运单的分摊路径
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           b.level1_code dept_code, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO004'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO004: 派端机构级别操作动因（按部门维度）
  -- 每票运单在派端机构产生1次操作，dept_code=send_dept（具体部门）
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           a.send_dept, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.send_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'AO004'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  -- AO005: 线路重量动因
  -- 按操作运单的线路重量(waybill_wt)作为动因量，用于运输相关作业的分摊
  -- acti_code 拼接线路代码(CONCAT)，区分不同线路的作业
  -- 需要关联线路维表(abc_dim_line)获取线路类型(line_type)来匹配动因逻辑
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code,
           a.op_dept_code, c.dept_type, c.dept_type_name,
           d.func_code, d.func_name,
           CONCAT(d.acti_code, '_', a.line_code), d.acti_name,
           a.car_no, d.driv_code, d.driv_name,
           a.waybill_wt qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_line b ON DATE_FORMAT(a.op_dt, '%Y%m') = b.month_code AND a.line_code = b.line_code
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code
       AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON b.line_type = d.line_leve
       AND c.dept_type = d.dept_type AND d.driv_code = 'AO005'
       AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO006/AO007: 包裹状态动因
  -- 按包裹状态(is_pkg)区分整包和散件，分别生成不同动因
  -- AO006和AO007通过abc_rel_driv_logic中的pkg_state字段匹配
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code,
           a.op_dept_code, c.dept_type, c.dept_type_name,
           d.func_code, d.func_name, d.acti_code, d.acti_name,
           NULL car_no, d.driv_code, d.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code
       AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state
       AND c.dept_type = d.dept_type AND d.driv_code IN ('AO006', 'AO007')
       AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO008/AO009: 操作代码动因
  -- 按操作代码(op_code)+包裹状态(is_pkg)组合区分不同操作类型
  -- AO008和AO009通过abc_rel_driv_logic中的op_code和pkg_state字段匹配
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code,
           a.op_dept_code, c.dept_type, c.dept_type_name,
           d.func_code, d.func_name, d.acti_code, d.acti_name,
           NULL car_no, d.driv_code, d.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code
       AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state
       AND a.op_code = d.op_code AND c.dept_type = d.dept_type
       AND d.driv_code IN ('AO008', 'AO009')
       AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO011: 分拨区操作动因（8.2新增）
  -- 按业务区(level2_code)+操作代码+包裹状态组合，用于分拨区作业的成本分摊
  -- dept_code取level2_code（业务区），实现分拨区维度的成本归集
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code,
           c.level2_code dept_code, c.dept_type, c.dept_type_name,
           d.func_code, d.func_name, d.acti_code, d.acti_name,
           NULL car_no, d.driv_code, d.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code
       AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.is_pkg = d.pkg_state
       AND a.op_code = d.op_code AND c.dept_type = d.dept_type
       AND d.driv_code IN ('AO011')
       AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month AND d.driv_code IS NOT NULL;

  -- AO010: 产品动因
  -- 按产品代码(prod_code)区分不同产品的操作量，用于产品维度的作业成本分摊
  -- 通过abc_rel_driv_logic中的prod_code字段匹配产品与动因逻辑
  INSERT INTO abc_fct_ao_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code,
           a.rec_dept, b.dept_type, b.dept_type_name,
           c.func_code, c.func_name, c.acti_code, c.acti_name,
           NULL car_no, c.driv_code, c.driv_name,
           1 qty, a.waybill_no, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code
       AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON a.prod_code = c.prod_code
       AND b.dept_type = c.dept_type AND c.driv_code = 'AO010'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
