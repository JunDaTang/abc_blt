-- ============================================================
-- 存储过程: p_abc_data_subj_acco
-- 功能: 根据运单信息生成模拟的财务成本数据，按科目资源映射关系，
--       为每个运单在各机构（收端、派端、中转、总部）生成人工、运输、设备、物料等成本记录
-- 输入参数:
--   p_fm_dt - 处理日期，默认当前日期
-- 输入表: abc_bsl_waybill（运单信息）、abc_rel_subj_reso（科目资源映射）、abc_dim_dept（机构维表）
-- 输出表: ods_subj_acco（ODS科目余额接口表）
-- 执行顺序: 第2步-业务数据准备（依赖运单信息，为资源清单和后续分摊提供源数据）
-- 改造说明: for...in 多层嵌套游标 → DECLARE CURSOR + OPEN/FETCH/CLOSE
-- ============================================================
-- MySQL 8.0 版本 (从 Oracle PL/SQL 转换)
-- author  : blt
-- created : 2019-06-15
-- purpose : 生成财务成本接口数据
-- version  modify  time        desc
-- -------  -----   ----------  -------------------------------
-- v1.0     blt     2019-06-15  生成财务成本接口数据

DROP PROCEDURE IF EXISTS p_abc_data_subj_acco;
DELIMITER //
CREATE PROCEDURE p_abc_data_subj_acco(IN p_fm_dt DATE)
BEGIN
  DECLARE v_sqlstate  VARCHAR(1000);
  DECLARE v_proc_name VARCHAR(300);
  DECLARE v_rowcount  INT;
  DECLARE v_yyyymm VARCHAR(1000);
  DECLARE v_cnt    INT;
  DECLARE v_pep    DECIMAL(18,4);
  DECLARE v_mng    DECIMAL(18,4);
  DECLARE v_div    DECIMAL(18,4);
  DECLARE v_mate   DECIMAL(18,4);
  DECLARE v_car    DECIMAL(18,4);
  DECLARE v_fot    DECIMAL(18,4);
  
  -- 参数默认值处理
  IF p_fm_dt IS NULL THEN SET p_fm_dt = NOW(); END IF;
  -- 状态追踪变量初始化
  SET v_sqlstate  = '变量赋值';
  SET v_proc_name = 'p_abc_data_subj_acco';
  SET v_yyyymm    = DATE_FORMAT(p_fm_dt, '%Y%m');  -- 月份编码，格式 YYYYMM
  SET v_cnt       = 0;

  -- 步骤1: 删除当月已有的接口数据，确保幂等性
  DELETE FROM ods_subj_acco a WHERE a.month_code = v_yyyymm;

  -- 步骤2: 开始逐运单、逐科目生成成本记录
  SET v_sqlstate = '生成接口数据';

  -- 运单游标：遍历所有运单，为每个运单在各机构生成成本记录
  BEGIN
    DECLARE done_waybill INT DEFAULT 0;
    DECLARE v_waybill_no VARCHAR(100);
    DECLARE v_rec_dept VARCHAR(50);
    DECLARE v_send_dept VARCHAR(50);
    DECLARE v_rec_city VARCHAR(50);
    DECLARE v_send_city VARCHAR(50);
    DECLARE v_amt DECIMAL(18,2);
    DECLARE v_prod_name VARCHAR(100);
    DECLARE cur_waybill CURSOR FOR
      SELECT waybill_no, rec_dept, send_dept, rec_city, send_city, amt, prod_name
        FROM abc_bsl_waybill;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_waybill = 1;

    OPEN cur_waybill;
    waybill_loop: LOOP
      FETCH cur_waybill INTO v_waybill_no, v_rec_dept, v_send_dept, v_rec_city, v_send_city, v_amt, v_prod_name;
      IF done_waybill THEN LEAVE waybill_loop; END IF;

      -- 为当前运单生成各类成本的随机比例系数
      SET v_sqlstate = '生成成本';
      SET v_pep  = RAND() * 5 / 3;   -- 人工及福利占比系数
      SET v_mng  = RAND() * 5 / 3;   -- 管理成本占比系数
      SET v_div  = RAND() * 5 / 2;   -- 设备折旧占比系数
      SET v_mate = RAND() * 3;       -- 物料费占比系数
      SET v_car  = RAND() * 5 / 2;   -- 运输费占比系数
      SET v_fot  = RAND() * 3;       -- 燃油附加费占比系数

      -- 科目资源映射游标：遍历所有科目，按资源类型分别生成不同成本记录
      BEGIN
        DECLARE done_sub INT DEFAULT 0;
        DECLARE v_subj_code VARCHAR(50);
        DECLARE v_subj_name VARCHAR(100);
        DECLARE v_reso_name VARCHAR(100);
        DECLARE cur_sub CURSOR FOR
          SELECT subj_code, subj_name, reso_name FROM abc_rel_subj_reso;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_sub = 1;

        OPEN cur_sub;
        sub_loop: LOOP
          FETCH cur_sub INTO v_subj_code, v_subj_name, v_reso_name;
          IF done_sub THEN LEAVE sub_loop; END IF;

          -- 人工及福利（reso_name='人工及福利'）：在收端、派端、总部、中转机构分别生成人工和管理成本
          IF v_reso_name = '人工及福利' THEN
            -- 收端营业部：生成人工成本和管理成本
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_rec_dept, v_subj_code, v_subj_name, '人工', NULL, v_amt * v_pep / 100, NOW());
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_rec_dept, v_subj_code, v_subj_name, '管理', NULL, v_amt * v_mng / 100, NOW());
            -- 派端营业部：生成人工成本和管理成本
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_send_dept, v_subj_code, v_subj_name, '人工', NULL, v_amt * v_pep / 100, NOW());
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_send_dept, v_subj_code, v_subj_name, '管理', NULL, v_amt * v_mng / 100, NOW());
            -- 总部（dept_code='100'）：生成管理成本
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, '100', v_subj_code, v_subj_name, '管理', NULL, v_amt * v_mng / 100, NOW());

            -- 营业部/分拨区/中转中心：在与收派城市匹配的非营业部机构生成管理成本和人工成本
            BEGIN
              DECLARE done_dept INT DEFAULT 0;
              DECLARE v_dept_code VARCHAR(50);
              DECLARE v_dept_city VARCHAR(50);
              DECLARE cur_dept CURSOR FOR
                SELECT dept_code, city_code
                  FROM abc_dim_dept a
                 WHERE DATE_FORMAT(a.fm_tm, '%Y%m') <= v_yyyymm
                   AND DATE_FORMAT(a.to_tm, '%Y%m') >= v_yyyymm
                   AND a.dept_type IN ('YYC', 'FBC', 'ZZC')
                   AND (a.city_code = v_rec_city OR a.city_code = v_send_city);
              DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_dept = 1;

              OPEN cur_dept;
              dept_loop: LOOP
                FETCH cur_dept INTO v_dept_code, v_dept_city;
                IF done_dept THEN LEAVE dept_loop; END IF;
                INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_dept_code, v_subj_code, v_subj_name, '管理', NULL, v_amt * v_mng / 100, NOW());
                INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_dept_code, v_subj_code, v_subj_name, '人工', NULL, v_amt * v_pep / 100, NOW());
              END LOOP;
              CLOSE cur_dept;
            END;
          END IF;

          -- 运输费（reso_name='运输费'）：在收端、派端、中转机构生成运输成本，并关联随机车牌号
          IF v_reso_name = '运输费' THEN
            -- 收端营业部：生成运输成本，车牌号格式为"城市代码-5位随机数"
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_rec_dept, v_subj_code, v_subj_name, NULL,
              CONCAT(v_rec_city, '-', LPAD(ROUND(RAND() * 5, 0), 5, '0')),
              v_amt * v_car / 100, NOW());
            -- 派端营业部：生成运输成本
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_send_dept, v_subj_code, v_subj_name, NULL,
              CONCAT(v_send_city, '-', LPAD(ROUND(RAND() * 5, 0), 5, '0')),
              v_amt * v_car / 100, NOW());

            -- 中转中心（dept_type='ZZC'）：生成中转运输成本
            BEGIN
              DECLARE done_dept2 INT DEFAULT 0;
              DECLARE v_dept_code2 VARCHAR(50);
              DECLARE v_dept_city2 VARCHAR(50);
              DECLARE cur_dept2 CURSOR FOR
                SELECT dept_code, city_code
                  FROM abc_dim_dept a
                 WHERE DATE_FORMAT(a.fm_tm, '%Y%m') <= v_yyyymm
                   AND DATE_FORMAT(a.to_tm, '%Y%m') >= v_yyyymm
                   AND a.dept_type = 'ZZC'
                   AND (a.city_code = v_rec_city OR a.city_code = v_send_city);
              DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_dept2 = 1;

              OPEN cur_dept2;
              dept_loop2: LOOP
                FETCH cur_dept2 INTO v_dept_code2, v_dept_city2;
                IF done_dept2 THEN LEAVE dept_loop2; END IF;
                INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_dept_code2, v_subj_code, v_subj_name, NULL,
                  CONCAT(v_dept_city2, '-', LPAD(ROUND(RAND() * 5, 0), 5, '0')),
                  v_amt * v_car / 100, NOW());
              END LOOP;
              CLOSE cur_dept2;
            END;
          END IF;

          -- 设备折旧（reso_name='设备折旧'）：在收端、派端、中转机构生成设备折旧成本
          IF v_reso_name = '设备折旧' THEN
            -- 收端营业部设备折旧
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_rec_dept, v_subj_code, v_subj_name, NULL, NULL, v_amt * v_div / 100, NOW());
            -- 派端营业部设备折旧
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_send_dept, v_subj_code, v_subj_name, NULL, NULL, v_amt * v_div / 100, NOW());

            -- 中转中心（dept_type='ZZC'）设备折旧
            BEGIN
              DECLARE done_dept3 INT DEFAULT 0;
              DECLARE v_dept_code3 VARCHAR(50);
              DECLARE cur_dept3 CURSOR FOR
                SELECT dept_code
                  FROM abc_dim_dept a
                 WHERE DATE_FORMAT(a.fm_tm, '%Y%m') <= v_yyyymm
                   AND DATE_FORMAT(a.to_tm, '%Y%m') >= v_yyyymm
                   AND a.dept_type = 'ZZC'
                   AND (a.city_code = v_rec_city OR a.city_code = v_send_city);
              DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_dept3 = 1;

              OPEN cur_dept3;
              dept_loop3: LOOP
                FETCH cur_dept3 INTO v_dept_code3;
                IF done_dept3 THEN LEAVE dept_loop3; END IF;
                INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_dept_code3, v_subj_code, v_subj_name, NULL, NULL, v_amt * v_div / 100, NOW());
              END LOOP;
              CLOSE cur_dept3;
            END;
          END IF;

          -- 物料费（reso_name='物料费'）：仅在收端营业部生成物料成本
          IF v_reso_name = '物料费' THEN
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_rec_dept, v_subj_code, v_subj_name, NULL, NULL, v_amt * v_mate / 100, NOW());
          END IF;

          -- 燃油附加费（reso_name='燃油附加费'）：仅快运产品在收端生成燃油附加费
          IF v_reso_name = '燃油附加费' AND v_prod_name = '快运' THEN
            INSERT INTO ods_subj_acco VALUES (v_yyyymm, v_rec_dept, v_subj_code, v_subj_name, NULL, NULL, v_amt * v_fot / 100, NOW());
          END IF;

        END LOOP;
        CLOSE cur_sub;
      END;

    END LOOP;
    CLOSE cur_waybill;
  END;

  COMMIT;
  SET v_sqlstate = '结束';

END;
//
DELIMITER ;
