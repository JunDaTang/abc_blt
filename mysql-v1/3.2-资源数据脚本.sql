-- ============================================================
-- 文件名: 3.2-资源数据脚本.sql
-- 说明: 初始化资源维度表和科目-资源映射关系
--       1) 插入资源维度表 ABC_DIM_RESO：定义5种资源（薪酬福利、设备折旧、运输费、物料费、生鲜物料费）
--       2) 插入科目-资源映射表 ABC_REL_SUBJ_RESO：将财务科目归集到对应资源
-- 执行顺序: 第1步（基础数据），在建表脚本（3.1）之后执行
-- ============================================================

USE abc_blt;


-- ============================================================
-- 第一部分：资源维度表（ABC_DIM_RESO）
-- 定义 ABC 系统的资源清单，资源按三级层次组织：总资源 → 二级分类 → 具体资源
-- ZY00 总资源
--   ├─ ZY01 人工成本 → ZY0101 薪酬福利
--   ├─ ZY02 设备成本 → ZY0201 设备折旧
--   ├─ ZY03 运输成本 → ZY0301 运输费
--   └─ ZY04 物料成本 → ZY0401 物料费、ZY0402 生鲜物料费
-- ============================================================

-- 插入资源维度：薪酬福利（ZY0101），属于人工成本（ZY01），是最终分摊到运单的核心资源
insert into ABC_DIM_RESO (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0101', '薪酬福利', 'ZY00', '总资源', 'ZY01', '人工成本', null);

-- 插入资源维度：设备折旧（ZY0201），属于设备成本（ZY02），如皮带机、发动机等折旧费用
insert into ABC_DIM_RESO (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0201', '设备折旧', 'ZY00', '总资源', 'ZY02', '设备成本', null);

-- 插入资源维度：运输费（ZY0301），属于运输成本（ZY03），如车辆油费、过桥费
insert into ABC_DIM_RESO (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0301', '运输费', 'ZY00', '总资源', 'ZY03', '运输成本', null);

-- 插入资源维度：物料费（ZY0401），属于物料成本（ZY04），如包装材料费
insert into ABC_DIM_RESO (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0401', '物料费', 'ZY00', '总资源', 'ZY04', '物料成本', null);

-- 插入资源维度：生鲜物料费（ZY0402），属于物料成本（ZY04），如保鲜材料费
insert into ABC_DIM_RESO (FM_DT, TO_DT, RESO_CODE, RESO_NAME, L1_RESO_CODE, L1_RESO_NAME, L2_RESO_CODE, L2_RESO_NAME, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), 'ZY0402', '生鲜物料费', 'ZY00', '总资源', 'ZY04', '物料成本', null);



-- ============================================================
-- 第二部分：科目-资源映射表（ABC_REL_SUBJ_RESO）
-- 将财务科目编码归集到对应的资源代码，建立"科目 → 资源"的映射关系
-- RESO_TYPE 含义：
--   '科目归类' = 该科目按归属关系映射到资源
--   '资源性质' = 该科目按资源性质直接对应
-- ============================================================

-- 插入科目-资源映射：人工成本类科目 → 薪酬福利（ZY0101）
-- 600101 基本工资：员工基本薪酬，直接归入薪酬福利资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600101', '基本工资', 'ZY0101', '薪酬福利', '科目归类', null);

-- 600102 社保：企业缴纳的社保费用，归入薪酬福利资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600102', '社保', 'ZY0101', '薪酬福利', '科目归类', null);

-- 600103 福利：员工福利费用，归入薪酬福利资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600103', '福利', 'ZY0101', '薪酬福利', '科目归类', null);

-- 插入科目-资源映射：设备成本类科目 → 设备折旧（ZY0201）
-- 600201 皮带机折旧：分拣设备折旧，归入设备折旧资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600201', '皮带机折旧', 'ZY0201', '设备折旧', '科目归类', null);

-- 600202 发动机折旧：运输车辆发动机折旧，归入设备折旧资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600202', '发动机折旧', 'ZY0201', '设备折旧', '科目归类', null);

-- 插入科目-资源映射：运输成本类科目 → 运输费（ZY0301）
-- 600301 车辆油费：运输车辆燃油费，归入运输费资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600301', '车辆油费', 'ZY0301', '运输费', '科目归类', null);

-- 600302 车辆过桥费：高速路桥费，归入运输费资源
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600302', '车辆过桥费', 'ZY0301', '运输费', '科目归类', null);

-- 插入科目-资源映射：物料成本类科目 → 物料费/生鲜物料费
-- 600401 材料费：普通包装材料费，归入物料费资源（ZY0401）
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600401', '材料费', 'ZY0401', '物料费', '科目归类', null);

-- 600402 保鲜材料费：生鲜保鲜材料费，按资源性质归入生鲜物料费（ZY0402）
insert into abc_rel_subj_reso (FM_DT, TO_DT, SUBJ_CODE, SUBJ_NAME, RESO_CODE, RESO_NAME, RESO_TYPE, LOAD_TM)
values (STR_TO_DATE('01-01-2019', '%d-%m-%Y'), STR_TO_DATE('31-12-9999', '%d-%m-%Y'), '600402', '保鲜材料费', 'ZY0402', '生鲜物料费', '资源性质', null);


