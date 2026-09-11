-- ============================================================
-- 存储过程: p_abc_fct_ra_dist
-- 功能: RA（资源→作业）分摊，将资源成本（含RR分摊后的结果）按动因量比例分摊到各作业
--       资源来源 = RR分摊结果(to_amt) + 资源清单(原始金额)，合并后按动因分摊到作业
-- 输入参数: p_to_dt - 截至日期（默认当前日期），用于确定分摊所属月份
-- 输入表: abc_dim_dept（机构维表）、abc_rel_ra_dist（RA分摊规则）、
--         abc_fct_rr_dist（RR分摊结果）、abc_fct_reso_list（资源清单）、
--         abc_fct_ra_driv（RA动因量）
-- 输出表: abc_fct_ra_dist（RA分摊结果）、abc_fct_ra_dist_tmp01/02/03/04（中间临时表）
-- 执行顺序: 第7步-RA分摊（四级分摊模型第2级：资源→作业，依赖RR分摊完成）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-30
-- purpose : 生成RA分摊结果
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-30  生成RA分摊结果

DROP PROCEDURE IF EXISTS p_abc_fct_ra_dist;
DELIMITER //
CREATE PROCEDURE p_abc_fct_ra_dist(IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_month   VARCHAR(10);
  
  -- 参数默认值处理：如果未传入日期，则使用当前日期
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_ra_dist';
  -- 计算分摊月份范围：v_fm_date=月初（如2019-06-01），v_to_date=下月初（如2019-07-01）
  SET v_fm_date   = DATE_FORMAT(DATE_ADD(p_to_dt, INTERVAL -1 MONTH), '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  -- 月份编码，格式YYYYMM，如201906
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');

  -- 清空当月临时表和结果表，保证幂等性（可重复执行）
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_ra_dist_tmp01;
  DELETE FROM abc_fct_ra_dist_tmp02;
  DELETE FROM abc_fct_ra_dist_tmp03;
  DELETE FROM abc_fct_ra_dist_tmp04;
  DELETE FROM abc_fct_ra_dist a WHERE a.month_code = v_month;

  -- ============================================================
  -- 第1步(tmp01): 建立分摊标准
  -- 将RA分摊规则表(abc_rel_ra_dist)与机构维表(abc_dim_dept)做展开
  -- 按机构类型匹配，生成所有「源功能中心→目标作业」的分摊关系行
  -- 相比RR，RA多了目标作业维度(to_acti_code/to_acti_name)
  -- ============================================================
  SET v_sqlstate = '建立分摊标准';
  INSERT INTO abc_fct_ra_dist_tmp01
    SELECT b.mode_code,
           a.dept_code         fm_dept_code,    -- 源机构编码
           a.dept_name         fm_dept_name,    -- 源机构名称
           b.fm_dept_type_code,                 -- 源机构类型(YYD/YYC/FBC/ZZC)
           b.fm_dept_type_name,
           b.fm_func_code,                      -- 源功能中心(1010/1020/1030/1040)
           b.fm_func_name,
           b.fm_reso_code,                      -- 源资源代码
           b.fm_reso_name,
           a.dept_code         to_dept_code,    -- 目标机构编码
           a.dept_name         to_dept_name,    -- 目标机构名称
           b.to_dept_type_code,                 -- 目标机构类型
           b.to_dept_type_name,
           b.to_func_code,                      -- 目标功能中心
           b.to_func_name,
           b.to_reso_code,                      -- 目标资源代码
           b.to_reso_name,
           b.to_acti_code,                      -- 目标作业代码（RA独有，分摊到具体作业）
           b.to_acti_name,                      -- 目标作业名称
           b.dist_type,                         -- 分摊方式
           b.driv_code,                         -- 动因代码(XX001表示直接计入不分摊)
           b.driv_name
      FROM abc_dim_dept a
     INNER JOIN abc_rel_ra_dist b
        ON a.dept_type = b.fm_dept_type_code   -- 按机构类型关联，展开所有同类型机构
       AND b.fm_dt <= v_fm_date                -- 规则有效期覆盖分摊月份
       AND b.to_dt >= v_fm_date
     WHERE a.fm_tm <= v_fm_date                -- 机构有效期覆盖分摊月份
       AND a.to_tm >= v_fm_date;

  -- ============================================================
  -- 第2步(tmp02): 合并资源
  -- RA的资源来源有两部分，需要合并:
  --   1) RR分摊结果(abc_fct_rr_dist): 上一级RR分摊到各功能中心的金额(to_amt)
  --   2) 资源清单(abc_fct_reso_list): 未经RR分摊的原始资源金额
  -- 按 源机构+源功能中心+源资源+车辆 汇总，得到每个资源维度的待分摊总金额
  -- ============================================================
  SET v_sqlstate = '合并资源';
  INSERT INTO abc_fct_ra_dist_tmp02
    SELECT fm_dept_code,
           fm_func_code,
           fm_reso_code,
           fm_car,
           SUM(fm_amt) fm_amt                   -- 汇总: RR分摊金额 + 资源清单金额
      FROM (SELECT a.to_dept_code fm_dept_code,  -- 来自RR分摊结果: RR的to_dept变成RA的fm_dept
                   a.to_func_code fm_func_code,
                   a.to_reso_code fm_reso_code,
                   a.fm_car,
                   a.to_amt       fm_amt         -- RR分摊后的金额
              FROM abc_fct_rr_dist a
             WHERE a.month_code = v_month
               AND a.to_amt <> 0
            UNION ALL
            SELECT b.dept_code, b.func_code, b.reso_code, b.car_no, b.amt  -- 来自资源清单: 原始金额
              FROM abc_fct_reso_list b
             WHERE b.month_code = v_month) t
     GROUP BY fm_dept_code, fm_func_code, fm_reso_code, fm_car;

  -- ============================================================
  -- 第3步(tmp03): 关联资源
  -- 将分摊标准(tmp01)与合并后的资源(tmp02)关联，匹配每条分摊路径对应的资源金额
  -- 通过源机构+源功能中心+源资源代码定位待分摊金额
  -- LEFT JOIN: 保留所有分摊路径，无匹配资源时fm_amt为NULL
  -- ============================================================
  SET v_sqlstate = '关联资源';
  INSERT INTO abc_fct_ra_dist_tmp03
    SELECT a.mode_code,
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
           b.fm_car,                            -- 车辆编号
           b.fm_amt,                            -- 待分摊资源总金额
           a.to_dept_code,
           a.to_dept_name,
           a.to_dept_type_code,
           a.to_dept_type_name,
           a.to_func_code,
           a.to_func_name,
           a.to_reso_code,
           a.to_reso_name,
           b.fm_car to_car,                     -- 车辆信息传递到目标侧
           a.to_acti_code,
           a.to_acti_name,
           a.dist_type,
           a.driv_code,
           a.driv_name
      FROM abc_fct_ra_dist_tmp01 a
      LEFT JOIN abc_fct_ra_dist_tmp02 b
        ON a.fm_dept_code = b.fm_dept_code     -- 源机构匹配
       AND a.fm_func_code = b.fm_func_code     -- 源功能中心匹配
       AND a.fm_reso_code = b.fm_reso_code;    -- 源资源代码匹配

  -- ============================================================
  -- 第4步(tmp04): 关联动因
  -- 将上一步结果与RA动因表(abc_fct_ra_driv)关联，获取每个目标作业的动因量(qty)
  -- 匹配条件: 目标机构+目标功能中心+车辆(可为空)+作业代码前6位+动因代码
  -- 注意: acti_code匹配用SUBSTRING截取前6位，因为动因表的acti_code可能包含更细的后缀
  -- 注意: 车辆用IFNULL处理空值，NULL和NULL视为匹配('abc'='abc')
  -- 同时用窗口函数计算每个「源」的总动因量(all_qty)
  -- ============================================================
  SET v_sqlstate = '关联动因';
  INSERT INTO abc_fct_ra_dist_tmp04
    SELECT a.mode_code,
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
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
           a.to_car,
           a.to_acti_code to_acti_type_code,    -- 规则中的作业代码(作为作业类型)
           a.to_acti_name to_acti_type_name,
           IFNULL(b.acti_code, a.to_acti_code) to_acti_code,  -- 优先取动因表的精确作业代码，无匹配则用规则代码
           a.dist_type,
           a.driv_code,
           a.driv_name,
           b.qty,                                                          -- 该目标作业的动因量
           SUM(b.qty) OVER(PARTITION BY a.fm_dept_code, a.fm_func_code, a.fm_reso_code, a.fm_car) all_qty  -- 总动因量
      FROM abc_fct_ra_dist_tmp03 a
      LEFT JOIN abc_fct_ra_driv b
        ON a.to_dept_code = b.dept_code        -- 目标机构匹配
       AND a.to_func_code = b.func_code        -- 目标功能中心匹配
       AND IFNULL(a.to_car, 'abc') = IFNULL(b.car_no, 'abc')  -- 车辆匹配(NULL视为相等)
       AND a.to_acti_code = SUBSTRING(b.acti_code, 1, 6)      -- 作业代码前6位匹配
       AND a.driv_code = b.driv_code           -- 动因代码匹配
       AND b.month_code = v_month;

  -- ============================================================
  -- 第5步: 生成分摊结果，写入最终表 abc_fct_ra_dist
  -- 核心分摊公式:
  --   当动因代码为 RR001/RA001/AA001/AO001 时 → 直接计入(to_amt = fm_amt)
  --   其他动因代码 → 按比例分摊: to_amt = fm_amt × (qty / all_qty)
  --   即: 分摊金额 = 资源金额 × (该对象动因量 / 总动因量)
  -- ============================================================
  SET v_sqlstate = '生成分摊结果';
  INSERT INTO abc_fct_ra_dist
    SELECT a.mode_code,
           v_month month_code,                 -- 月份编码
           a.fm_dept_code,
           a.fm_dept_name,
           a.fm_dept_type_code,
           a.fm_dept_type_name,
           a.fm_func_code,
           a.fm_func_name,
           a.fm_reso_code,
           a.fm_reso_name,
           a.fm_car,
           a.fm_amt,                           -- 分摊前原始金额
           a.to_dept_code,
           a.to_dept_name,
           a.to_dept_type_code,
           a.to_dept_type_name,
           a.to_func_code,
           a.to_func_name,
           a.to_reso_code,
           a.to_reso_name,
           a.to_car,
           a.to_acti_type_code,                -- 作业类型代码
           a.to_acti_type_name,                -- 作业类型名称
           a.to_acti_code,                     -- 作业代码
           a.dist_type,
           a.driv_code,
           a.driv_name,
           a.qty,                              -- 该目标的动因量
           a.all_qty,                          -- 总动因量
           CASE
             WHEN a.driv_code IN ('RR001', 'RA001', 'AA001', 'AO001') THEN
              a.fm_amt                         -- XX001动因: 直接计入，不分摊
             ELSE
              a.fm_amt * a.qty / a.all_qty     -- 按比例分摊: 金额 × (单个动因量/总动因量)
           END to_amt,                         -- 分摊后金额
           NOW() load_tm                       -- 数据加载时间戳
      FROM abc_fct_ra_dist_tmp04 a;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
