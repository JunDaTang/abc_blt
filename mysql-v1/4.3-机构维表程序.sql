-- ============================================================
-- 存储过程: p_abc_dim_dept
-- 功能: 生成机构维度表，使用递归展开机构层级树（公司→大区→业务区→分拨区→营业部），
--       采用拉链表设计（fm_tm/to_tm）跟踪机构层级变更历史
-- 输入参数:
--   p_dt      - 处理日期，默认当前日期
--   v_init_flg - 初始化标志：1=全量初始化（fm_tm从1993开始），0=增量更新（fm_tm为当月月初）
-- 输入表: ods_dept（ODS机构源表）、abc_dim_dept（目标维表，增量比对用）
-- 输出表: abc_dim_dept（机构维表，拉链表）、abc_dim_dept_tmp01/02/03（临时表）
-- 执行顺序: 第1步-基础数据准备（所有后续分摊的前提）
-- 改造说明: CONNECT BY + SYS_CONNECT_BY_PATH → WITH RECURSIVE
--           REGEXP_SUBSTR → SUBSTRING_INDEX 嵌套
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-05-04
-- purpose : 生成机构维表
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-05-04  生成机构维表

DROP PROCEDURE IF EXISTS p_abc_dim_dept;
DELIMITER //
CREATE PROCEDURE p_abc_dim_dept(IN p_dt DATE,
                                IN v_init_flg INT)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_rowcount  INT;
  DECLARE v_fm_date   DATE;
  DECLARE v_max_sgkey INT;
  
  -- 参数默认值处理：如果传入日期为空，则使用当前日期
  IF p_dt IS NULL THEN SET p_dt = NOW(); END IF;
  -- 状态追踪变量初始化
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'P_ABC_DIM_DEPT';
  -- 计算当月月初日期，用于拉链表生效时间
  SET v_fm_date   = DATE_FORMAT(p_dt, '%Y-%m-01');

  -- 步骤1: 清空临时表，准备中间数据容器
  SET v_sqlstate = '清空临时表';
  TRUNCATE TABLE ABC_DIM_DEPT_TMP01;
  TRUNCATE TABLE ABC_DIM_DEPT_TMP02;
  TRUNCATE TABLE ABC_DIM_DEPT_TMP03;

  -- 步骤2: 全量初始化时清空目标维表，确保从干净状态开始
  SET v_sqlstate = '初始化删除数据';
  IF v_init_flg = 1 THEN
    DELETE FROM abc_dim_dept;
  END IF;

  -- 步骤3: 递归展开机构层级树，构造带路径的完整机构树
  -- 用 WITH RECURSIVE 替代 CONNECT BY + SYS_CONNECT_BY_PATH
  -- code_path 格式如 @总公司@华南大区@深圳业务区@罗湖区@罗湖营业部@，用于后续逐级提取各层级
  SET v_sqlstate = '构造ASU层级路径';
  INSERT INTO abc_dim_dept_tmp01
  WITH RECURSIVE dept_tree AS (
    -- 根节点：顶级公司，无上级机构（parent_code 为空）
    SELECT dept_code,
           dept_name,
           dept_type,
           dept_type_name,
           parent_code,
           city_code,
           1 AS type_level,
           CAST(CONCAT('@', dept_code, '@') AS CHAR(1000)) AS code_path,
           CAST(CONCAT('@', dept_name, '@') AS CHAR(1000)) AS name_path
      FROM ods_dept a
     WHERE parent_code IS NULL
    UNION ALL
    -- 递归子节点：逐层向下展开，每级拼接路径
    SELECT d.dept_code,
           d.dept_name,
           d.dept_type,
           d.dept_type_name,
           d.parent_code,
           d.city_code,
           dt.type_level + 1,
           CONCAT(dt.code_path, d.dept_code, '@'),
           CONCAT(dt.name_path, d.dept_name, '@')
      FROM ods_dept d
     INNER JOIN dept_tree dt ON d.parent_code = dt.dept_code
  )
  SELECT dept_code, dept_name, dept_type, dept_type_name,
         parent_code, city_code, type_level, code_path, name_path
    FROM dept_tree;

  -- 步骤4: 将路径展开为各层级字段（level1~level5）
  -- REGEXP_SUBSTR(code_path, '[^@]+', 1, N) → SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', N+1), '@', -1)
  -- 路径格式: @A@B@C@ → 第1段=A, 第2段=B, ...
  -- 如果某层级不足（路径较短），则用当前机构代码填充（保证宽表对齐）
  SET v_sqlstate = '展开层级路径';
  INSERT INTO abc_dim_dept_tmp02
    SELECT a.code_path,
           -- 当前层级
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', type_level + 1), '@', -1), '') dept_code,
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', type_level + 1), '@', -1), '') dept_name,
           -- 生效时间：全量初始化从1993-03-01开始，增量更新从当月月初开始
           CASE
             WHEN v_init_flg = 1 THEN
              DATE('1993-03-01')
             ELSE
              v_fm_date
           END fm_tm,
           -- 截止时间：9999-12-31 表示当前有效记录
           DATE('9999-12-31') to_tm,
           -- level1: 公司层（第1级），不足时用当前机构代码填充
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', 2), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', type_level + 1), '@', -1), '')) level1_code,
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', 2), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', type_level + 1), '@', -1), '')) level1_name,
           -- level2: 大区层（第2级）
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', 3), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', type_level + 1), '@', -1), '')) level2_code,
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', 3), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', type_level + 1), '@', -1), '')) level2_name,
           -- level3: 业务区层（第3级）
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', 4), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', type_level + 1), '@', -1), '')) level3_code,
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', 4), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', type_level + 1), '@', -1), '')) level3_name,
           -- level4: 分拨区层（第4级）
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', 5), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', type_level + 1), '@', -1), '')) level4_code,
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', 5), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', type_level + 1), '@', -1), '')) level4_name,
           -- level5: 营业部层（第5级）
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', 6), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(code_path, '@', type_level + 1), '@', -1), '')) level5_code,
           IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', 6), '@', -1),
                  IFNULL(SUBSTRING_INDEX(SUBSTRING_INDEX(name_path, '@', type_level + 1), '@', -1), '')) level5_name,
           dept_type,
           dept_type_name,
           parent_code,
           city_code,
           type_level
      FROM abc_dim_dept_tmp01 a;

  -- 步骤5: 获取当前维表最大主键，用于增量插入时生成新的自增ID
  SET v_sqlstate = '获取最大主键';
  SELECT IFNULL(MAX(dept_id), 0) INTO v_max_sgkey FROM abc_dim_dept;

  -- 步骤6: 增量比对，将新数据与现有维表匹配
  -- 已存在的记录复用原 dept_id（通过所有关键字段拼接比对）
  -- 新增记录分配新 dept_id（v_max_sgkey + 行号）
  -- 只与 to_tm='9999-12-31' 的当前有效记录比对
  INSERT INTO abc_dim_dept_tmp03
    SELECT IFNULL(b.dept_id,
               v_max_sgkey + ROW_NUMBER()
               OVER(PARTITION BY b.dept_id ORDER BY b.dept_id)) dept_id,
           a.dept_code,
           a.dept_name,
           a.dept_type,
           a.dept_type_name,
           a.fm_tm,
           a.to_tm,
           a.level1_code,
           a.level1_name,
           a.level2_code,
           a.level2_name,
           a.level3_code,
           a.level3_name,
           a.level4_code,
           a.level4_name,
           a.level5_code,
           a.level5_name,
           a.parent_code,
           a.city_code,
           a.type_level
      FROM abc_dim_dept_tmp02 a
      LEFT JOIN abc_dim_dept b
        ON CONCAT(a.dept_code, a.dept_name, a.dept_type, a.level1_code,
                  a.level1_name, a.level2_code, a.level2_name, a.level3_code,
                  a.level3_name, a.level4_code, a.level4_name, a.level5_code,
                  a.level5_name, a.parent_code) =
           CONCAT(b.dept_code, b.dept_name, b.dept_type, b.level1_code,
                  b.level1_name, b.level2_code, b.level2_name, b.level3_code,
                  b.level3_name, b.level4_code, b.level4_name, b.level5_code,
                  b.level5_name, b.parent_code)
       AND b.to_tm = DATE('9999-12-31');

  -- 步骤7: 拉链表处理 — 将发生变化的旧记录的 to_tm 截止为前一天
  -- 即旧版本失效，新版本即将插入
  SET v_sqlstate = '将变化记录的前一条ABC维表记录截止';
  UPDATE abc_dim_dept a
     SET a.to_tm = DATE_SUB(v_fm_date, INTERVAL 1 DAY), a.load_tm = NOW()
   WHERE a.to_tm = DATE('9999-12-31')
     AND a.dept_code IN (SELECT b.dept_code
                           FROM abc_dim_dept_tmp03 b
                          WHERE b.dept_id > v_max_sgkey);
  COMMIT;

  -- 步骤8: 插入新版本的机构维表记录（仅新增的机构或变更的机构）
  SET v_sqlstate = '插入新版本ABC维表记录';
  INSERT INTO abc_dim_dept
    (dept_id, dept_code, dept_name, dept_type, dept_type_name,
     fm_tm, to_tm, level1_code, level1_name, level2_code, level2_name,
     level3_code, level3_name, level4_code, level4_name,
     level5_code, level5_name, parent_code, city_code, type_level, load_tm)
    SELECT dept_id, dept_code, dept_name, dept_type, dept_type_name,
           fm_tm, to_tm, level1_code, level1_name, level2_code, level2_name,
           level3_code, level3_name, level4_code, level4_name,
           level5_code, level5_name, parent_code, city_code, type_level,
           NOW() load_tm
      FROM abc_dim_dept_tmp03 a
     WHERE a.dept_id > v_max_sgkey;
  COMMIT;

  -- 步骤9: 清理无效数据 — 删除生效时间大于截止时间的脏记录
  SET v_sqlstate = '删除ASU_DEPT无效数据';
  DELETE FROM abc_dim_dept a WHERE a.fm_tm > a.to_tm;
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
