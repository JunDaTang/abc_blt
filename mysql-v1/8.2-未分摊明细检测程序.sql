-- ============================================================
-- 存储过程: p_abc_fct_no_dist_list
-- 功能: 检测四级分摊（RR/RA/AA/AO）中未成功分摊的明细记录
--       未分摊条件：all_qty=0（无动因量）且 fm_amt≠0（有资源金额）
--                  且动因代码非 XX001（排除直接计入的情况）
--       输出每条未分摊资源的详细信息（部门、功能中心、资源、作业、车牌、动因等）
--       便于业务人员排查分摊失败原因（如缺少动因配置、动因量为0等）
-- 输入参数: p_to_dt - 截止日期（用于计算检测月份）
-- 输入表: abc_fct_rr_dist（RR分摊结果）、abc_fct_ra_dist（RA分摊结果）
--         abc_fct_aa_dist（AA分摊结果）、abc_fct_ao_dist（AO分摊结果）
-- 输出表: abc_fct_no_dist_list（未分摊明细表，按月份+分摊类型记录每条未分摊记录）
-- 执行顺序: 第11步-未分摊明细检测（在分摊检测和AO分摊之后执行）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : 未分摊明细检测程序
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-30  未分摊明细检测程序

DROP PROCEDURE IF EXISTS p_abc_fct_no_dist_list;
DELIMITER //
CREATE PROCEDURE p_abc_fct_no_dist_list(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 初始化变量：计算检测月份
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_check_dist';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01'); -- 月初第一天
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');                              -- 下月月初
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');                                -- 月份编码

  -- 清空当月未分摊明细（保证幂等性）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_no_dist_list a WHERE a.month_code = v_month;

  -- ========== RR未分摊检测 ==========
  -- 筛选条件：all_qty=0（无动因量）、fm_amt≠0（有资源金额）、排除直接计入代码
  -- RR和RA层无作业信息，fm_acti_type_code/fm_acti_code 填NULL
  SET v_sqlstate = 'RR分摊检测-未分摊';
  INSERT INTO abc_fct_no_dist_list
    SELECT a.month_code, a.dist_type,
           a.fm_dept_code, a.fm_dept_name,
           a.fm_dept_type_code, a.fm_dept_type_name,
           a.fm_func_code, a.fm_func_name,
           a.fm_reso_code, a.fm_reso_name,
           NULL fm_acti_type_code, NULL fm_acti_type_name,
           NULL fm_acti_code, a.fm_car,
           a.driv_code, a.driv_name,
           MAX(a.fm_amt) amt, NOW() load_tm
      FROM abc_fct_rr_dist a
     WHERE a.month_code = v_month
       AND IFNULL(a.all_qty, 0) = 0
       AND IFNULL(a.fm_amt, 0) <> 0
       AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
     GROUP BY a.month_code, a.dist_type,
              a.fm_dept_code, a.fm_dept_name,
              a.fm_dept_type_code, a.fm_dept_type_name,
              a.fm_func_code, a.fm_func_name,
              a.fm_reso_code, a.fm_reso_name,
              a.fm_car, a.driv_code, a.driv_name;

  -- ========== RA未分摊检测 ==========
  -- 同RR逻辑，从RA分摊结果表中查找未分摊记录
  SET v_sqlstate = 'RA分摊检测-未分摊';
  INSERT INTO abc_fct_no_dist_list
    SELECT a.month_code, a.dist_type,
           a.fm_dept_code, a.fm_dept_name,
           a.fm_dept_type_code, a.fm_dept_type_name,
           a.fm_func_code, a.fm_func_name,
           a.fm_reso_code, a.fm_reso_name,
           NULL fm_acti_type_code, NULL fm_acti_type_name,
           NULL fm_acti_code, a.fm_car,
           a.driv_code, a.driv_name,
           MAX(a.fm_amt) amt, NOW() load_tm
      FROM abc_fct_ra_dist a
     WHERE a.month_code = v_month
       AND IFNULL(a.all_qty, 0) = 0
       AND IFNULL(a.fm_amt, 0) <> 0
       AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
     GROUP BY a.month_code, a.dist_type,
              a.fm_dept_code, a.fm_dept_name,
              a.fm_dept_type_code, a.fm_dept_type_name,
              a.fm_func_code, a.fm_func_name,
              a.fm_reso_code, a.fm_reso_name,
              a.fm_car, a.driv_code, a.driv_name;

  -- ========== AA未分摊检测 ==========
  -- AA层开始有作业信息，fm_acti_type_code/fm_acti_code 从结果表取实际值
  SET v_sqlstate = 'AA分摊检测-未分摊';
  INSERT INTO abc_fct_no_dist_list
    SELECT a.month_code, a.dist_type,
           a.fm_dept_code, a.fm_dept_name,
           a.fm_dept_type_code, a.fm_dept_type_name,
           a.fm_func_code, a.fm_func_name,
           a.fm_reso_code, a.fm_reso_name,
           a.fm_acti_type_code, a.fm_acti_type_name,
           a.fm_acti_code, a.fm_car,
           a.driv_code, a.driv_name,
           MAX(a.fm_amt) amt, NOW() load_tm
      FROM abc_fct_aa_dist a
     WHERE a.month_code = v_month
       AND IFNULL(a.all_qty, 0) = 0
       AND IFNULL(a.fm_amt, 0) <> 0
       AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
     GROUP BY a.month_code, a.dist_type,
              a.fm_dept_code, a.fm_dept_name,
              a.fm_dept_type_code, a.fm_dept_type_name,
              a.fm_func_code, a.fm_func_name,
              a.fm_reso_code, a.fm_reso_name,
              a.fm_acti_type_code, a.fm_acti_type_name,
              a.fm_acti_code, a.fm_car,
              a.driv_code, a.driv_name;

  -- ========== AO未分摊检测 ==========
  -- 从AO分摊结果表中查找未分摊到运单的记录
  SET v_sqlstate = 'AO分摊检测-未分摊';
  INSERT INTO abc_fct_no_dist_list
    SELECT a.month_code, a.dist_type,
           a.fm_dept_code, a.fm_dept_name,
           a.fm_dept_type_code, a.fm_dept_type_name,
           a.fm_func_code, a.fm_func_name,
           a.fm_reso_code, a.fm_reso_name,
           a.fm_acti_type_code, a.fm_acti_type_name,
           a.fm_acti_code, a.fm_car,
           a.driv_code, a.driv_name,
           MAX(a.fm_amt) amt, NOW() load_tm
      FROM abc_fct_ao_dist a
     WHERE a.month_code = v_month
       AND IFNULL(a.all_qty, 0) = 0
       AND IFNULL(a.fm_amt, 0) <> 0
       AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
     GROUP BY a.month_code, a.dist_type,
              a.fm_dept_code, a.fm_dept_name,
              a.fm_dept_type_code, a.fm_dept_type_name,
              a.fm_func_code, a.fm_func_name,
              a.fm_reso_code, a.fm_reso_name,
              a.fm_acti_type_code, a.fm_acti_type_name,
              a.fm_acti_code, a.fm_car,
              a.driv_code, a.driv_name;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
