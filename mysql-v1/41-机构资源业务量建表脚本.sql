-- ============================================================
-- 文件名: 41-机构资源业务量建表脚本.sql
-- 说明: 机构维度表（含层级临时表）、运单信息表、客户维表、产品维表、
--       以及资源相关表（与 31 脚本有部分重叠，此处为完整业务数据准备阶段）
-- 所属阶段: 业务数据准备（第2步）
-- ============================================================


-- ------------------------------------------------------------
-- 表名: ODS_DEPT
-- 用途: ODS 层源数据，存储从运营系统获取的机构（网点）基本信息
-- 在 ABC 模型中的角色: 原始数据入口，是机构维度表的源数据
--       经加工后生成 ABC_DIM_DEPT（含层级关系）
-- 关键字段:
--   dept_code   - 机构代码（网点编号）
--   dept_type   - 机构类型（如区部、网点、分拨中心）
--   parent_code - 父机构代码（构成树形层级）
--   city_code   - 所属城市
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ODS_DEPT (
  dept_code VARCHAR(30) COMMENT '部门代码',
  dept_name VARCHAR(100) COMMENT '部门名称',
  dept_type VARCHAR(30) COMMENT '部门类型',
  dept_type_name VARCHAR(100) COMMENT '部门类型名称',
  parent_code VARCHAR(30) COMMENT '父结点',
  city_code VARCHAR(30) COMMENT '城市',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ODS机构表';


-- ------------------------------------------------------------
-- 表名: ABC_DIM_DEPT_TMP01
-- 用途: 机构维度加工临时表（第1步）- 存储基础信息及层级计算辅助字段
-- 在 ABC 模型中的角色: 中间临时表，用于递归构建机构层级路径
--       code_path/name_path 用于记录从根节点到当前节点的路径
-- 关键字段:
--   type_level  - 层级深度
--   code_path   - 机构代码路径（如 总部/大区/区部/网点）
--   name_path   - 机构名称路径
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_DIM_DEPT_TMP01 (
  dept_code VARCHAR(30) COMMENT '部门代码',
  dept_name VARCHAR(100) COMMENT '部门名称',
  dept_type VARCHAR(30) COMMENT '部门类型',
  dept_type_name VARCHAR(100) COMMENT '部门类型名称',
  parent_code VARCHAR(30) COMMENT '父结点',
  city_code VARCHAR(30) COMMENT '城市',
  type_level DECIMAL(20,6) COMMENT '层级深度',
  code_path TEXT COMMENT '机构代码路径',
  name_path TEXT COMMENT '机构名称路径'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='机构维度加工临时表1-层级路径构建';


-- ------------------------------------------------------------
-- 表名: ABC_DIM_DEPT_TMP02
-- 用途: 机构维度加工临时表（第2步）- 解析层级路径为 level1~level5 列
-- 在 ABC 模型中的角色: 中间临时表，将路径字符串拆分为各层级字段
--       为最终 ABC_DIM_DEPT 提供扁平化的层级结构
-- 关键字段:
--   code_path   - 原始路径（用于拆分）
--   level1_code~level5_code - 各层级机构代码
--   level1_name~level5_name - 各层级机构名称
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_DIM_DEPT_TMP02 (
  code_path TEXT COMMENT '机构代码路径',
  dept_code TEXT COMMENT '部门代码',
  dept_name TEXT COMMENT '部门名称',
  fm_tm DATETIME COMMENT '开始时间',
  to_tm DATETIME COMMENT '结束时间',
  level1_code TEXT COMMENT '层级1机构代码',
  level1_name TEXT COMMENT '层级1机构名称',
  level2_code TEXT COMMENT '层级2机构代码',
  level2_name TEXT COMMENT '层级2机构名称',
  level3_code TEXT COMMENT '层级3机构代码',
  level3_name TEXT COMMENT '层级3机构名称',
  level4_code TEXT COMMENT '层级4机构代码',
  level4_name TEXT COMMENT '层级4机构名称',
  level5_code TEXT COMMENT '层级5机构代码',
  level5_name TEXT COMMENT '层级5机构名称',
  dept_type VARCHAR(30) COMMENT '部门类型',
  dept_type_name VARCHAR(100) COMMENT '部门类型名称',
  parent_code VARCHAR(30) COMMENT '父结点',
  city_code VARCHAR(30) COMMENT '城市',
  type_level DECIMAL(20,6) COMMENT '层级深度'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='机构维度加工临时表2-层级拆分';


-- ------------------------------------------------------------
-- 表名: ABC_DIM_DEPT_TMP03
-- 用途: 机构维度加工临时表（第3步）- 加入代理键 dept_id
-- 在 ABC 模型中的角色: 中间临时表，为缓慢变化维度生成代理键
--       最终数据写入 ABC_DIM_DEPT
-- 关键字段:
--   dept_id     - 机构代理键（自增或序列生成）
--   level1~level5 - 各层级信息（继承自 TMP02）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_DIM_DEPT_TMP03 (
  dept_id DECIMAL(20,6) COMMENT '机构代理键',
  dept_code TEXT COMMENT '部门代码',
  dept_name TEXT COMMENT '部门名称',
  dept_type VARCHAR(30) COMMENT '部门类型',
  dept_type_name VARCHAR(100) COMMENT '部门类型名称',
  fm_tm DATETIME COMMENT '开始时间',
  to_tm DATETIME COMMENT '结束时间',
  level1_code TEXT COMMENT '层级1机构代码',
  level1_name TEXT COMMENT '层级1机构名称',
  level2_code TEXT COMMENT '层级2机构代码',
  level2_name TEXT COMMENT '层级2机构名称',
  level3_code TEXT COMMENT '层级3机构代码',
  level3_name TEXT COMMENT '层级3机构名称',
  level4_code TEXT COMMENT '层级4机构代码',
  level4_name TEXT COMMENT '层级4机构名称',
  level5_code TEXT COMMENT '层级5机构代码',
  level5_name TEXT COMMENT '层级5机构名称',
  parent_code VARCHAR(30) COMMENT '父结点',
  city_code VARCHAR(30) COMMENT '城市',
  type_level DECIMAL(20,6) COMMENT '层级深度'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='机构维度加工临时表3-代理键生成';


-- ------------------------------------------------------------
-- 表名: ABC_DIM_DEPT
-- 用途: 机构维度表（最终产出），包含完整的五级层级结构
-- 在 ABC 模型中的角色: 核心维度表，贯穿整个四级分摊模型
--       所有分摊规则表和结果表中的 dept/func 都引用此表的层级
--       支持按区部、城市等维度做利润分析
-- 关键字段:
--   dept_id     - 代理键（唯一标识）
--   dept_code   - 机构代码（业务主键）
--   level1~level5 - 五级层级结构（如：总部→大区→省份→区部→网点）
--   type_level  - 当前节点所在层级
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_DIM_DEPT (
  dept_id DECIMAL(20,6) COMMENT '机构ID代理键',
  dept_code VARCHAR(30) COMMENT '部门代码',
  dept_name VARCHAR(100) COMMENT '部门名称',
  dept_type VARCHAR(30) COMMENT '网点类型',
  dept_type_name VARCHAR(100) COMMENT '网点类型名',
  fm_tm DATETIME COMMENT '开始日期',
  to_tm DATETIME COMMENT '结束日期',
  level1_code VARCHAR(30) COMMENT '层级1代码',
  level1_name VARCHAR(100) COMMENT '层级1名称',
  level2_code VARCHAR(30) COMMENT '层级2代码',
  level2_name VARCHAR(100) COMMENT '层级2名称',
  level3_code VARCHAR(30) COMMENT '层级3代码',
  level3_name VARCHAR(100) COMMENT '层级3名称',
  level4_code VARCHAR(30) COMMENT '层级4代码',
  level4_name VARCHAR(100) COMMENT '层级4名称',
  level5_code VARCHAR(30) COMMENT '层级5代码',
  level5_name VARCHAR(100) COMMENT '层级5名称',
  parent_code VARCHAR(30) COMMENT '父结点',
  city_code VARCHAR(30) COMMENT '城市',
  type_level INT COMMENT '层级',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='机构维度表';


-- ------------------------------------------------------------
-- 表名: ABC_BSL_WAYBILL
-- 用途: 运单基础信息表，存储每个运单的收派件、客户、产品、重量、金额等
-- 在 ABC 模型中的角色: 核心业务事实表，是 AO 分摊阶段的最终承载对象
--       AO 分摊将作业成本按动因分配到每个运单上
--       也是最终成本分析基表 ABC_BSL_COST_BASE 的运单信息来源
-- 关键字段:
--   waybill_no  - 运单号（唯一标识一笔快件）
--   rec_dept    - 收件网点（始发端）
--   send_dept   - 派件网点（目的端）
--   cust_code   - 客户卡号（关联客户维表）
--   prod_code   - 产品代码（关联产品维表）
--   wt          - 计费重量
--   amt         - 运费金额（收入）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_BSL_WAYBILL (
  waybill_no VARCHAR(30) COMMENT '运单号',
  rec_dt DATETIME COMMENT '收件日期',
  send_dt DATETIME COMMENT '派件日期',
  cust_code VARCHAR(30) COMMENT '客户卡号',
  rec_dept VARCHAR(30) COMMENT '收件网点',
  send_dept VARCHAR(30) COMMENT '派件网点',
  rec_city VARCHAR(30) COMMENT '收件城市',
  send_city VARCHAR(30) COMMENT '派件城市',
  prod_code VARCHAR(30) COMMENT '产品代码',
  prod_name VARCHAR(100) COMMENT '产品名',
  wt DECIMAL(20,6) COMMENT '计费重量',
  amt DECIMAL(20,6) COMMENT '金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运单基础信息表';


-- ------------------------------------------------------------
-- 表名: ABC_REL_CUST
-- 用途: 客户维度表，存储客户基本信息及行业分类
-- 在 ABC 模型中的角色: 维度表，用于客户利润分析
--       支持按行业维度分析不同客户群体的盈利能力
-- 关键字段:
--   cust_code   - 客户代码（客户卡号）
--   cust_name   - 客户名称
--   indu_l1     - 一级行业分类（如电商、制造业）
--   indu_l2     - 二级行业分类
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_REL_CUST (
  cust_code VARCHAR(30) COMMENT '客户代码',
  cust_name VARCHAR(100) COMMENT '客户名',
  indu_l1 VARCHAR(100) COMMENT '1级行业',
  indu_l2 VARCHAR(30) COMMENT '2级行业',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='客户维表';


-- ------------------------------------------------------------
-- 表名: ABC_REL_PROD
-- 用途: 产品维度表，存储快递产品定义及定价规则
-- 在 ABC 模型中的角色: 维度表，用于产品利润分析
--       支持按产品维度分析不同产品的成本与收入对比
-- 关键字段:
--   prod_code   - 产品代码（如标快、特惠）
--   prod_name   - 产品名称
--   first_pric  - 首价（首重价格）
--   add_pric    - 续价（续重单价）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_REL_PROD (
  prod_code VARCHAR(30) COMMENT '产品代码',
  prod_name VARCHAR(100) COMMENT '产品名',
  first_pric DECIMAL(20,6) COMMENT '首价',
  add_pric DECIMAL(20,6) COMMENT '续价',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='产品维表';


-- ------------------------------------------------------------
-- 表名: ODS_SUBJ_ACCO
-- 用途: ODS 层源数据表，存储从财务系统接口获取的科目余额明细
-- 在 ABC 模型中的角色: 原始数据入口，是四级分摊模型的源头数据
--       通过 ABC_REL_SUBJ_RESO 映射后形成资源成本
--       （注意：与 31 脚本中定义相同，此处为完整脚本包含）
-- 关键字段:
--   month_code  - 月份
--   dept_code   - 机构代码
--   subj_code   - 科目代码
--   post_name   - 岗位名（用于区分人员归属）
--   car_no      - 车牌号（用于运输车辆成本识别）
--   amt         - 科目金额
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ODS_SUBJ_ACCO (
  month_code VARCHAR(10) COMMENT '月份',
  dept_code VARCHAR(30) COMMENT '机构代码',
  subj_code VARCHAR(30) COMMENT '科目代码',
  subj_name VARCHAR(100) COMMENT '科目名称',
  post_name VARCHAR(100) COMMENT '岗位名',
  car_no VARCHAR(10) COMMENT '车牌号',
  amt DECIMAL(20,6) COMMENT '金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ODS财务成本接口表';


-- ------------------------------------------------------------
-- 表名: ABC_REL_SUBJ_RESO
-- 用途: 配置会计科目与资源代码的映射关系
-- 在 ABC 模型中的角色: 规则配置表，用于将财务科目余额转换为资源成本
--       （注意：与 31 脚本中定义相同，此处为完整脚本包含）
-- 关键字段:
--   subj_code   - 会计科目代码
--   reso_code   - 映射到的资源代码
--   reso_type   - 资源类型（区分直接/间接资源）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_REL_SUBJ_RESO (
  fm_dt DATETIME COMMENT '开始日期',
  to_dt DATETIME COMMENT '结束日期',
  subj_code VARCHAR(30) COMMENT '科目代码',
  subj_name VARCHAR(100) COMMENT '科目名称',
  reso_code VARCHAR(30) COMMENT '资源代码',
  reso_name VARCHAR(100) COMMENT '资源名称',
  reso_type VARCHAR(100) COMMENT '类型',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='科目资源配置表';


-- ------------------------------------------------------------
-- 表名: ABC_DIM_RESO
-- 用途: 资源维度表，定义资源的层级结构
-- 在 ABC 模型中的角色: 核心维度表，贯穿整个四级分摊模型
--       （注意：与 31 脚本中定义相同，此处为完整脚本包含）
-- 关键字段:
--   reso_code   - 资源代码（最细粒度）
--   l1_reso_code/l2_reso_code - 一级/二级资源分类
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_DIM_RESO (
  fm_dt DATETIME COMMENT '开始日期',
  to_dt DATETIME COMMENT '结束日期',
  reso_code VARCHAR(30) COMMENT '资源代码',
  reso_name VARCHAR(100) COMMENT '资源名称',
  l1_reso_code VARCHAR(30) COMMENT '层级1资源代码',
  l1_reso_name VARCHAR(100) COMMENT '层级1资源名称',
  l2_reso_code VARCHAR(30) COMMENT '层级2资源代码',
  l2_reso_name VARCHAR(100) COMMENT '层级2资源名称',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资源维度表';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RESO_LIST
-- 用途: 资源清单事实表，存储各机构各功能中心的资源金额
-- 在 ABC 模型中的角色: 基础事实表，是 RR 分摊的输入数据
--       （注意：与 31 脚本中定义相同，此处为完整脚本包含）
-- 关键字段:
--   reso_code   - 资源代码（ZY0101=人工、ZY0201=设备、ZY0301=运输）
--   func_code   - 功能中心代码
--   amt         - 资源金额
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_FCT_RESO_LIST (
  month_code VARCHAR(10) COMMENT '月份',
  dept_code VARCHAR(30) COMMENT '机构代码',
  dept_type VARCHAR(100) COMMENT '机构类型',
  dept_type_name VARCHAR(100) COMMENT '机构类型名',
  func_code VARCHAR(30) COMMENT '功能中心代码',
  func_name VARCHAR(100) COMMENT '功能中心名称',
  car_no VARCHAR(10) COMMENT '车牌号',
  reso_code VARCHAR(10) COMMENT '资源代码',
  reso_name VARCHAR(100) COMMENT '资源名称',
  amt DECIMAL(20,6) COMMENT '金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC资源结果表';


-- ------------------------------------------------------------
-- 表名: ABC_BSL_OP_WAYBILL
-- 用途: 运单操作明细表，记录每个运单在各网点的操作流水
-- 在 ABC 模型中的角色: 业务事实表，是 AO 分摊阶段计算动因量的基础
--       操作记录（如收件、转运、派件）用于匹配动因逻辑表中的规则
--       从而计算每个运单在各作业上的动因量
-- 关键字段:
--   waybill_no  - 运单号
--   op_dept_code - 操作网点代码
--   op_code     - 操作码（如 P01=收件、P02=派件）
--   line_code   - 线路代码（运输作业关联）
--   is_pkg      - 是否包车/包件
--   waybill_wt  - 运单重量
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ABC_BSL_OP_WAYBILL (
  op_dt DATETIME COMMENT '操作日期',
  op_dept_code VARCHAR(30) COMMENT '操作网点',
  op_code VARCHAR(30) COMMENT '操作码',
  op_name VARCHAR(100) COMMENT '操作码名称',
  waybill_no VARCHAR(30) COMMENT '运单号',
  car_no VARCHAR(30) COMMENT '车牌',
  line_code VARCHAR(30) COMMENT '线路',
  is_pkg INT COMMENT '是否包',
  waybill_wt DECIMAL(20,6) COMMENT '重量',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运单操作基础表';
