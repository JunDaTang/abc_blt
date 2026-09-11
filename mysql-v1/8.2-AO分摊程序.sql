-- ============================================================
-- 存储过程: p_abc_fct_ao_dist
-- 功能: AO（作业→运单）分摊，将作业成本按动因量分摊到每个运单
--       作业成本来源 = RA分摊结果（资源→作业）+ AA分摊结果（作业→作业）
--       分摊公式: 分摊金额 = 资源金额 × (该运单动因量 / 总动因量)
--       动因代码为 XX001 时直接计入不分摊（金额全额归该运单）
-- 输入参数: p_to_dt - 截止日期（用于计算分摊月份，取上月作为分摊期间）
-- 输入表: abc_dim_dept（机构维表）、abc_rel_ao_dist（AO分摊规则）
--         abc_fct_ra_dist（RA分摊结果）、abc_fct_aa_dist（AA分摊结果）
--         abc_fct_ao_driv（AO动因事实表）
-- 输出表: abc_fct_ao_dist（AO分摊结果）、abc_fct_ao_dist_tmp01~tmp04（中间临时表）
-- 执行顺序: 第9步-AO分摊（8.2版本，在RR→RA→AA之后执行）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : 生成AO分摊结果 (8.2版本，使用abc_rel_ao_dist)
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
  
  -- 初始化变量：计算分摊月份（取 p_to_dt 的上一个月）
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_ao_dist';
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01'); -- 月初第一天
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');                              -- 下月月初（作为区间终点）
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');                                -- 月份编码，如 201906

  -- 清空临时表和当月分摊结果（保证幂等性）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_ao_dist_tmp01;  -- 分摊标准（规则维度）
  DELETE FROM abc_fct_ao_dist_tmp02;  -- 合并资源（RA+AA的作业成本）
  DELETE FROM abc_fct_ao_dist_tmp03;  -- 关联资源（规则 LEFT JOIN 资源）
  DELETE FROM abc_fct_ao_dist_tmp04;  -- 生成动因（关联运单动因量）
  DELETE FROM abc_fct_ao_dist a WHERE a.month_code = v_month; -- 删除当月历史结果

  -- 步骤1: 建立分摊标准
  -- 将AO分摊规则与机构维表关联，生成当月有效的分摊规则明细
  -- 关联条件：机构类型 = 规则中的部门类型，且在有效期范围内
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

  -- 步骤2: 合并资源 — 将RA分摊结果和AA分摊结果合并为作业成本
  -- RA结果：资源→作业分摊后每个作业获得的成本
  -- AA结果：辅助作业间相互分摊后每个作业获得的成本
  -- 按（部门、功能中心、资源、作业类型、作业代码、车牌）维度汇总金额
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

  -- 步骤3: 关联资源 — 将分摊规则(tmp01) LEFT JOIN 作业成本(tmp02)
  -- 关联条件：部门 + 功能中心 + 资源代码 + 作业代码
  -- LEFT JOIN 保证即使某作业无成本，规则行也保留（便于检测未分摊）
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

  -- 步骤4: 生成动因 — 将关联结果(tmp03) LEFT JOIN AO动因表
  -- 关联条件：部门 + 功能中心 + 车牌(IFNULL处理NULL匹配) + 作业代码 + 动因代码 + 月份
  -- 窗口函数 SUM(qty) 计算每个(部门+功能+资源+作业+车牌)分组下的总动因量 all_qty
  -- all_qty 用于分摊公式的分母：分摊金额 = fm_amt × qty / all_qty
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

  -- 步骤5: 生成分摊结果 — 按分摊公式计算每个运单应分摊的金额
  -- 核心分摊公式：
  --   动因代码为 XX001（RR001/RA001/AA001/AO001）→ 直接计入，to_amt = fm_amt（全额归该运单）
  --   其他动因代码 → 按比例分摊，to_amt = fm_amt × qty / all_qty
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
