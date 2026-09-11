-- ============================================================
-- 存储过程: p_abc_fct_check_dist
-- 功能: 四级分摊检测程序，对RR/RA/AA/AO每一级分摊进行5项检测
--       dist_step=1 理论金额：规则配置中应分摊的资源总额（关联规则表后取MAX(fm_amt)汇总）
--       dist_step=2 实际金额：实际关联到的资源总额（不关联规则表，直接取MAX(fm_amt)汇总）
--       dist_step=3 已分摊金额：结果表中所有 to_amt 的合计（含直接计入和按比例分摊）
--       dist_step=4 未分摊金额：all_qty=0 且非直接计入的资源金额（无动因量导致无法分摊）
--       dist_step=5 重复分摊金额：理论 - 实际的差额（fm_amt - SUM(to_amt)）
--       5项检测用于验证分摊的完整性和准确性，理想情况下各项应平衡
-- 输入参数: p_to_dt - 截止日期（用于计算检测月份）
-- 输入表: abc_fct_rr_dist_tmp03、abc_fct_ra_dist_tmp04、abc_fct_aa_dist_tmp04、
--         abc_fct_ao_dist_tmp04（各分摊中间结果表）
--         abc_fct_rr_dist、abc_fct_ra_dist、abc_fct_aa_dist、abc_fct_ao_dist（各分摊最终结果）
--         abc_rel_rr_dist、abc_rel_ra_dist、abc_rel_aa_dist、abc_rel_ao_dist（分摊规则）
-- 输出表: abc_fct_chk_dist（分摊检测结果表，按月份+分摊类型+检测步骤记录金额）
-- 执行顺序: 第10步-分摊检测（在RR→RA→AA→AO四级分摊全部完成后执行）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : 分摊检测程序
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-30  分摊检测程序

DROP PROCEDURE IF EXISTS p_abc_fct_check_dist;
DELIMITER //
CREATE PROCEDURE p_abc_fct_check_dist(IN p_to_dt DATE)
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

  -- 清空当月检测结果（保证幂等性）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_chk_dist a WHERE a.month_code = v_month;

  -- ========== RR分摊检测（资源→资源） ==========

  -- RR-理论：关联规则表后取应分摊总额（有规则配置的资源才计入）
  SET v_sqlstate = 'RR分摊检测-理论';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RR' dist_type, 1 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_rr_dist_tmp03 a
             INNER JOIN abc_rel_rr_dist b
                ON a.fm_dept_type_code = b.fm_dept_type_code
               AND a.fm_func_code = b.fm_func_code
               AND a.fm_reso_code = b.fm_reso_code
               AND b.fm_dt <= v_fm_date AND b.to_dt >= v_fm_date
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- RR-实际：不关联规则表，直接取中间结果表中实际关联到的资源总额
  SET v_sqlstate = 'RR分摊检测-实际';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RR' dist_type, 2 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_rr_dist_tmp03 a
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- RR-已分摊：结果表中所有to_amt的合计（含直接计入和按比例分摊）
  SET v_sqlstate = 'RR分摊检测-已分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RR' dist_type, 3 dist_step,
           SUM(a.to_amt) amt, NOW() load_tm
      FROM abc_fct_rr_dist a WHERE a.month_code = v_month;

  -- RR-未分摊：all_qty=0（无动因量）且非直接计入的资源金额，这些金额无法分摊出去
  SET v_sqlstate = 'RR分摊检测-未分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RR' dist_type, 4 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_rr_dist a
             WHERE a.month_code = v_month
               AND IFNULL(a.all_qty, 0) = 0
               AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- RR-重复分摊：理论金额 - 实际金额的差额，检测是否存在超额分摊
  SET v_sqlstate = 'RR分摊检测-重复分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RR' dist_type, 5 dist_step,
           SUM(fm_amt - to_amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) fm_amt, SUM(a.to_amt) to_amt
              FROM abc_fct_rr_dist a
             WHERE a.month_code = v_month
               AND (IFNULL(a.all_qty, 0) <> 0 OR a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001'))
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- ========== RA分摊检测（资源→作业） ==========

  -- RA-理论：关联规则表后取应分摊总额
  SET v_sqlstate = 'RA分摊检测-理论';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RA' dist_type, 1 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_ra_dist_tmp04 a
             INNER JOIN abc_rel_ra_dist b
                ON a.fm_dept_type_code = b.fm_dept_type_code
               AND a.fm_func_code = b.fm_func_code
               AND a.fm_reso_code = b.fm_reso_code
               AND b.fm_dt <= v_fm_date AND b.to_dt >= v_fm_date
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- RA-实际：不关联规则表，直接取中间结果表中实际关联到的资源总额
  SET v_sqlstate = 'RA分摊检测-实际';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RA' dist_type, 2 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_ra_dist_tmp04 a
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- RA-已分摊：结果表中所有to_amt的合计
  SET v_sqlstate = 'RA分摊检测-已分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RA' dist_type, 3 dist_step,
           SUM(a.to_amt) amt, NOW() load_tm
      FROM abc_fct_ra_dist a WHERE a.month_code = v_month;

  -- RA-未分摊：all_qty=0且非直接计入的资源金额
  SET v_sqlstate = 'RA分摊检测-未分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RA' dist_type, 4 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_ra_dist a
             WHERE a.month_code = v_month
               AND IFNULL(a.all_qty, 0) = 0
               AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- RA-重复分摊：理论金额 - 实际金额的差额
  SET v_sqlstate = 'RA分摊检测-重复分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'RA' dist_type, 5 dist_step,
           SUM(fm_amt - to_amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car,
                   MAX(a.fm_amt) fm_amt, SUM(a.to_amt) to_amt
              FROM abc_fct_ra_dist a
             WHERE a.month_code = v_month
               AND (IFNULL(a.all_qty, 0) <> 0 OR a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001'))
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) t;

  -- ========== AA分摊检测（作业→作业） ==========

  -- AA-理论：关联规则表后取应分摊总额（注意：AA的关联条件多了作业代码）
  SET v_sqlstate = 'AA分摊检测-理论';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AA' dist_type, 1 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_aa_dist_tmp04 a
             INNER JOIN abc_rel_aa_dist b
                ON a.fm_dept_type_code = b.fm_dept_type_code
               AND a.fm_func_code = b.fm_func_code
               AND a.fm_reso_code = b.fm_reso_code
               AND a.fm_acti_type_code = b.fm_acti_code
               AND b.fm_dt <= v_fm_date AND b.to_dt >= v_fm_date
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- AA-实际：不关联规则表，直接取中间结果表中实际关联到的资源总额
  SET v_sqlstate = 'AA分摊检测-实际';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AA' dist_type, 2 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_aa_dist_tmp04 a
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- AA-已分摊：结果表中所有to_amt的合计
  SET v_sqlstate = 'AA分摊检测-已分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AA' dist_type, 3 dist_step,
           SUM(a.to_amt) amt, NOW() load_tm
      FROM abc_fct_aa_dist a WHERE a.month_code = v_month;

  -- AA-未分摊：all_qty=0且非直接计入的资源金额
  SET v_sqlstate = 'AA分摊检测-未分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AA' dist_type, 4 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_aa_dist a
             WHERE a.month_code = v_month
               AND IFNULL(a.all_qty, 0) = 0
               AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- AA-重复分摊：理论金额 - 实际金额的差额
  SET v_sqlstate = 'AA分摊检测-重复分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AA' dist_type, 5 dist_step,
           SUM(fm_amt - to_amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) fm_amt, SUM(a.to_amt) to_amt
              FROM abc_fct_aa_dist a
             WHERE a.month_code = v_month
               AND (IFNULL(a.all_qty, 0) <> 0 OR a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001'))
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- ========== AO分摊检测（作业→运单） ==========

  -- AO-理论：关联规则表后取应分摊总额
  SET v_sqlstate = 'AO分摊检测-理论';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AO' dist_type, 1 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_ao_dist_tmp04 a
             INNER JOIN abc_rel_ao_dist b
                ON a.fm_dept_type_code = b.fm_dept_type_code
               AND a.fm_func_code = b.fm_func_code
               AND a.fm_reso_code = b.fm_reso_code
               AND a.fm_acti_type_code = b.fm_acti_code
               AND b.fm_dt <= v_fm_date AND b.to_dt >= v_fm_date
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- AO-实际：不关联规则表，直接取中间结果表中实际关联到的资源总额
  SET v_sqlstate = 'AO分摊检测-实际';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AO' dist_type, 2 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_ao_dist_tmp04 a
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- AO-已分摊：结果表中所有to_amt的合计
  SET v_sqlstate = 'AO分摊检测-已分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AO' dist_type, 3 dist_step,
           SUM(a.to_amt) amt, NOW() load_tm
      FROM abc_fct_ao_dist a WHERE a.month_code = v_month;

  -- AO-未分摊：all_qty=0且非直接计入的资源金额
  SET v_sqlstate = 'AO分摊检测-未分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AO' dist_type, 4 dist_step,
           SUM(amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) amt
              FROM abc_fct_ao_dist a
             WHERE a.month_code = v_month
               AND IFNULL(a.all_qty, 0) = 0
               AND a.driv_code NOT IN ('RR001', 'RA001', 'AA001', 'AO001')
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  -- AO-重复分摊：理论金额 - 实际金额的差额
  SET v_sqlstate = 'AO分摊检测-重复分摊';
  INSERT INTO abc_fct_chk_dist
    SELECT v_month month_code, 'AO' dist_type, 5 dist_step,
           SUM(fm_amt - to_amt) amt, NOW() load_tm
      FROM (SELECT a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                   a.fm_acti_type_code, a.fm_acti_code, a.fm_car,
                   MAX(a.fm_amt) fm_amt, SUM(a.to_amt) to_amt
              FROM abc_fct_ao_dist a
             WHERE a.month_code = v_month
               AND (IFNULL(a.all_qty, 0) <> 0 OR a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001'))
             GROUP BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code,
                      a.fm_acti_type_code, a.fm_acti_code, a.fm_car) t;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
