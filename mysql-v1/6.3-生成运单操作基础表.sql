-- ============================================================
-- 存储过程: p_abc_bsl_op_waybill
-- 功能: 根据运单信息生成运单操作基础表和线路主数据
--       1) 逐日遍历运单，为每个运单分配装车(30)/卸车(31)操作及车牌
--          - 同城运单不生成操作记录
--          - 异地运单生成收端装车、派端卸车、中转装车三条操作记录
--          - 车牌从科目余额表(ods_subj_acco)中随机匹配
--          - 随机标记包裹状态(is_pkg)
--       2) 汇总生成线路维表，根据线路代码格式区分：
--          - 包含两段'W'的线路(如"城市W城市W")为干线(20)，里程100-300km
--          - 其他为短驳(10)，里程20-50km
-- 输入参数: p_fm_dt - 起始日期，p_to_dt - 截止日期
-- 输入表: abc_bsl_waybill（运单信息）、ods_subj_acco（科目余额表，获取车牌信息）
-- 输出表: abc_bsl_op_waybill（运单操作基础表）、abc_dim_line（线路维表）
-- 执行顺序: 第4步-运单操作数据生成，在基础数据准备之后、动因计算之前
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成运单操作基础表
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-15  生成运单操作基础表
-- 改造说明: for...in 游标 → DECLARE CURSOR + OPEN/FETCH/CLOSE

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
  DECLARE v_month   VARCHAR(10);
  DECLARE v_pkg     INT;
  
  -- 初始化变量：参数为空则取当前日期，计算月份范围
  IF p_fm_dt IS NULL THEN SET p_fm_dt = NOW(); END IF;
  IF p_to_dt IS NULL THEN SET p_to_dt = NOW(); END IF;
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_bsl_op_waybill';
  SET v_fm_date   = DATE_FORMAT(p_fm_dt, '%Y-%m-01');
  SET v_to_date   = DATE_FORMAT(p_to_dt, '%Y-%m-01');
  SET v_month     = DATE_FORMAT(v_fm_date, '%Y%m');
  SET v_pkg       = 0;

  -- 清理当月运单操作数据和线路维表数据，保证幂等重跑
  SET v_sqlstate = '删除数据';
  DELETE FROM abc_bsl_op_waybill a WHERE a.op_dt >= v_fm_date AND a.op_dt <= v_to_date;
  DELETE FROM abc_dim_line a WHERE a.month_code = v_month;

  -- 逐日遍历运单，为每个运单生成装车/卸车操作记录
  WHILE v_fm_date <= v_to_date DO
    BEGIN
      DECLARE done_waybill INT DEFAULT 0;
      DECLARE v_waybill_no VARCHAR(100);
      DECLARE v_rec_dt DATE;
      DECLARE v_rec_dept VARCHAR(50);
      DECLARE v_send_dept VARCHAR(50);
      DECLARE v_rec_city VARCHAR(50);
      DECLARE v_send_city VARCHAR(50);
      DECLARE v_wt INT;
      -- 游标：获取当天所有运单的基本信息
      DECLARE cur_waybill CURSOR FOR
        SELECT waybill_no, rec_dt, rec_dept, send_dept, rec_city, send_city, wt
          FROM abc_bsl_waybill a WHERE a.rec_dt = v_fm_date;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_waybill = 1;

      OPEN cur_waybill;
      waybill_loop: LOOP
        FETCH cur_waybill INTO v_waybill_no, v_rec_dt, v_rec_dept, v_send_dept, v_rec_city, v_send_city, v_wt;
        IF done_waybill THEN LEAVE waybill_loop; END IF;

        -- 随机生成包裹状态(0或1)，用于后续AA/AO动因按包裹状态分摊
        SET v_pkg = MOD(FLOOR(RAND() * 10), 2);

        -- 异地运单：收派城市不同，需要生成收端装车和派端卸车操作
        IF v_rec_city <> v_send_city THEN
          -- 收端装车操作(op_code='30')：从科目余额表中随机匹配一辆收端机构的车牌
          -- 线路代码格式：收端机构+收端城市+'W'（如"ABC上海W"）
          BEGIN
            DECLARE done_car1 INT DEFAULT 0;
            DECLARE v_car_no1 VARCHAR(50);
            DECLARE cur_car1 CURSOR FOR
              SELECT t.car_no FROM (SELECT car_no, dept_code,
                     ROW_NUMBER() OVER(ORDER BY RAND()) rn FROM ods_subj_acco b
                     WHERE b.month_code = DATE_FORMAT(v_fm_date, '%Y%m')
                       AND b.dept_code = v_rec_dept AND b.car_no IS NOT NULL) t WHERE t.rn = 1;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_car1 = 1;
            OPEN cur_car1;
            FETCH cur_car1 INTO v_car_no1;
            IF NOT done_car1 THEN
              -- 插入收端装车记录：操作日期、收端机构、操作代码30=装车、运单号、车牌、线路代码、包裹状态、重量
              INSERT INTO abc_bsl_op_waybill VALUES (v_fm_date, v_rec_dept, '30', '装车',
                v_waybill_no, v_car_no1, CONCAT(v_rec_dept, v_rec_city, 'W'), v_pkg, v_wt, NOW());
            END IF;
            CLOSE cur_car1;
          END;
          COMMIT;

          -- 派端卸车操作(op_code='31')：从科目余额表中随机匹配一辆派端机构的车牌
          -- 线路代码格式：派端城市+'W'+派端机构（如"上海WABC"）
          BEGIN
            DECLARE done_car2 INT DEFAULT 0;
            DECLARE v_car_no2 VARCHAR(50);
            DECLARE cur_car2 CURSOR FOR
              SELECT t.car_no FROM (SELECT car_no, dept_code,
                     ROW_NUMBER() OVER(ORDER BY RAND()) rn FROM ods_subj_acco b
                     WHERE b.month_code = DATE_FORMAT(v_fm_date, '%Y%m')
                       AND b.dept_code = v_send_dept AND b.car_no IS NOT NULL) t WHERE t.rn = 1;
            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_car2 = 1;
            OPEN cur_car2;
            FETCH cur_car2 INTO v_car_no2;
            IF NOT done_car2 THEN
              -- 插入派端卸车记录
              INSERT INTO abc_bsl_op_waybill VALUES (v_fm_date, v_send_dept, '31', '卸车',
                v_waybill_no, v_car_no2, CONCAT(v_send_city, 'W', v_send_dept), v_pkg, v_wt, NOW());
            END IF;
            CLOSE cur_car2;
          END;
          COMMIT;
        END IF;

        -- 中转装车操作：从科目余额表中匹配目的城市方向的中转车辆
        -- 匹配条件：机构代码前3位=目的城市、机构代码以'W'结尾（中转站点）、有车牌
        -- 线路代码格式：收端城市+'W'+目的城市+'W'（如"上海W北京W"），含两段W表示干线
        BEGIN
          DECLARE done_car3 INT DEFAULT 0;
          DECLARE v_car_no3 VARCHAR(50);
          DECLARE v_car_dept3 VARCHAR(50);
          DECLARE cur_car3 CURSOR FOR
            SELECT t.car_no, t.dept_code FROM (SELECT car_no, dept_code,
                   ROW_NUMBER() OVER(ORDER BY RAND()) rn FROM ods_subj_acco b
                   WHERE b.month_code = DATE_FORMAT(v_fm_date, '%Y%m')
                     AND SUBSTRING(b.dept_code, 1, 3) = v_send_city
                     AND b.dept_code LIKE '%W' AND b.car_no IS NOT NULL) t WHERE t.rn = 1;
          DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_car3 = 1;
          OPEN cur_car3;
          FETCH cur_car3 INTO v_car_no3, v_car_dept3;
          IF NOT done_car3 THEN
            -- 插入中转装车记录
            INSERT INTO abc_bsl_op_waybill VALUES (v_fm_date, v_car_dept3, '30', '装车',
              v_waybill_no, v_car_no3, CONCAT(v_rec_city, 'W', v_send_city, 'W'), v_pkg, v_wt, NOW());
          END IF;
          CLOSE cur_car3;
        END;
        COMMIT;
      END LOOP;
      CLOSE cur_waybill;
    END;
    -- 日期递增，处理下一天
    SET v_fm_date = DATE_ADD(v_fm_date, INTERVAL 1 DAY);
  END WHILE;

  -- 生成线路维表：汇总当月所有线路代码，根据线路类型计算里程
  -- 线路类型判断规则：
  --   线路代码含两段'W'(如"上海W北京W") → 干线(20)，里程=100+随机(0~200)km
  --   其他(如"ABC上海W") → 短驳(10)，里程=20+随机(0~30)km
  SET v_sqlstate = '生成线路主数据';
  INSERT INTO abc_dim_line
    SELECT t.month_code, t.line_code,
           CASE WHEN t.line_code LIKE '%W%W' THEN ROUND(t.main_km, 0) ELSE ROUND(t.bir_km, 0) END line_km,
           CASE WHEN t.line_code LIKE '%W%W' THEN '20' ELSE '10' END line_type,
           NOW() load_tm
      FROM (SELECT DATE_FORMAT(a.op_dt, '%Y%m') month_code, a.line_code,
                   20 + RAND() * 30 bir_km, 100 + RAND() * 200 main_km
              FROM abc_bsl_op_waybill a
             WHERE DATE_FORMAT(a.op_dt, '%Y%m') = v_month
             GROUP BY DATE_FORMAT(a.op_dt, '%Y%m'), a.line_code) t;
  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
