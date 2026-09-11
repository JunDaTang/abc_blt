-- ============================================================
-- 文件名: 6.2-动因数据脚本.sql
-- 说明: 配置动因逻辑表（ABC_REL_DRIV_LOGIC），定义各级分摊所需的动因计算规则
--       动因逻辑将"功能中心 + 作业 + 操作类型 + 线路级别 + 包装状态"等条件
--       与具体的动因代码关联起来，指导动因生成程序如何计算各维度的动因量
-- 执行顺序: 第4步（动因配置），在分摊规则（5.2）之后、动因执行（6.4）之前执行
-- ============================================================

USE abc_blt;


-- ============================================================
-- 第一部分：RR 阶段动因逻辑（driv_code=RR002）
-- RR002 = 收派票数，用于营业点公共资源在收件/派件功能间分摊
-- DEPT_TYPE=YYD（营业点），按收件/派件网点统计的票数作为分摊动因
-- ============================================================

-- 插入 RR 动因逻辑：RR002 收件票数，用于营业点（YYD）收件功能（1010）的资源分摊
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RR002', '收派票数', '1010', '收件', null, null, null, null, null, null, 'YYD', null, '按收件网点统计的票数', null);

-- 插入 RR 动因逻辑：RR002 派件票数，用于营业点（YYD）派件功能（1020）的资源分摊
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RR002', '收派票数', '1020', '派件', null, null, null, null, null, null, 'YYD', null, '按派件网点统计的票数', null);


-- ============================================================
-- 第二部分：RA 阶段动因逻辑
-- RA002 = 车辆运行的线路类型里程，区分支线/干线、中转场/营业点
-- RA003 = 装卸中转票数，带系数（RT），中转系数1.5 > 装卸系数1
-- ============================================================

-- 插入 RA 动因逻辑：RA002 支线里程，中转场（ZZC）运输功能（1030），支线作业（201000），线路级别=20
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA002', '车辆运行的线路类型里程', '1030', '运输', '201000', '支线', null, '20', null, null, 'ZZC', null, '车辆行使的支线里程', null);

-- 插入 RA 动因逻辑：RA002 干线里程，中转场（ZZC）干线作业（202000），线路级别=10
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA002', '车辆运行的线路类型里程', '1030', '运输', '202000', '干线', null, '10', null, null, 'ZZC', null, '车辆行使的干线里程', null);

-- 插入 RA 动因逻辑：RA002 支线里程，营业点（YYD）支线作业（201000）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA002', '车辆运行的线路类型里程', '1030', '运输', '201000', '支线', null, '20', null, null, 'YYD', null, '车辆行使的支线里程', null);

-- 插入 RA 动因逻辑：RA002 干线里程，营业点（YYD）干线作业（202000）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA002', '车辆运行的线路类型里程', '1030', '运输', '202000', '干线', null, '10', null, null, 'YYD', null, '车辆行使的干线里程', null);

-- 插入 RA 动因逻辑：RA003 装卸中转票数，中转场装卸作业（301000），RT=1（装卸系数）
-- OP_CODE=30/31 区分不同操作子类型
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA003', '装卸中转票数', '1050', '操作', '301000', '装卸', '30', null, null, 1, 'ZZC', null, '装卸和中转相乘系数的票数', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA003', '装卸中转票数', '1050', '操作', '301000', '装卸', '31', null, null, 1, 'ZZC', null, '装卸和中转相乘系数的票数', null);

-- 插入 RA 动因逻辑：RA003 中转票数，中转场中转作业（302000），RT=1.5（中转系数更高，工作量更大）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA003', '装卸中转票数', '1050', '操作', '302000', '中转', '30', null, null, 1.5, 'ZZC', null, '装卸和中转相乘系数的票数', null);


-- ============================================================
-- 第三部分：AA 阶段动因逻辑
-- AA002 = 车辆装载重量的正常闲置，将运输成本按装载状态拆分
-- AA003 = 整包单件装卸票数，将装卸成本按包装形式拆分
-- AA004 = 整包单件中转票数，将中转成本按包装形式拆分
-- PKG_STATE: 1=整包, 0=单件
-- ============================================================

-- 插入 AA 动因逻辑：AA002 车辆装载重量，支线正常（201010）/支线闲置（201020）
-- 区分营业点（YYD）和中转场（ZZC）两种机构类型
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '201010', '支线正常', null, '20', null, null, 'ZZC', null, '车辆的正常和闲置重量', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '201020', '支线闲置', null, '20', null, null, 'ZZC', null, '车辆的正常和闲置重量', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '202010', '干线正常', null, '10', null, null, 'ZZC', null, '车辆的正常和闲置重量', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '202020', '干线闲置', null, '10', null, null, 'ZZC', null, '车辆的正常和闲置重量', null);

-- 营业点（YYD）的 AA002 动因逻辑，与中转场结构相同
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '201010', '支线正常', null, '20', null, null, 'YYD', null, '车辆的正常和闲置重量', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '201020', '支线闲置', null, '20', null, null, 'YYD', null, '车辆的正常和闲置重量', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '202010', '干线正常', null, '10', null, null, 'YYD', null, '车辆的正常和闲置重量', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA002', '车辆装载重量的正常闲置', '1030', '运输', '202020', '干线闲置', null, '10', null, null, 'YYD', null, '车辆的正常和闲置重量', null);

-- 插入 AA 动因逻辑：AA003 整包单件装卸票数，PKG_STATE=1 为整包，0 为单件
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA003', '整包单件装卸票数', '1050', '操作', '301010', '整包装卸', null, null, '1', null, 'ZZC', null, '整包单件装卸票数', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA003', '整包单件装卸票数', '1050', '操作', '301020', '单件装卸', null, null, '0', null, 'ZZC', null, '整包单件装卸票数', null);

-- 插入 AA 动因逻辑：AA004 整包单件中转票数
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA004', '整包单件中转票数', '1050', '操作', '302010', '整包中转', '30', null, '1', null, 'ZZC', null, '整包单件中转票数', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA004', '整包单件中转票数', '1050', '操作', '302020', '单件中转', '30', null, '0', null, 'ZZC', null, '整包单件中转票数', null);


-- ============================================================
-- 第四部分：AO 阶段动因逻辑
-- AO 阶段直接将作业成本按运单数分摊到每件运单
-- AO002 = 收件运单（收件作业按运单数分摊）
-- AO003 = 派件运单（派件作业按运单数分摊）
-- AO004 = 收派运单（管理作业按运单数分摊）
-- AO005 = 车辆运输的运单（运输作业按运单数分摊）
-- AO006~AO010 = 操作环节的整包/单件装卸/中转运单
-- ============================================================

-- 插入 AO 动因逻辑：AO002 收件运单，收件作业（101010）按运单分摊
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO002', '收件运单', '1010', '收件', '101010', '收件作业', null, null, null, null, 'YYD', null, '收件运单', null);

-- 插入 AO 动因逻辑：AO003 派件运单，派件作业（101020）按运单分摊
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO003', '派件运单', '1020', '派件', '101020', '派件作业', null, null, null, null, 'YYD', null, '派件运单', null);

-- 插入 AO 动因逻辑：AO004 收派运单，管理支持作业（101040）按运单分摊
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO004', '收派运单', '1040', '管理', '101040', '管理支持', null, null, null, null, 'YYD', null, '收派运单', null);

-- 插入 AO 动因逻辑：AO005 车辆运输的运单
-- 按线路级别（LINE_LEVE）和装载状态（正常/闲置）组合，覆盖所有运输场景
-- 中转场（ZZC）：支线正常/闲置 + 干线正常/闲置
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '201010', '支线正常', null, '20', null, null, 'ZZC', null, '车辆运输的运单', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '201020', '支线闲置', null, '20', null, null, 'ZZC', null, '车辆运输的运单', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '202010', '干线正常', null, '10', null, null, 'ZZC', null, '车辆运输的运单', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '202020', '干线闲置', null, '10', null, null, 'ZZC', null, '车辆运输的运单', null);

-- 营业点（YYD）的 AO005 动因逻辑，与中转场结构相同
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '201010', '支线正常', null, '20', null, null, 'YYD', null, '车辆运输的运单', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '201020', '支线闲置', null, '20', null, null, 'YYD', null, '车辆运输的运单', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '202010', '干线正常', null, '10', null, null, 'YYD', null, '车辆运输的运单', null);

insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO005', '车辆运输的运单', '1030', '运输', '202020', '干线闲置', null, '10', null, null, 'YYD', null, '车辆运输的运单', null);

-- 插入 AO 动因逻辑：AO006~AO009 操作环节的装卸/中转运单
-- AO006 整包装卸的运单（PKG_STATE=1）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO006', '整包装卸的运单', '1050', '操作', '301010', '整包装卸', null, null, '1', null, 'ZZC', null, '整包装卸的运单', null);

-- AO007 单件装卸的运单（PKG_STATE=0）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO007', '单件装卸的运单', '1050', '操作', '301020', '单件装卸', null, null, '0', null, 'ZZC', null, '单件装卸的运单', null);

-- AO008 整包中转的运单（PKG_STATE=1）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO008', '整包中转的运单', '1050', '操作', '302010', '整包中转', '30', null, '1', null, 'ZZC', null, '整包中转的运单', null);

-- AO009 单件中转的运单（PKG_STATE=0）
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO009', '单件中转的运单', '1050', '操作', '302020', '单件中转', '30', null, '0', null, 'ZZC', null, '单件中转的运单', null);

-- AO010 收件电商产品运单（PROD_CODE=P002），电商产品的收件作业单独分摊
insert into ABC_REL_DRIV_LOGIC (FM_TM, TO_TM, DRIV_CODE, DRIV_NAME, FUNC_CODE, FUNC_NAME, ACTI_CODE, ACTI_NAME, OP_CODE, LINE_LEVE, PKG_STATE, RT, DEPT_TYPE, PROD_CODE, REMARK, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO010', '收件电商产品运单', '1050', '操作', '101010', '收件作业', null, null, null, null, 'YYD', 'P002', '收件电商产品运单', null);


