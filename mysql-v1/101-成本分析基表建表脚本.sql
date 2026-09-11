-- ============================================================
-- 文件名: 101-成本分析基表建表脚本.sql
-- 说明: 成本分析基表（ABC_BSL_COST_BASE），是四级分摊模型的最终产出
--       将运单收入与五类成本匹配，支持区部/流向/客户/产品等多维度利润分析
-- 所属阶段: 汇总（第7步）
-- ============================================================


-- ------------------------------------------------------------
-- 表名: ABC_BSL_COST_BASE_TMP01
-- 用途: 成本分析基表加工临时表 - 按运单汇总 AO 分摊结果中的五类成本
-- 在 ABC 模型中的角色: 中间临时表，将 ABC_FCT_AO_DIST 中的分摊结果
--       按资源代码分类汇总为五类成本：
--       dive_amt(设备ZY0201)、car_amt(运输ZY0301)、metr_amt(物料ZY0401/0402)、
--       mgr_amt(管理ZY0101+func=1040)、pep_amt(人工ZY0101+func≠1040)
-- 关键字段:
--   waybill_no  - 运单号
--   dive_amt    - 设备成本
--   car_amt     - 运输成本
--   metr_amt    - 物料成本
--   mgr_amt     - 管理成本
--   pep_amt     - 人工成本
--   all_amt     - 总成本（五类之和）
-- ------------------------------------------------------------
CREATE TABLE ABC_BSL_COST_BASE_TMP01 (
  waybill_no VARCHAR(100) COMMENT '运单号',
  fm_acti_type_code VARCHAR(10) COMMENT '作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '作业类型名称',
  dive_amt DECIMAL(20,6) COMMENT '设备成本',
  car_amt DECIMAL(20,6) COMMENT '运输成本',
  metr_amt DECIMAL(20,6) COMMENT '物料成本',
  mgr_amt DECIMAL(20,6) COMMENT '管理成本',
  pep_amt DECIMAL(20,6) COMMENT '人工成本',
  all_amt DECIMAL(20,6) COMMENT '总成本'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成本分析基表临时表-运单成本汇总';


-- ------------------------------------------------------------
-- 表名: ABC_BSL_COST_BASE
-- 用途: 成本分析基表 - 整个 ABC 四级分摊模型的最终产出
--       运单粒度的收入与成本匹配表，是多维度利润分析的数据基础
-- 在 ABC 模型中的角色: 最终产出表，整合了：
--       - 运单信息（来自 ABC_BSL_WAYBILL）
--       - 机构层级（来自 ABC_DIM_DEPT）
--       - 客户信息（来自 ABC_REL_CUST）
--       - 产品信息（来自 ABC_REL_PROD）
--       - 五类成本（来自 ABC_FCT_AO_DIST 汇总）
--       支持的分析维度：区部利润、流向利润、客户利润、产品利润
-- 关键字段:
--   month_code     - 月份
--   rec_area_code  - 收件区部代码（区部利润分析维度）
--   send_area_code - 派件区部代码
--   waybill_no     - 运单号
--   rec_city/send_city - 始发/目的城市（流向利润分析维度）
--   cust_code      - 客户代码（客户利润分析维度）
--   prod_code      - 产品代码（产品利润分析维度）
--   income_amt     - 运单收入
--   dive_amt       - 设备成本（资源代码 ZY0201）
--   car_amt        - 运输成本（资源代码 ZY0301）
--   metr_amt       - 物料成本（资源代码 ZY0401/ZY0402）
--   mgr_amt        - 管理成本（ZY0101 + func=1040）
--   pep_amt        - 人工成本（ZY0101 + func≠1040）
--   cost_all_amt   - 总成本（五类成本之和）
--   rn             - 收入标记，rn=1 的记录才计入收入（避免运单重复计收入）
-- ------------------------------------------------------------
CREATE TABLE ABC_BSL_COST_BASE (
  month_code VARCHAR(6) COMMENT '月份',
  rec_dept VARCHAR(30) COMMENT '收件网点',
  rec_area_code VARCHAR(30) COMMENT '收件区部代码',
  rec_area_name VARCHAR(30) COMMENT '收件区部名称',
  send_dept VARCHAR(30) COMMENT '派件网点',
  send_area_code VARCHAR(30) COMMENT '派件区部代码',
  send_area_name VARCHAR(30) COMMENT '派件区部名称',
  waybill_no VARCHAR(30) COMMENT '运单号',
  rec_city VARCHAR(30) COMMENT '始发城市',
  send_city VARCHAR(30) COMMENT '目的城市',
  cust_code VARCHAR(30) COMMENT '客户代码',
  cust_name VARCHAR(100) COMMENT '客户名称',
  prod_code VARCHAR(30) COMMENT '产品代码',
  prod_name VARCHAR(100) COMMENT '产品名称',
  income_amt DECIMAL(20,6) COMMENT '收入',
  fm_acti_type_code VARCHAR(10) COMMENT '作业代码',
  fm_acti_type_name VARCHAR(100) COMMENT '作业名称',
  dive_amt DECIMAL(20,6) COMMENT '设备成本',
  car_amt DECIMAL(20,6) COMMENT '运输成本',
  metr_amt DECIMAL(20,6) COMMENT '物料成本',
  mgr_amt DECIMAL(20,6) COMMENT '管理成本',
  pep_amt DECIMAL(20,6) COMMENT '人工成本',
  cost_all_amt DECIMAL(20,6) COMMENT '所有成本',
  rn DECIMAL(20,6) COMMENT '收入状态(1时才能用)',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC成本分析基础表';
