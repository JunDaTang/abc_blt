-- ============================================================
-- 存储过程: p_abc_fct_reso_list
-- 功能: 生成ABC资源清单，将ODS科目余额按机构和资源代码汇总，
--       区分运输资源（ZY0301→功能中心1030）和操作资源（其他→功能中心5010）
-- 输入参数:
--   p_fm_dt - 处理日期，默认当前日期
-- 输入表: ods_subj_acco（科目余额）、abc_rel_subj_reso（科目资源映射）、abc_dim_dept（机构维表）
-- 输出表: abc_fct_reso_list（资源清单事实表）
-- 执行顺序: 第4步-资源数据汇总（RR分摊的输入源，是四级分摊的起点）
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成ABC资源清单数据
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-15  生成ABC资源清单数据

DROP PROCEDURE IF EXISTS p_abc_fct_reso_list;
DELIMITER //
CREATE PROCEDURE p_abc_fct_reso_list(IN p_fm_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_rowcount  INT;
  DECLARE v_yyyymm VARCHAR(1000);
  
  -- 参数默认值处理
  IF p_fm_dt IS NULL THEN SET p_fm_dt = NOW(); END IF;
  -- 状态追踪变量初始化
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_fct_reso_list';
  SET v_yyyymm    = DATE_FORMAT(p_fm_dt, '%Y%m');  -- 月份编码，格式 YYYYMM

  -- 步骤1: 删除当月已有资源清单数据，确保幂等性
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_fct_reso_list a WHERE a.month_code = v_yyyymm;

  -- 步骤2: 汇总生成资源清单
  -- 将科目余额通过科目资源映射关联到资源代码，按机构+资源+车牌汇总金额
  -- 功能中心区分逻辑：
  --   ZY0301（运输资源）→ func_code='1030'（运输功能中心）
  --   其他资源           → func_code='5010'（操作功能中心）
  -- 拉链表时间范围过滤：关联的科目映射和机构维表都按生效/截止时间匹配当月
  SET v_sqlstate = '生成资源清单';
  INSERT INTO abc_fct_reso_list
    SELECT a.month_code,
           a.dept_code,
           c.dept_type,
           c.dept_type_name,
           -- 功能中心代码：运输资源归1030（运输），其他归5010（操作）
           CASE
             WHEN b.reso_code = 'ZY0301' THEN '1030'
             ELSE '5010'
           END func_code,
           -- 功能中心名称
           CASE
             WHEN b.reso_code = 'ZY0301' THEN '运输'
             ELSE '操作'
           END func_name,
           a.car_no,
           b.reso_code,
           b.reso_name,
           SUM(a.amt) amt,  -- 按维度汇总金额
           NOW() load_tm   -- 加载时间戳
      FROM ods_subj_acco a
      -- 关联科目资源映射表，按生效/截止时间范围匹配当月有效映射
      LEFT JOIN abc_rel_subj_reso b
        ON a.subj_code = b.subj_code
       AND DATE_FORMAT(b.fm_dt, '%Y%m') <= v_yyyymm
       AND DATE_FORMAT(b.to_dt, '%Y%m') >= v_yyyymm
      -- 关联机构维表，获取机构类型和名称，按拉链表有效期匹配当月
      LEFT JOIN abc_dim_dept c
        ON a.dept_code = c.dept_code
       AND DATE_FORMAT(c.fm_tm, '%Y%m') <= v_yyyymm
       AND DATE_FORMAT(c.to_tm, '%Y%m') >= v_yyyymm
     WHERE a.month_code = v_yyyymm
     GROUP BY a.month_code,
              a.dept_code,
              c.dept_type,
              c.dept_type_name,
              CASE
                WHEN b.reso_code = 'ZY0301' THEN '1030'
                ELSE '5010'
              END,
              CASE
                WHEN b.reso_code = 'ZY0301' THEN '运输'
                ELSE '操作'
              END,
              a.car_no,
              b.reso_code,
              b.reso_name;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
