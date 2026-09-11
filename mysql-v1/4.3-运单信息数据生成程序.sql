-- ============================================================
-- 存储过程: p_abc_data_waybill
-- 功能: 模拟生成运单信息数据，按日期范围逐日生成随机运单，
--       包含收派端营业部、产品、重量、收入等信息
-- 输入参数:
--   p_fm_dt - 起始日期，默认当前日期
--   p_to_dt - 结束日期，默认当前日期
-- 输入表: abc_dim_dept（机构维表，随机选取营业部）、abc_rel_prod（产品关系表）
-- 输出表: abc_bsl_waybill（运单信息表）
-- 执行顺序: 第2步-业务数据准备（依赖机构维表，为后续成本生成提供运单基础）
-- 改造说明: for...in 嵌套游标 → DECLARE CURSOR + OPEN/FETCH/CLOSE
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成运单信息
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-15  生成运单信息

DROP PROCEDURE IF EXISTS p_abc_data_waybill;
DELIMITER //
CREATE PROCEDURE p_abc_data_waybill(IN p_fm_dt DATE,
                                    IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_rowcount  INT;
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_cnt     INT;
  DECLARE v_wt      INT;
  DECLARE v_rd      INT;
  
  -- 参数默认值处理
  IF p_fm_dt IS NULL THEN SET p_fm_dt = NOW(); END IF;
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  -- 状态追踪变量初始化
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_data_waybill';
  SET v_fm_date   = DATE(p_fm_dt);
  SET v_to_date   = DATE(p_to_dt);
  SET v_cnt       = 0;
  SET v_wt        = 0;
  SET v_rd        = 0;

  -- 按日期范围逐日生成运单数据
  WHILE v_fm_date <= v_to_date DO
    -- 步骤1: 删除当天已有的运单数据，确保幂等性
    SET v_sqlstate = '删除当天已收集运单信息';
    DELETE FROM abc_bsl_waybill a WHERE a.rec_dt = v_fm_date;
    -- 每天生成 50~150 条随机运单
    SET v_cnt = 50 + ROUND(RAND() * 100, 0);

    -- 步骤2: 逐条生成运单，循环直到当日运单数用完
    SET v_sqlstate = '生成运单号';
    WHILE v_cnt >= 0 DO
      -- 随机生成重量（0~100kg）和随机偏移量（用于计算到达日期、客户编码等）
      SET v_wt = ROUND(RAND() * 100, 0);
      SET v_rd = ROUND(RAND() * 1000, 0);

      -- 第一层游标: 随机选取一个营业部作为收端（dept_type='YYD' 表示营业部）
      BEGIN
        DECLARE done_dept1 INT DEFAULT 0;
        DECLARE v_dept1_code VARCHAR(50);
        DECLARE v_dept1_city VARCHAR(50);
        DECLARE cur_dept1 CURSOR FOR
          SELECT dept_code, city_code
            FROM (SELECT dept_code, city_code,
                         ROW_NUMBER() OVER(ORDER BY RAND()) rn
                    FROM abc_dim_dept a WHERE a.dept_type = 'YYD') t
           WHERE t.rn = 1;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_dept1 = 1;

        OPEN cur_dept1;
        FETCH cur_dept1 INTO v_dept1_code, v_dept1_city;
        IF NOT done_dept1 THEN

          -- 第二层游标: 随机选取一个营业部作为派端
      BEGIN
            DECLARE done_dept2 INT DEFAULT 0;
            DECLARE v_dept2_code VARCHAR(50);
            DECLARE v_dept2_city VARCHAR(50);
            DECLARE cur_dept2 CURSOR FOR
              SELECT dept_code, city_code
                FROM (SELECT dept_code, city_code,
                             ROW_NUMBER() OVER(ORDER BY RAND()) rn
                        FROM abc_dim_dept a WHERE a.dept_type = 'YYD') t
               WHERE t.rn = 1;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_dept2 = 1;

            OPEN cur_dept2;
            FETCH cur_dept2 INTO v_dept2_code, v_dept2_city;
            IF NOT done_dept2 THEN

              -- 第三层游标: 随机选取一个产品（快运/快递等），获取首重价格和续重单价
          BEGIN
                DECLARE done_prod INT DEFAULT 0;
                DECLARE v_prod_code VARCHAR(50);
                DECLARE v_prod_name VARCHAR(100);
                DECLARE v_first_pric DECIMAL(18,2);
                DECLARE v_add_pric DECIMAL(18,2);
                DECLARE cur_prod CURSOR FOR
                  SELECT prod_code, prod_name, first_pric, add_pric
                    FROM (SELECT prod_code, prod_name, first_pric, add_pric,
                                 ROW_NUMBER() OVER(ORDER BY RAND()) rn
                            FROM abc_rel_prod) t
                   WHERE t.rn = 1;
                DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_prod = 1;

                OPEN cur_prod;
                FETCH cur_prod INTO v_prod_code, v_prod_name, v_first_pric, v_add_pric;
                IF NOT done_prod THEN
                  -- 组装运单记录并插入运单信息表
                -- 运单号格式: YYYYMMDD + 3位序号（如 20190615001）
                -- 到达日期: 收件日期 + 随机0~4天
                -- 客户编码: C10 + 随机数（模拟客户代码）
                -- 收入: 首重价格 + 续重单价 ×（重量-1），即阶梯计价模型
                INSERT INTO abc_bsl_waybill
                  VALUES
                    (CONCAT(DATE_FORMAT(v_fm_date, '%Y%m%d'), LPAD(v_cnt, 3, '0')),
                     v_fm_date,
                     DATE_ADD(v_fm_date, INTERVAL MOD(v_rd, 5) DAY),
                     CONCAT('C10', MOD(v_rd, 9)),
                     v_dept1_code,
                     v_dept2_code,
                     v_dept1_city,
                     v_dept2_city,
                     v_prod_code,
                     v_prod_name,
                     v_wt,
                     v_first_pric + v_add_pric * (v_wt - 1),
                     NOW());
                END IF;
                CLOSE cur_prod;
              END;

            END IF;
            CLOSE cur_dept2;
          END;

        END IF;
        CLOSE cur_dept1;
      END;

      SET v_cnt = v_cnt - 1;
    END WHILE;

    SET v_fm_date = DATE_ADD(v_fm_date, INTERVAL 1 DAY);
  END WHILE;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
