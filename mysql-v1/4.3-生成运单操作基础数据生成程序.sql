-- ============================================================
-- 存储过程: p_abc_bsl_op_waybill
-- 功能: 根据运单信息生成运单操作记录，为每个运单分配收端装车、派端卸车、中转等操作环节，
--       并关联对应车牌信息，用于支撑操作环节的成本分摊
-- 输入参数:
--   p_fm_dt - 起始日期，默认当前日期
--   p_to_dt - 结束日期，默认当前日期
-- 输入表: abc_bsl_waybill（运单信息）、ods_subj_acco（获取车牌信息）
-- 输出表: abc_bsl_op_waybill（运单操作基础表）
-- 执行顺序: 第3步-业务数据准备（依赖运单信息和科目余额，为AO分摊提供操作环节数据）
-- 改造说明: for...in 游标 → DECLARE CURSOR + OPEN/FETCH/CLOSE
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成运单操作基础数据
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-15  生成运单操作基础数据

DROP PROCEDURE IF EXISTS p_abc_bsl_op_waybill;
DELIMITER //
CREATE PROCEDURE p_abc_bsl_op_waybill(IN p_fm_dt DATE,
                                      IN p_to_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_rowcount  INT;
  DECLARE v_fm_date DATE;
  DECLARE v_to_date DATE;
  DECLARE v_pkg     INT;
  
  -- 参数默认值处理
  IF p_fm_dt IS NULL THEN SET p_fm_dt = NOW(); END IF;
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  -- 状态追踪变量初始化
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_bsl_op_waybill';
  SET v_fm_date   = DATE(p_fm_dt);
  SET v_to_date   = DATE(p_to_dt);
  SET v_pkg       = 0;

  -- 步骤1: 删除日期范围内的已有操作记录，确保幂等性
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_bsl_op_waybill a
   WHERE a.op_dt >= v_fm_date
     AND a.op_dt <= v_to_date;

  -- 步骤2: 按日期逐日处理，为每天每条运单生成操作环节记录
  WHILE v_fm_date <= v_to_date DO
    -- 运单游标：查询当天所有运单信息
    BEGIN
      DECLARE done_waybill INT DEFAULT 0;
      DECLARE v_waybill_no VARCHAR(100);
      DECLARE v_rec_dt DATE;
      DECLARE v_rec_dept VARCHAR(50);
      DECLARE v_send_dept VARCHAR(50);
      DECLARE v_rec_city VARCHAR(50);
      DECLARE v_send_city VARCHAR(50);
      DECLARE v_wt INT;
      DECLARE cur_waybill CURSOR FOR
        SELECT waybill_no, rec_dt, rec_dept, send_dept, rec_city, send_city, wt
          FROM abc_bsl_waybill a WHERE a.rec_dt = v_fm_date;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_waybill = 1;

      OPEN cur_waybill;
      waybill_loop: LOOP
        FETCH cur_waybill INTO v_waybill_no, v_rec_dt, v_rec_dept, v_send_dept, v_rec_city, v_send_city, v_wt;
        IF done_waybill THEN LEAVE waybill_loop; END IF;

        -- 随机生成件数（0或1），模拟散件/多件场景
        SET v_pkg = MOD(FLOOR(RAND() * 10), 2);

        -- 同城运单不生成操作记录，仅异地运单需要装车/卸车/中转
        IF v_rec_city <> v_send_city THEN
          -- 步骤3: 生成收端装车记录（op_code='30'，装车）
          -- 从当月该营业部的科目余额中随机取一辆车作为装车车辆
          BEGIN
            DECLARE done_car1 INT DEFAULT 0;
            DECLARE v_car_no1 VARCHAR(50);
            DECLARE cur_car1 CURSOR FOR
              SELECT t.car_no
                FROM (SELECT car_no, dept_code,
                             ROW_NUMBER() OVER(ORDER BY RAND()) rn
                        FROM ods_subj_acco b
                       WHERE b.month_code = DATE_FORMAT(v_fm_date, '%Y%m')
                         AND b.dept_code = v_rec_dept
                         AND b.car_no IS NOT NULL) t
               WHERE t.rn = 1;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_car1 = 1;

            OPEN cur_car1;
            FETCH cur_car1 INTO v_car_no1;
            IF NOT done_car1 THEN
              INSERT INTO abc_bsl_op_waybill
              VALUES (v_fm_date, v_rec_dept, '30', '装车',
                      v_waybill_no, v_car_no1,
                      CONCAT(v_rec_dept, v_rec_city, 'W'),
                      v_pkg, v_wt, NOW());
            END IF;
            CLOSE cur_car1;
          END;
          COMMIT;

          -- 步骤4: 生成派端卸车记录（op_code='31'，卸车）
          -- 从当月该派端营业部的科目余额中随机取一辆车作为卸车车辆
          BEGIN
            DECLARE done_car2 INT DEFAULT 0;
            DECLARE v_car_no2 VARCHAR(50);
            DECLARE cur_car2 CURSOR FOR
              SELECT t.car_no
                FROM (SELECT car_no, dept_code,
                             ROW_NUMBER() OVER(ORDER BY RAND()) rn
                        FROM ods_subj_acco b
                       WHERE b.month_code = DATE_FORMAT(v_fm_date, '%Y%m')
                         AND b.dept_code = v_send_dept
                         AND b.car_no IS NOT NULL) t
               WHERE t.rn = 1;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_car2 = 1;

            OPEN cur_car2;
            FETCH cur_car2 INTO v_car_no2;
            IF NOT done_car2 THEN
              INSERT INTO abc_bsl_op_waybill
              VALUES (v_fm_date, v_send_dept, '31', '卸车',
                      v_waybill_no, v_car_no2,
                      CONCAT(v_rec_city, 'W', v_send_dept),
                      v_pkg, v_wt, NOW());
            END IF;
            CLOSE cur_car2;
          END;
          COMMIT;
        END IF;

        -- 步骤5: 生成中转装车记录（无论同城/异地都尝试生成）
        -- 从派端城市中以'W'结尾的机构中随机取车辆，模拟中转环节
        BEGIN
          DECLARE done_car3 INT DEFAULT 0;
          DECLARE v_car_no3 VARCHAR(50);
          DECLARE v_car_dept3 VARCHAR(50);
          DECLARE cur_car3 CURSOR FOR
            SELECT t.car_no, t.dept_code
              FROM (SELECT car_no, dept_code,
                           ROW_NUMBER() OVER(ORDER BY RAND()) rn
                      FROM ods_subj_acco b
                     WHERE b.month_code = DATE_FORMAT(v_fm_date, '%Y%m')
                       AND SUBSTRING(b.dept_code, 1, 3) = v_send_city
                       AND b.dept_code LIKE '%W'
                       AND b.car_no IS NOT NULL) t
             WHERE t.rn = 1;
          DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_car3 = 1;

          OPEN cur_car3;
          FETCH cur_car3 INTO v_car_no3, v_car_dept3;
          IF NOT done_car3 THEN
            INSERT INTO abc_bsl_op_waybill
            VALUES (v_fm_date, v_car_dept3, '30', '装车',
                    v_waybill_no, v_car_no3,
                    CONCAT(v_rec_city, 'W', v_rec_city, 'W'),
                    v_pkg, v_wt, NOW());
          END IF;
          CLOSE cur_car3;
        END;
        COMMIT;

      END LOOP;
      CLOSE cur_waybill;
    END;

    SET v_fm_date = DATE_ADD(v_fm_date, INTERVAL 1 DAY);
  END WHILE;
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
