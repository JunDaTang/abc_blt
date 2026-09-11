-- ============================================================
-- 存储过程: p_abc_fct_aa_dist
-- 功能: AA（作业→作业）分摊，将辅助作业成本按动因量比例分摊到其他作业
--       资源来源 = RA分摊结果(to_amt)，将RA分摊到辅助作业的成本再分摊到其他作业
-- 输入参数: p_to_dt - 截至日期（默认当前日期），用于确定分摊所属月份
-- 输入表: abc_dim_dept（机构维表）、abc_rel_aa_dist（AA分摊规则）、
--         abc_fct_ra_dist（RA分摊结果，作为AA的资源来源）、abc_fct_aa_driv（AA动因量）
-- 输出表: abc_fct_aa_dist（AA分摊结果）、abc_fct_aa_dist_tmp01/02/03/04（中间临时表）
-- 执行顺序: 第8步-AA分摊（四级分摊模型第3级：作业→作业，依赖RA分摊完成）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : 生成AA分摊结果
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-30  生成AA分摊结果

DROP PROCEDURE IF EXISTS p_abc_fct_aa_dist;
DELIMITER //
CREATE PROCEDURE p_abc_fct_aa_dist(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 参数默认值处理：如果未传入日期，则使用当前日期
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_aa_dist';
  -- 计算分摊月份范围：v_fm_date=月初（如2019-06-01），v_to_date=下月初（如2019-07-01）
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  -- 月份编码，格式YYYYMM，如201906
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  -- 清空当月临时表和结果表，保证幂等性（可重复执行）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_aa_dist_tmp01;
  DELETE FROM abc_fct_aa_dist_tmp02;
  DELETE FROM abc_fct_aa_dist_tmp03;
  DELETE FROM abc_fct_aa_dist_tmp04;
  DELETE FROM abc_fct_aa_dist a WHERE a.month_code = v_month;

  -- ============================================================
  -- 第1步(tmp01): 建立分摊标准
  -- 将AA分摊规则表(abc_rel_aa_dist)与机构维表(abc_dim_dept)做展开
  -- 相比RR/RA，AA多了源作业维度(fm_acti_code)和目标作业维度(to_acti_code)
  -- 每行代表一条分摊路径：源(机构+功能中心+资源+作业) → 目标(机构+功能中心+资源+作业)
  -- ============================================================
  SET v_sqlstate = '建立分摊标准';
  INSERT INTO abc_fct_aa_dist_tmp01
    SELECT b.mode_code,
           a.dept_code         fm_dept_code,    -- 源机构编码
           a.dept_name         fm_dept_name,    -- 源机构名称
           b.fm_dept_type_code,                 -- 源机构类型
           b.fm_dept_type_name,
           b.fm_func_code,                      -- 源功能中心
           b.fm_func_name,
           b.fm_reso_code,                      -- 源资源代码
           b.fm_reso_name,
           b.fm_acti_code,                      -- 源作业代码（辅助作业，成本从这里转出）
           b.fm_acti_name,                      -- 源作业名称
           a.dept_code         to_dept_code,    -- 目标机构编码
           a.dept_name         to_dept_name,    -- 目标机构名称
           b.to_dept_type_code,                 -- 目标机构类型
           b.to_dept_type_name,
           b.to_func_code,                      -- 目标功能中心
           b.to_func_name,
           b.to_reso_code,                      -- 目标资源代码
           b.to_reso_name,
           b.to_acti_code,                      -- 目标作业代码（成本分摊到哪个作业）
           b.to_acti_name,                      -- 目标作业名称
           b.dist_type,                         -- 分摊方式
           b.driv_code,                         -- 动因代码(XX001表示直接计入不分摊)
           b.driv_name
      FROM abc_dim_dept a
     INNER JOIN abc_rel_aa_dist b
        ON a.dept_type = b.fm_dept_type_code   -- 按机构类型关联，展开所有同类型机构
       AND b.fm_dt <= v_fm_date                -- 规则有效期覆盖分摊月份
       AND b.to_dt >= v_fm_date
     WHERE a.fm_tm <= v_fm_date                -- 机构有效期覆盖分摊月份
       AND a.to_tm >= v_fm_date;

  -- ============================================================
  -- 第2步(tmp02): 合并资源
  -- AA的资源来源仅来自RA分摊结果(abc_fct_ra_dist)
  -- 取RA的to端（分摊结果）按 机构+功能中心+资源+作业类型+作业+车辆 汇总
  -- 得到每个辅助作业的待分摊总金额
  -- ============================================================
  SET v_sqlstate = '合并资源';
  INSERT INTO abc_fct_aa_dist_tmp02
    SELECT a.to_dept_code fm_dept_code,        -- RA结果的to_dept变成AA的fm_dept
           a.to_func_code fm_func_code,
           a.to_reso_code fm_reso_code,
           a.to_acti_type_code fm_acti_type_code,  -- 作业类型
           a.to_acti_code fm_acti_code,            -- 作业代码
           a.to_car fm_car,                        -- 车辆
           SUM(a.to_amt) fm_amt                    -- 汇总RA分摊金额
      FROM abc_fct_ra_dist a
     WHERE a.month_code = v_month
       AND a.to_amt <> 0
     GROUP BY a.to_dept_code,
              a.to_func_code,
              a.to_reso_code,
              a.to_acti_type_code,
              a.to_acti_code,
              a.to_car;

  -- ============================================================
  -- 第3步(tmp03): 关联资源
  -- 将分摊标准(tmp01)与合并后的资源(tmp02)关联
  -- 匹配条件: 源机构+源功能中心+源资源+源作业类型
  -- LEFT JOIN: 保留所有分摊路径，无匹配资源时fm_amt为NULL
  -- ============================================================
  SET v_sqlstate = '关联资源';
  INSERT INTO abc_fct_aa_dist_tmp03
    SELECT a.mode_code,
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
           a.fm_acti_code      fm_acti_type_code,  -- 规则中的源作业代码作为作业类型
           a.fm_acti_name      fm_acti_type_name,
           b.fm_acti_code,                         -- 实际作业代码（从资源汇总来）
           b.fm_car,                               -- 车辆
           b.fm_amt,                               -- 待分摊金额
           a.to_dept_code,
           a.to_dept_name,
           a.to_dept_type_code,
           a.to_dept_type_name,
           a.to_func_code,
           a.to_func_name,
           a.to_reso_code,
           a.to_reso_name,
           a.to_acti_code,
           a.to_acti_name,
           b.fm_car            to_car,             -- 车辆信息传递到目标侧
           a.dist_type,
           a.driv_code,
           a.driv_name
      FROM abc_fct_aa_dist_tmp01 a
      LEFT JOIN abc_fct_aa_dist_tmp02 b
        ON a.fm_dept_code = b.fm_dept_code     -- 源机构匹配
       AND a.fm_func_code = b.fm_func_code     -- 源功能中心匹配
       AND a.fm_reso_code = b.fm_reso_code     -- 源资源代码匹配
       AND a.fm_acti_code = b.fm_acti_type_code;  -- 源作业代码匹配

  -- ============================================================
  -- 第4步(tmp04): 生成动因（关联动因）
  -- 将上一步结果与AA动因表(abc_fct_aa_driv)关联，获取每个目标作业的动因量(qty)
  -- 匹配条件比RA更严格，多了作业代码后缀匹配(SUBSTRING从第8位起)
  -- 窗口函数分区键增加了fm_acti_code: 同一源作业的所有分摊目标合计
  -- ============================================================
  SET v_sqlstate = '生成动因';
  INSERT INTO abc_fct_aa_dist_tmp04
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
           a.to_dept_code,
           a.to_dept_name,
           a.to_dept_type_code,
           a.to_dept_type_name,
           a.to_func_code,
           a.to_func_name,
           a.to_reso_code,
           a.to_reso_name,
           a.to_acti_code to_acti_type_code,    -- 规则中的目标作业代码作为作业类型
           a.to_acti_name to_acti_type_name,
           b.acti_code to_acti_code,            -- 动因表中的精确作业代码
           a.to_car,
           a.dist_type,
           a.driv_code,
           a.driv_name,
           b.qty,                                                          -- 该目标作业的动因量
           SUM(b.qty) OVER(PARTITION BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_acti_code, a.fm_car) all_qty  -- 总动因量
      FROM abc_fct_aa_dist_tmp03 a
      LEFT JOIN abc_fct_aa_driv b
        ON a.to_dept_code = b.dept_code        -- 目标机构匹配
       AND a.to_func_code = b.func_code        -- 目标功能中心匹配
       AND IFNULL(a.to_car, 'abc') = IFNULL(b.car_no, 'abc')  -- 车辆匹配(NULL视为相等)
       AND a.to_acti_code = SUBSTRING(b.acti_code, 1, 6)      -- 目标作业代码前6位匹配
       AND IFNULL(SUBSTRING(a.fm_acti_code, 8), 'abc') =
           IFNULL(SUBSTRING(b.acti_code, 8), 'abc')            -- 源作业代码后缀匹配（第8位起）
       AND a.driv_code = b.driv_code           -- 动因代码匹配
       AND b.month_code = v_month;

  -- ============================================================
  -- 第5步: 生成分摊结果，写入最终表 abc_fct_aa_dist
  -- 核心分摊公式:
  --   当动因代码为 RR001/RA001/AA001/AO001 时 → 直接计入(to_amt = fm_amt)
  --   其他动因代码 → 按比例分摊: to_amt = fm_amt × (qty / all_qty)
  --   即: 分摊金额 = 资源金额 × (该对象动因量 / 总动因量)
  -- ============================================================
  SET v_sqlstate = '生成分摊结果';
  INSERT INTO abc_fct_aa_dist
    SELECT mode_code,
           v_month month_code,                 -- 月份编码
           fm_dept_code,
           fm_dept_name,
           fm_dept_type_code,
           fm_dept_type_name,
           fm_func_code,
           fm_func_name,
           fm_reso_code,
           fm_reso_name,
           fm_acti_type_code,                  -- 源作业类型代码
           fm_acti_type_name,                  -- 源作业类型名称
           fm_acti_code,                       -- 源作业代码
           fm_car,                             -- 车辆
           fm_amt,                             -- 分摊前原始金额
           to_dept_code,
           to_dept_name,
           to_dept_type_code,
           to_dept_type_name,
           to_func_code,
           to_func_name,
           to_reso_code,
           to_reso_name,
           to_acti_type_code,                  -- 目标作业类型代码
           to_acti_type_name,                  -- 目标作业类型名称
           to_acti_code,                       -- 目标作业代码
           to_car,                             -- 目标车辆
           dist_type,
           driv_code,
           driv_name,
           qty,                                -- 该目标的动因量
           all_qty,                            -- 总动因量
           CASE
             WHEN a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001') THEN
              a.fm_amt                         -- XX001动因: 直接计入，不分摊
             ELSE
              a.fm_amt * a.qty / a.all_qty     -- 按比例分摊: 金额 × (单个动因量/总动因量)
           END to_amt,                         -- 分摊后金额
           NOW() load_tm                       -- 数据加载时间戳
      FROM abc_fct_aa_dist_tmp04 a;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
