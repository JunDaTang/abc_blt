-- ============================================================
-- 存储过程: p_abc_fct_rr_driv
-- 功能: 生成RR（资源→资源）阶段的动因数据
--       RR002动因：按运单票数统计收端(1010)和派端(1020)各功能中心的分摊动因量，
--       用于将共享资源成本按票数比例分摊到各功能中心
-- 输入参数: p_to_dt - 截止日期（默认当前日期），自动推算月份范围
-- 输入表: abc_bsl_waybill（运单信息）、abc_dim_dept（机构维表）、
--         abc_rel_driv_logic（动因逻辑配置）
-- 输出表: abc_fct_rr_driv（RR动因事实表）
-- 执行顺序: 第5步-动因计算（RR动因），在四级分摊模型中属于最先执行的动因生成
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成RR动因
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-27  生成RR动因

DROP PROCEDURE IF EXISTS p_abc_fct_rr_driv;
DELIMITER //
CREATE PROCEDURE p_abc_fct_rr_driv(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 初始化变量：参数为空则取当前日期，计算月份范围
  -- v_fm_date = 当月1号，v_to_date = 下月1号，v_month = YYYYMM格式
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_rr_driv';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  -- 清理当月已有的RR002动因数据，保证幂等重跑
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_rr_driv a WHERE a.month_code = v_month AND a.driv_code = 'RR002';

  -- 生成RR002动因：按运单票数统计各功能中心的分摊动因量
  SET v_sqlstate = '生成动因';

  -- 收端(1010)动因：统计每个收端机构的运单票数作为分摊依据
  -- 动因量 = COUNT(1)，即该机构当月收到的运单数量
  -- 通过INNER JOIN abc_rel_driv_logic匹配机构类型对应的功能中心和作业
  INSERT INTO abc_fct_rr_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.rec_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.driv_code, c.driv_name, COUNT(1) qty, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.rec_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'RR002' AND c.func_code = '1010'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date
     GROUP BY DATE_FORMAT(a.rec_dt, '%Y%m'), a.rec_dept, b.dept_type, b.dept_type_name,
              c.func_code, c.func_name, c.driv_code, c.driv_name;

  -- 派端(1020)动因：统计每个派端机构的运单票数作为分摊依据
  -- 逻辑与收端相同，区别在于使用send_dept(派端机构)和func_code='1020'
  INSERT INTO abc_fct_rr_driv
    SELECT DATE_FORMAT(a.rec_dt, '%Y%m') month_code, a.send_dept,
           b.dept_type, b.dept_type_name, c.func_code, c.func_name,
           c.driv_code, c.driv_name, COUNT(1) qty, NOW() load_tm
      FROM abc_bsl_waybill a
      LEFT JOIN abc_dim_dept b ON a.send_dept = b.dept_code AND b.fm_tm <= v_fm_date AND b.to_tm >= v_fm_date
     INNER JOIN abc_rel_driv_logic c ON b.dept_type = c.dept_type AND c.driv_code = 'RR002' AND c.func_code = '1020'
     WHERE a.rec_dt >= v_fm_date AND a.rec_dt < v_to_date
     GROUP BY DATE_FORMAT(a.rec_dt, '%Y%m'), a.send_dept, b.dept_type, b.dept_type_name,
              c.func_code, c.func_name, c.driv_code, c.driv_name;

  -- 提交事务
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
