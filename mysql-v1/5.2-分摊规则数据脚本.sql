-- ============================================================
-- 文件名: 5.2-分摊规则数据脚本.sql
-- 说明: 配置四级分摊模型的完整分摊规则，定义成本在每一级如何流转
--       1) ABC_REL_RR_DIST - RR分摊规则：共享资源在功能中心间分摊
--       2) ABC_REL_RA_DIST - RA分摊规则：资源成本分摊到作业
--       3) ABC_REL_AA_DIST - AA分摊规则：辅助作业间相互分摊
--       4) ABC_REL_AO_DIST - AO分摊规则：作业成本最终分摊到运单
-- 执行顺序: 第3步（规则配置），在基础数据（3.2/4.2）之后、动因数据（6.2）之前执行
-- ============================================================

USE abc_blt;


-- ============================================================
-- 第一部分：RR 分摊规则（ABC_REL_RR_DIST）
-- RR = Resource to Resource，共享资源在各功能中心间分摊
-- 场景：营业点的"公共"功能中心（func=5010）的资源，需要分摊到收件、派件等功能中心
-- 动因：RR002 = 按收派票数比例分摊
-- DIST_TYPE = RR01，表示 RR 分摊类型1
-- ============================================================

-- 插入 RR 分摊规则：营业点公共薪酬福利 → 按收派票数（RR002）分摊到收件功能
-- 含义：营业点公共区域（如经理室、行政）的人工成本，按收件/派件票数比例分摊
insert into abc_rel_rr_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RR01', 'RR002', '收派票数', 'YYD', '营业点', '5010', '公共', 'ZY0101', '薪酬福利', 'YYD', '营业点', '1010', '收件', 'ZY0101', '薪酬福利', null);

-- 插入 RR 分摊规则：营业点公共薪酬福利 → 按收派票数（RR002）分摊到派件功能
insert into abc_rel_rr_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RR01', 'RR002', '收派票数', 'YYD', '营业点', '5010', '公共', 'ZY0101', '薪酬福利', 'YYD', '营业点', '1020', '派件', 'ZY0101', '薪酬福利', null);

-- 插入 RR 分摊规则：营业点公共设备折旧 → 按收派票数（RR002）分摊到收件功能
-- 含义：营业点公共设备（如空调、电脑）的折旧费，按收件/派件票数比例分摊
insert into abc_rel_rr_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RR01', 'RR002', '收派票数', 'YYD', '营业点', '5010', '公共', 'ZY0201', '设备折旧', 'YYD', '营业点', '1010', '收件', 'ZY0201', '设备折旧', null);

-- 插入 RR 分摊规则：营业点公共设备折旧 → 按收派票数（RR002）分摊到派件功能
insert into abc_rel_rr_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RR01', 'RR002', '收派票数', 'YYD', '营业点', '5010', '公共', 'ZY0201', '设备折旧', 'YYD', '营业点', '1020', '派件', 'ZY0201', '设备折旧', null);







-- ============================================================
-- 第二部分：RA 分摊规则（ABC_REL_RA_DIST）
-- RA = Resource to Activity，资源成本分摊到作业
-- 分摊方式：
--   RA001 = 直接记入（资源直接归属到某功能的某作业，无需动因分摊）
--   RA002 = 按车辆运行的线路类型里程分摊
--   RA003 = 按装卸中转票数分摊
-- ============================================================

-- --- 营业点（YYD）：直接记入规则 ---
-- 收件薪酬福利 → 直接记入收件作业（101010），人工成本直接归属
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYD', '营业点', '1010', '收件', 'ZY0101', '薪酬福利', 'YYD', '营业点', '1010', '收件', 'ZY0101', '薪酬福利', '101010', '收件作业', null);

-- 派件薪酬福利 → 直接记入派件作业（101020）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYD', '营业点', '1020', '派件', 'ZY0101', '薪酬福利', 'YYD', '营业点', '1020', '派件', 'ZY0101', '薪酬福利', '101020', '派件作业', null);

-- 收件设备折旧 → 直接记入收件作业（101010）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYD', '营业点', '1010', '收件', 'ZY0201', '设备折旧', 'YYD', '营业点', '1010', '收件', 'ZY0201', '设备折旧', '101010', '收件作业', null);

-- 派件设备折旧 → 直接记入派件作业（101020）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYD', '营业点', '1020', '派件', 'ZY0201', '设备折旧', 'YYD', '营业点', '1020', '派件', 'ZY0201', '设备折旧', '101020', '派件作业', null);

-- 营业点公共物料费 → 直接记入收件作业（101010），物料费全部归入收件环节
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYD', '营业点', '5010', '公共', 'ZY0401', '物料费', 'YYD', '营业点', '1010', '收件', 'ZY0401', '物料费', '101010', '收件作业', null);

-- 营业点公共生鲜物料费 → 直接记入收件作业（101010），保鲜材料在收件环节使用
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYD', '营业点', '5010', '公共', 'ZY0402', '生鲜物料费', 'YYD', '营业点', '1010', '收件', 'ZY0402', '生鲜物料费', '101010', '收件作业', null);

-- --- 运输费按线路里程分摊（RA002）---
-- 营业点运输费 → 按线路里程（RA002）分摊到支线作业（201000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA002', '车辆运行的线路类型里程', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201000', '支线', null);

-- 营业点运输费 → 按线路里程（RA002）分摊到干线作业（202000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA002', '车辆运行的线路类型里程', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202000', '干线', null);

-- 中转场运输费 → 按线路里程（RA002）分摊到支线作业（201000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA002', '车辆运行的线路类型里程', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201000', '支线', null);

-- 中转场运输费 → 按线路里程（RA002）分摊到干线作业（202000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA002', '车辆运行的线路类型里程', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202000', '干线', null);

-- --- 管理层薪酬直接记入管理作业（RA001）---
-- 业务区（YYC）公共薪酬 → 直接记入管理支持作业（101040）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'YYC', '业务区', '5010', '公共', 'ZY0101', '薪酬福利', 'YYC', '业务区', '1040', '管理', 'ZY0101', '薪酬福利', '101040', '管理支持', null);

-- 分拨区（FBC）公共薪酬 → 直接记入管理支持作业（101040）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'FBC', '分拨区', '5010', '公共', 'ZY0101', '薪酬福利', 'FBC', '分拨区', '1040', '管理', 'ZY0101', '薪酬福利', '101040', '管理支持', null);

-- 总部（ZB）公共薪酬 → 直接记入管理支持作业（101040）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA001', '直接记入', 'ZB', '总部', '5010', '公共', 'ZY0101', '薪酬福利', 'ZB', '总部', '1040', '管理', 'ZY0101', '薪酬福利', '101040', '管理支持', null);

-- --- 中转场公共费用按装卸中转票数分摊（RA003）---
-- 中转场公共薪酬 → 按装卸中转票数（RA003）分摊到装卸作业（301000）
-- RT=1 表示装卸系数为1，中转系数为1.5
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA003', '装卸中转票数', 'ZZC', '中转场', '5010', '公共', 'ZY0101', '薪酬福利', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301000', '装卸', null);

-- 中转场公共薪酬 → 按装卸中转票数（RA003）分摊到中转作业（302000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA003', '装卸中转票数', 'ZZC', '中转场', '5010', '公共', 'ZY0101', '薪酬福利', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302000', '中转', null);

-- 中转场公共设备折旧 → 按装卸中转票数（RA003）分摊到装卸作业（301000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA003', '装卸中转票数', 'ZZC', '中转场', '5010', '公共', 'ZY0201', '设备折旧', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301000', '装卸', null);

-- 中转场公共设备折旧 → 按装卸中转票数（RA003）分摊到中转作业（302000）
insert into abc_rel_ra_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'RA01', 'RA003', '装卸中转票数', 'ZZC', '中转场', '5010', '公共', 'ZY0201', '设备折旧', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302000', '中转', null);







-- ============================================================
-- 第三部分：AA 分摊规则（ABC_REL_AA_DIST）
-- AA = Activity to Activity，辅助作业间相互分摊
-- 场景：运输作业的"支线"成本需进一步细分为"支线正常"和"支线闲置"
--       操作作业的"装卸"成本需进一步细分为"整包装卸"和"单件装卸"
-- 动因：
--   AA002 = 按车辆装载重量的正常/闲置比例分摊
--   AA003 = 按整包/单件装卸票数比例分摊
--   AA004 = 按整包/单件中转票数比例分摊
-- ============================================================

-- --- 运输费按装载重量分摊（AA002）：支线 → 支线正常 / 支线闲置 ---
-- 营业点支线运输费 → 按装载重量（AA002）分摊到支线正常（201010）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201000', '支线', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201010', '支线正常', null);

-- 营业点支线运输费 → 按装载重量（AA002）分摊到支线闲置（201020）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201000', '支线', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201020', '支线闲置', null);

-- 营业点干线运输费 → 按装载重量（AA002）分摊到干线正常（202010）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202000', '干线', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202010', '干线正常', null);

-- 营业点干线运输费 → 按装载重量（AA002）分摊到干线闲置（202020）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202000', '干线', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202020', '干线闲置', null);

-- 中转场支线运输费 → 按装载重量（AA002）分摊到支线正常/闲置
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201000', '支线', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201010', '支线正常', null);

insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201000', '支线', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201020', '支线闲置', null);

-- 中转场干线运输费 → 按装载重量（AA002）分摊到干线正常/闲置
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202000', '干线', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202010', '干线正常', null);

insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA002', '车辆装载重量的正常闲置', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202000', '干线', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202020', '干线闲置', null);

-- --- 装卸费按整包/单件票数分摊（AA003）---
-- 中转场装卸薪酬 → 按整包单件票数（AA003）分摊到整包装卸（301010）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA003', '整包单件装卸票数', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301000', '装卸', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301010', '整包装卸', null);

-- 中转场装卸薪酬 → 按整包单件票数（AA003）分摊到单件装卸（301020）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA003', '整包单件装卸票数', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301000', '装卸', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301020', '单件装卸', null);

-- 中转场装卸设备折旧 → 按整包单件票数（AA003）分摊到整包装卸（301010）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA003', '整包单件装卸票数', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301000', '装卸', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301010', '整包装卸', null);

-- 中转场装卸设备折旧 → 按整包单件票数（AA003）分摊到单件装卸（301020）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA003', '整包单件装卸票数', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301000', '装卸', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301020', '单件装卸', null);

-- --- 中转费按整包/单件票数分摊（AA004）---
-- 中转场中转薪酬 → 按整包单件票数（AA004）分摊到整包中转（302010）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA004', '整包单件中转票数', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302000', '中转', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302010', '整包中转', null);

-- 中转场中转薪酬 → 按整包单件票数（AA004）分摊到单件中转（302020）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA004', '整包单件中转票数', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302000', '中转', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302020', '单件中转', null);

-- 中转场中转设备折旧 → 按整包单件票数（AA004）分摊到整包中转（302010）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA004', '整包单件中转票数', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302000', '中转', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302010', '整包中转', null);

-- 中转场中转设备折旧 → 按整包单件票数（AA004）分摊到单件中转（302020）
insert into abc_rel_aa_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, TO_DEPT_TYPE_CODE, TO_DEPT_TYPE_NAME, TO_FUNC_CODE, TO_FUNC_NAME, TO_RESO_CODE, TO_RESO_NAME, TO_ACTI_CODE, TO_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AA01', 'AA004', '整包单件中转票数', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302000', '中转', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302020', '单件中转', null);









-- ============================================================
-- 第四部分：AO 分摊规则（ABC_REL_AO_DIST）
-- AO = Activity to Order（运单），作业成本最终分摊到运单
-- 这是四级分摊的最后一步，将每个作业的成本分配到具体运单上
-- 动因代码：
--   AO002 = 收件运单数（收件作业按运单数分摊）
--   AO003 = 派件运单数（派件作业按运单数分摊）
--   AO004 = 收派运单数（管理作业按运单数分摊）
--   AO005 = 车辆运输的运单（运输作业按运单数分摊）
--   AO006 = 整包装卸的运单（整包装卸作业按运单数分摊）
--   AO007 = 单件装卸的运单（单件装卸作业按运单数分摊）
--   AO008 = 整包中转的运单（整包中转作业按运单数分摊）
--   AO009 = 单件中转的运单（单件中转作业按运单数分摊）
-- ============================================================

-- --- 营业点（YYD）收件/派件作业的 AO 分摊 ---
-- 收件薪酬福利 → 按收件运单数（AO002）分摊到每件运单
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO002', '收件运单', 'YYD', '营业点', '1010', '收件', 'ZY0101', '薪酬福利', '101010', '收件作业', null);

-- 派件薪酬福利 → 按派件运单数（AO003）分摊到每件运单
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO003', '派件运单', 'YYD', '营业点', '1020', '派件', 'ZY0101', '薪酬福利', '101020', '派件作业', null);

-- 收件设备折旧 → 按收件运单数（AO002）分摊到每件运单
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO002', '收件运单', 'YYD', '营业点', '1010', '收件', 'ZY0201', '设备折旧', '101010', '收件作业', null);

-- 派件设备折旧 → 按派件运单数（AO003）分摊到每件运单
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO003', '派件运单', 'YYD', '营业点', '1020', '派件', 'ZY0201', '设备折旧', '101020', '派件作业', null);

-- 收件物料费 → 按收件运单数（AO002）分摊到每件运单
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO002', '收件运单', 'YYD', '营业点', '1010', '收件', 'ZY0401', '物料费', '101010', '收件作业', null);

-- 收件生鲜物料费 → 按收件电商运单数（AO006）分摊，仅电商产品涉及生鲜保鲜
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO006', '收件电商产品运单', 'YYD', '营业点', '1010', '收件', 'ZY0402', '生鲜物料费', '101010', '收件作业', null);

-- --- 管理层 AO 分摊：管理支持按收派运单数（AO004）分摊 ---
-- 业务区管理薪酬 → 按收派运单数（AO004）分摊，适用于所有区部级别
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO004', '收派运单', 'YYC', '业务区', '1040', '管理', 'ZY0101', '薪酬福利', '101040', '管理支持', null);

-- 分拨区管理薪酬 → 按收派运单数（AO004）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO004', '收派运单', 'FBC', '分拨区', '1040', '管理', 'ZY0101', '薪酬福利', '101040', '管理支持', null);

-- 总部管理薪酬 → 按收派运单数（AO004）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO004', '收派运单', 'ZB', '总部', '1040', '管理', 'ZY0101', '薪酬福利', '101040', '管理支持', null);

-- --- 运输作业 AO 分摊：按运单数（AO005）分摊到每件运单 ---
-- 营业点支线/干线运输费，按正常/闲置状态分别以运单数分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201010', '支线正常', null);

insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '201020', '支线闲置', null);

insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202010', '干线正常', null);

insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'YYD', '营业点', '1030', '运输', 'ZY0301', '运输费', '202020', '干线闲置', null);

-- 中转场支线/干线运输费，同样按运单数（AO005）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201010', '支线正常', null);

insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '201020', '支线闲置', null);

insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202010', '干线正常', null);

insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO005', '车辆运输的运单', 'ZZC', '中转场', '1030', '运输', 'ZY0301', '运输费', '202020', '干线闲置', null);

-- --- 中转场操作作业 AO 分摊 ---
-- 整包装卸薪酬/设备 → 按整包装卸运单数（AO006）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO006', '整包装卸的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301010', '整包装卸', null);

-- 单件装卸薪酬 → 按单件装卸运单数（AO007）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO007', '单件装卸的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '301020', '单件装卸', null);

-- 整包装卸设备折旧 → 按整包装卸运单数（AO006）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO006', '整包装卸的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301010', '整包装卸', null);

-- 单件装卸设备折旧 → 按单件装卸运单数（AO007）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO007', '单件装卸的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '301020', '单件装卸', null);

-- 整包中转薪酬 → 按整包中转运单数（AO008）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO008', '整包中转的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302010', '整包中转', null);

-- 单件中转薪酬 → 按单件中转运单数（AO009）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO009', '单件中转的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0101', '薪酬福利', '302020', '单件中转', null);

-- 整包中转设备折旧 → 按整包中转运单数（AO008）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO008', '整包中转的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302010', '整包中转', null);

-- 单件中转设备折旧 → 按单件中转运单数（AO009）分摊
insert into abc_rel_ao_dist (MODE_CODE, FM_DT, TO_DT, DIST_TYPE, DRIV_CODE, DRIV_NAME, FM_DEPT_TYPE_CODE, FM_DEPT_TYPE_NAME, FM_FUNC_CODE, FM_FUNC_NAME, FM_RESO_CODE, FM_RESO_NAME, FM_ACTI_CODE, FM_ACTI_NAME, LOAD_TM)
values ('100', STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'AO01', 'AO009', '单件中转的运单', 'ZZC', '中转场', '1050', '操作', 'ZY0201', '设备折旧', '302020', '单件中转', null);
