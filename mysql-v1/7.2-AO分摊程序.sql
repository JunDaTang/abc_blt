-- ============================================================
-- 存储过程: p_abc_fct_ao_dist
-- 功能: AO（作业→运单）分摊，将作业成本（RA结果+AA结果）按动因量比例最终分摊到每个运单
--       这是四级分摊的最后一级，分摊结果直接落到运单粒度
--       资源来源 = RA分摊结果(to_amt) UNION ALL AA分摊结果(to_amt)
-- 输入参数: p_to_dt - 截至日期（默认当前日期），用于确定分摊所属月份
-- 输入表: abc_dim_dept（机构维表）、abc_rel_ao_dist（AO分摊规则）、
--         abc_fct_ra_dist（RA分摊结果）、abc_fct_aa_dist（AA分摊结果）、
--         abc_fct_ao_driv（AO动因量-运单级别）
-- 输出表: abc_fct_ao_dist（AO分摊结果）、abc_fct_ao_dist_tmp01/02/03/04（中间临时表）
-- 执行顺序: 第9步-AO分摊（四级分摊模型第4级：作业→运单，依赖RA+AA分摊完成）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : 生成AO分摊结果
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-30  生成AO分摊结果

DROP PROCEDURE IF EXISTS p_abc_fct_ao_dist;
DELIMITER //
CREATE PROCEDURE p_abc_fct_ao_dist(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_ao_dist';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_ao_dist_tmp01;
  DELETE FROM abc_fct_ao_dist_tmp02;
  DELETE FROM abc_fct_ao_dist_tmp03;
  DELETE FROM abc_fct_ao_dist_tmp04;
  DELETE FROM abc_fct_ao_dist a WHERE a.month_code = v_month;

  SET v_sqlstate = '建立分摊标准';
  INSERT INTO abc_fct_ao_dist_tmp01
    SELECT b.mode_code,
           a.dept_code         fm_dept_code,
           a.dept_name         fm_dept_name,
           b.fm_dept_type_code,
           b.fm_dept_type_name,
           b.fm_func_code,
           b.fm_func_name,
           b.fm_reso_code,
           b.fm_reso_name,
           b.fm_acti_code,
           b.fm_acti_name,
           b.dist_type,
           b.driv_code,
           b.driv_name
      FROM abc_dim_dept a
     INNER JOIN abc_rel_ao_dist b
        ON a.dept_type = b.fm_dept_type_code
       AND b.fm_dt <= v_fm_date
       AND b.to_dt >= v_fm_date
     WHERE a.fm_tm <= v_fm_date
       AND a.to_tm >= v_fm_date;

  SET v_sqlstate = '合并资源';
  INSERT INTO abc_fct_ao_dist_tmp02
    SELECT a.to_dept_code fm_dept_code,
           a.to_func_code fm_func_code,
           a.to_reso_code fm_reso_code,
           a.to_acti_type_code fm_acti_type_code,
           a.to_acti_code fm_acti_code,
           a.to_car fm_car,
           SUM(a.to_amt) fm_amt
      FROM abc_fct_ra_dist a
     WHERE a.month_code = v_month
       AND a.to_amt <> 0
     GROUP BY a.to_dept_code,
              a.to_func_code,
              a.to_reso_code,
              a.to_acti_type_code,
              a.to_acti_code,
              a.to_car
    UNION ALL
    SELECT a.to_dept_code fm_dept_code,
           a.to_func_code fm_func_code,
           a.to_reso_code fm_reso_code,
           a.to_acti_type_code fm_acti_type_code,
           a.to_acti_code fm_acti_code,
           a.to_car fm_car,
           SUM(a.to_amt) fm_amt
      FROM abc_fct_aa_dist a
     WHERE a.month_code = v_month
       AND a.to_amt <> 0
     GROUP BY a.to_dept_code,
              a.to_func_code,
              a.to_reso_code,
              a.to_acti_type_code,
              a.to_acti_code,
              a.to_car;

  SET v_sqlstate = '关联资源';
  INSERT INTO abc_fct_ao_dist_tmp03
    SELECT a.mode_code,
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
           a.fm_acti_code      fm_acti_type_code,
           a.fm_acti_name      fm_acti_type_name,
           b.fm_acti_code,
           b.fm_car,
           b.fm_amt,
           a.dist_type,
           a.driv_code,
           a.driv_name
      FROM abc_fct_ao_dist_tmp01 a
      LEFT JOIN abc_fct_ao_dist_tmp02 b
        ON a.fm_dept_code = b.fm_dept_code
       AND a.fm_func_code = b.fm_func_code
       AND a.fm_reso_code = b.fm_reso_code
       AND a.fm_acti_code = b.fm_acti_type_code;

  SET v_sqlstate = '生成动因';
  INSERT INTO abc_fct_ao_dist_tmp04
    SELECT a.mode_code,
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
           a.fm_acti_type_code,
           a.fm_acti_type_name,
           a.fm_acti_code,
           a.fm_car,
           a.fm_amt,
           a.dist_type,
           a.driv_code,
           a.driv_name,
           b.waybill_no,
           b.qty,
           SUM(b.qty) OVER(PARTITION BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_acti_code, a.fm_car) all_qty
      FROM abc_fct_ao_dist_tmp03 a
      LEFT JOIN abc_fct_ao_driv b
        ON a.fm_dept_code = b.dept_code
       AND a.fm_func_code = b.func_code
       AND IFNULL(a.fm_car, 'abc') = IFNULL(b.car_no, 'abc')
       AND a.fm_acti_code = b.acti_code
       AND a.driv_code = b.driv_code
       AND b.month_code = v_month;

  SET v_sqlstate = '生成分摊结果';
  INSERT INTO abc_fct_ao_dist
    SELECT a.mode_code,
           v_month month_code,
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
           a.fm_acti_type_code,
           a.fm_acti_type_name,
           a.fm_acti_code,
           a.fm_car,
           a.fm_amt,
           a.dist_type,
           a.driv_code,
           a.driv_name,
           a.waybill_no,
           a.qty,
           a.all_qty,
           CASE
             WHEN a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001') THEN
              a.fm_amt
             ELSE
              a.fm_amt * a.qty / a.all_qty
           END to_amt,
           NOW() load_tm
      FROM abc_fct_ao_dist_tmp04 a;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
