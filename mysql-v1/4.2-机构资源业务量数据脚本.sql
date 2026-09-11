-- ============================================================
-- 文件名: 4.2-机构资源业务量数据脚本.sql
-- 说明: 初始化 ABC 系统所需的全部基础配置数据，包含6张表：
--       1) ABC_DIM_RESO    - 资源维度表（资源清单）
--       2) ABC_REL_CUST    - 客户维表（客户信息及行业分类）
--       3) ABC_REL_PROD    - 产品维表（快递产品及定价）
--       4) ABC_REL_SUBJ_RESO - 科目-资源映射（财务科目归集到资源）
--       5) ODS_DEPT        - ODS 机构维表（含层级关系的机构清单）
-- 执行顺序: 第2步（业务数据准备），在建表脚本（4.1）之后、生成数据脚本（4.4）之前执行
-- ============================================================

USE abc_blt;


-- ============================================================
-- 第一部分：资源维度表（ABC_DIM_RESO）
-- 先清空再插入，确保数据幂等
-- 资源按三级层次：总资源(ZY00) → 二级分类 → 具体资源
-- ============================================================

DELETE FROM abc_dim_reso;


-- 插入资源维度：薪酬福利（ZY0101）→ 人工成本（ZY01）
insert into abc_dim_reso (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0101', '薪酬福利', 'ZY00', '总资源', 'ZY01', '人工成本', null);

-- 插入资源维度：设备折旧（ZY0201）→ 设备成本（ZY02）
insert into abc_dim_reso (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0201', '设备折旧', 'ZY00', '总资源', 'ZY02', '设备成本', null);

-- 插入资源维度：运输费（ZY0301）→ 运输成本（ZY03）
insert into abc_dim_reso (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0301', '运输费', 'ZY00', '总资源', 'ZY03', '运输成本', null);

-- 插入资源维度：物料费（ZY0401）→ 物料成本（ZY04）
insert into abc_dim_reso (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0401', '物料费', 'ZY00', '总资源', 'ZY04', '物料成本', null);

-- 插入资源维度：生鲜物料费（ZY0402）→ 物料成本（ZY04）
insert into abc_dim_reso (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0402', '生鲜物料费', 'ZY00', '总资源', 'ZY04', '物料成本', null);







-- ============================================================
-- 第二部分：客户维表（ABC_REL_CUST）
-- 定义模拟客户数据，包含客户编码、名称、行业分类（一级/二级）
-- 用于后续客户利润分析，按行业维度查看盈利能力
-- ============================================================

DELETE FROM abc_rel_cust;

-- 插入客户数据：制造业 - 手机行业客户
insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C100', '华为', '制造业', '手机', null);

insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C101', '中兴', '制造业', '手机', null);

insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C102', '小米', '制造业', '手机', null);

-- 插入客户数据：金融业 - 银行行业客户
insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C103', '中行', '金融', '银行', null);

insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C104', '建行', '金融', '银行', null);

insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C105', '农行', '金融', '银行', null);

-- 插入客户数据：制造业 - 文具行业客户
insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C106', '齐心', '制造业', '文具', null);

insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C107', '德力', '制造业', '文具', null);

-- 插入客户数据：互联网 - 电商行业客户
insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C108', '京东', '互联网', '电商', null);

insert into abc_rel_cust (CUST_CODE, CUST_NAME, INDU_L1, INDU_L2, LOAD_TM)
values ('C109', '淘宝', '互联网', '电商', null);





-- ============================================================
-- 第三部分：产品维表（ABC_REL_PROD）
-- 定义快递产品类型及定价规则
-- FIRST_PRIC = 首重价格，ADD_PRIC = 续重单价（元/kg）
-- ============================================================

DELETE FROM abc_rel_prod;

-- 插入产品数据：标快（P001），首重20元，续重5元/kg，标准快递产品
insert into abc_rel_prod (PROD_CODE, PROD_NAME, FIRST_PRIC, ADD_PRIC, LOAD_TM)
values ('P001', '标快', 20, 5, null);

-- 插入产品数据：电商（P002），首重12元，续重4元/kg，面向电商客户的经济型产品
insert into abc_rel_prod (PROD_CODE, PROD_NAME, FIRST_PRIC, ADD_PRIC, LOAD_TM)
values ('P002', '电商', 12, 4, null);

-- 插入产品数据：即日（P003），首重25元，续重8元/kg，当天达高端产品
insert into abc_rel_prod (PROD_CODE, PROD_NAME, FIRST_PRIC, ADD_PRIC, LOAD_TM)
values ('P003', '即日', 25, 8, null);

-- 插入产品数据：次日（P004），首重22元，续重6元/kg，次日达产品
insert into abc_rel_prod (PROD_CODE, PROD_NAME, FIRST_PRIC, ADD_PRIC, LOAD_TM)
values ('P004', '次日', 22, 6, null);







-- ============================================================
-- 第四部分：科目-资源映射表（ABC_REL_SUBJ_RESO）
-- 将财务科目编码归集到对应的资源代码（与3.2脚本数据一致）
-- ============================================================

DELETE FROM abc_rel_subj_reso;

-- 人工成本类科目 → 薪酬福利（ZY0101）
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600101', '基本工资', 'ZY0101', '薪酬福利', '科目归类', null);

insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600102', '社保', 'ZY0101', '薪酬福利', '科目归类', null);

insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600103', '福利', 'ZY0101', '薪酬福利', '科目归类', null);

-- 设备成本类科目 → 设备折旧（ZY0201）
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600201', '皮带机折旧', 'ZY0201', '设备折旧', '科目归类', null);

insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600202', '发动机折旧', 'ZY0201', '设备折旧', '科目归类', null);

-- 运输成本类科目 → 运输费（ZY0301）
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600301', '车辆油费', 'ZY0301', '运输费', '科目归类', null);

insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600302', '车辆过桥费', 'ZY0301', '运输费', '科目归类', null);

-- 物料成本类科目 → 物料费/生鲜物料费
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600401', '材料费', 'ZY0401', '物料费', '科目归类', null);

insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600402', '保鲜材料费', 'ZY0402', '生鲜物料费', '资源性质', null);







-- ============================================================
-- 第五部分：ODS 机构维表（ODS_DEPT）
-- 源系统机构数据，包含机构层级关系
-- DEPT_TYPE 类型说明：
--   ZB  = 总部（最高层）
--   FBC = 分拨区（大区级别，如华南分拨区、华中分拨区、华北分拨区）
--   YYC = 业务区（城市级别，如深圳区部、上海区部）
--   ZZC = 中转场（分拣中心）
--   YYD = 营业点（末端网点，直接面对客户）
-- PARENT_CODE 定义上下级关系，形成机构树
-- ============================================================

DELETE FROM ods_dept;

-- 插入机构数据：总部（顶层节点）
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('100', '总部', 'ZB', '总部', null, '755', null);

-- 插入机构数据：深圳区部及其下属机构
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('755AB', '深圳南山营业点', 'YYD', '营业点', '755Y', '755', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('755AC', '深圳福田营业点', 'YYD', '营业点', '755Y', '755', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('755W', '深圳中转场', 'ZZC', '中转场', '111Y', '755', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('755Y', '深圳区部', 'YYC', '业务区', '100', '755', null);

-- 插入机构数据：华南分拨区（管辖深圳、广州中转场）
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('111Y', '华南分拨区', 'FBC', '分拨区', '100', '755', null);

-- 插入机构数据：上海区部及其下属机构
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('021AB', '上海浦东', 'YYD', '营业点', '021Y', '021', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('021AC', '上海嘉定', 'YYD', '营业点', '021Y', '021', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('021W', '上海中转场', 'ZZC', '中转场', '222Y', '021', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('021Y', '上海区部', 'YYC', '业务区', '100', '755', null);

-- 插入机构数据：华中分拨区（管辖上海中转场）
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('222Y', '华中分拨区', 'FBC', '分拨区', '100', '755', null);

-- 插入机构数据：北京区部及其下属机构
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('010AB', '北京西城', 'YYD', '营业点', '010Y', '010', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('010AC', '北京朝阳', 'YYD', '营业点', '010Y', '010', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('010W', '北京中转场', 'ZZC', '中转场', '333Y', '010', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('010Y', '北京区部', 'YYC', '业务区', '100', '755', null);

-- 插入机构数据：华北分拨区（管辖北京中转场）
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('333Y', '华北分拨区', 'FBC', '分拨区', '100', '755', null);

-- 插入机构数据：广州区部及其下属机构（中转场归华南分拨区管辖）
insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('020AB', '广州天河营业点', 'YYD', '营业点', '020Y', '020', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('020AC', '广州越秀营业点', 'YYD', '营业点', '020Y', '020', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('020W', '广州中转场', 'ZZC', '中转场', '111Y', '020', null);

insert into ods_dept (DEPT_CODE, DEPT_NAME, DEPT_TYPE, DEPT_TYPE_NAME, PARENT_CODE, CITY_CODE, LOAD_TM)
values ('020Y', '广州区部', 'YYC', '业务区', '100', '755', null);

