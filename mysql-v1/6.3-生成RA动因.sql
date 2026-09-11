-- ============================================================
-- 存储过程: p_abc_fct_ra_driv
-- 功能: 生成RA（资源→作业）阶段的动因数据
--       RA002动因：按线路里程分摊运输资源成本，动因量=线路公里数(line_km)
--       RA003动因：按操作次数分摊操作资源成本，动因量=操作次数×费率(rt)
-- 输入参数: p_to_dt - 截止日期（默认当前日期），自动推算月份范围
-- 输入表: abc_bsl_op_waybill（运单操作基础表）、abc_dim_line（线路维表）、
--         abc_dim_dept（机构维表）、abc_rel_driv_logic（动因逻辑配置）
-- 输出表: abc_fct_ra_driv（RA动因事实表）
-- 执行顺序: 第5步-动因计算（RA动因），在RR动因之后执行
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成RA动因
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-27  生成RA动因

DROP PROCEDURE IF EXISTS p_abc_fct_ra_driv;
DELIMITER //
CREATE PROCEDURE p_abc_fct_ra_driv(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 初始化变量：参数为空则取当前日期，计算月份范围
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_rr_driv';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  -- 清理当月已有的RA002和RA003动因数据，保证幂等重跑
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_ra_driv a WHERE a.month_code = v_month AND a.driv_code IN ('RA002', 'RA003');

  -- 生成RA动因
  SET v_sqlstate = '生成动因';

  -- RA002动因：按线路里程分摊运输资源成本
  -- 先按(日期, 操作机构, 车牌, 线路)分组统计操作次数
  -- 再通过线路维表获取里程(line_km)，动因量 = SUM(线路公里数)
  -- JOIN条件：线路类型(line_type)匹配动因逻辑的线路级别(line_leve)
  -- 作业代码拼接线路代码(acti_code + '_' + line_code)，实现按线路细分作业
  INSERT INTO abc_fct_ra_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           CONCAT(d.acti_code, '_', a.line_code), d.acti_name,
           a.car_no, d.driv_code, d.driv_name,
           SUM(b.line_km) qty, NOW() load_tm
      FROM (SELECT DATE(a.op_dt) op_dt, a.op_dept_code, a.car_no, a.line_code
              FROM abc_bsl_op_waybill a
             WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month
             GROUP BY DATE(a.op_dt), a.op_dept_code, a.car_no, a.line_code) a
      LEFT JOIN abc_dim_line b ON DATE_FORMAT(a.op_dt, '%Y%m') = b.month_code AND a.line_code = b.line_code
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON b.line_type = d.line_leve AND c.dept_type = d.dept_type
       AND d.driv_code = 'RA002' AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     GROUP BY DATE_FORMAT(a.op_dt, '%Y%m'), a.op_dept_code, c.dept_type, c.dept_type_name,
              d.func_code, d.func_name, CONCAT(d.acti_code, '_', a.line_code),
              d.acti_name, a.car_no, d.driv_code, d.driv_name;

  -- RA003动因：按操作次数分摊操作资源成本
  -- 动因量 = SUM(1 × rt)，rt为动因逻辑配置中的费率/权重
  -- 通过操作代码(op_code)和机构类型(dept_type)匹配动因逻辑
  -- car_no置为NULL，因为操作类资源不区分车牌
  INSERT INTO abc_fct_ra_driv
    SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.op_dept_code,
           c.dept_type, c.dept_type_name, d.func_code, d.func_name,
           d.acti_code, d.acti_name, NULL car_no, d.driv_code, d.driv_name,
           SUM(1 * d.rt) qty, NOW() load_tm
      FROM abc_bsl_op_waybill a
      LEFT JOIN abc_dim_dept c ON a.op_dept_code = c.dept_code AND c.fm_tm <= v_fm_date AND c.to_tm >= v_fm_date
      LEFT JOIN abc_rel_driv_logic d ON a.op_code = d.op_code AND c.dept_type = d.dept_type
       AND d.driv_code = 'RA003' AND d.fm_tm <= v_fm_date AND d.to_tm >= v_fm_date
     WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month
     GROUP BY DATE_FORMAT(a.op_dt, '%Y%m'), a.op_dept_code, c.dept_type, c.dept_type_name,
              d.func_code, d.func_name, d.acti_code, d.acti_name, d.driv_code, d.driv_name;

  -- 提交事务
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
