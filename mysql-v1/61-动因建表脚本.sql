-- ============================================================
-- 文件名: 61-动因建表脚本.sql
-- 说明: 四级动因结果表（RR/RA/AA/AO）及动因逻辑配置表、线路维表
--       动因是分摊的"尺子"，决定成本按什么比例分配
-- 所属阶段: 动因计算（第4步）
-- ============================================================


-- ------------------------------------------------------------
-- 表名: ABC_DIM_LINE
-- 用途: 线路维度表，存储运输线路的里程和类型信息
-- 在 ABC 模型中的角色: 维度表，用于运输作业（ZY0301）的动因计算
--       运输成本按线路里程×运单重量分配，里程是重要的分摊因子
-- 关键字段:
--   line_code   - 线路编码（如"深圳-北京"）
--   line_km     - 线路里程（公里）
--   line_type   - 线路类型（干线/支线）
-- ------------------------------------------------------------
CREATE TABLE ABC_DIM_LINE (
  month_code VARCHAR(14) COMMENT '月份',
  line_code VARCHAR(30) COMMENT '线路编码',
  line_km DECIMAL(20,6) COMMENT '线路里程',
  line_type VARCHAR(30) COMMENT '线路类型',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC线路主数据';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RR_DRIV
-- 用途: RR 分摊动因结果表，存储各功能中心的动因量
-- 在 ABC 模型中的角色: 动因事实表，是 RR 分摊计算的比例依据
--       例如：某网点功能中心"人数"动因量=10人，则按 10/总人数 分摊共享资源
--       输入: 由动因逻辑计算生成
--       产出: 供 RR 分摊存储过程使用，计算分摊金额
-- 关键字段:
--   dept_code   - 机构代码
--   func_code   - 功能中心代码
--   driv_code   - 动因代码（如 R01=人数、R02=面积）
--   qty         - 动因量（如人数=10、面积=200平方米）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RR_DRIV (
  month_code VARCHAR(10) COMMENT '月份',
  dept_code VARCHAR(30) COMMENT '机构代码',
  dept_type VARCHAR(100) COMMENT '机构类型',
  dept_type_name VARCHAR(100) COMMENT '机构类型名',
  func_code VARCHAR(30) COMMENT '功能中心代码',
  func_name VARCHAR(100) COMMENT '功能中心名称',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名称',
  qty DECIMAL(20,6) COMMENT '动因量',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RR动因结果表';


-- ------------------------------------------------------------
-- 表名: ABC_REL_DRIV_LOGIC
-- 用途: 动因逻辑配置表，定义动因量的计算规则
--       根据操作码、线路等级、包状态、产品等条件，确定每个作业使用什么动因、乘以什么系数
-- 在 ABC 模型中的角色: 核心规则配置表，是 RA/AA/AO 动因计算的依据
--       决定了运单操作记录如何转化为各作业的动因量
-- 关键字段:
--   driv_code   - 动因代码
--   func_code   - 功能中心
--   acti_code   - 作业代码
--   op_code     - 操作码（匹配运单操作记录）
--   line_leve   - 线路等级（匹配运输线路）
--   pkg_state   - 包状态（区分散件/包件）
--   rt          - 系数（动因量的乘数，如包车系数=1.5）
--   dept_type   - 网点类型（限制适用范围）
--   prod_code   - 产品（限制适用范围）
-- ------------------------------------------------------------
CREATE TABLE ABC_REL_DRIV_LOGIC (
  fm_tm DATETIME COMMENT '开始时间',
  to_tm DATETIME COMMENT '结束时间',
  driv_code VARCHAR(50) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  func_code VARCHAR(50) COMMENT '功能中心',
  func_name VARCHAR(100) COMMENT '功能中心名',
  acti_code VARCHAR(50) COMMENT '作业代码',
  acti_name VARCHAR(100) COMMENT '作业名',
  op_code VARCHAR(50) COMMENT '操作码',
  line_leve VARCHAR(50) COMMENT '线路等级',
  pkg_state VARCHAR(50) COMMENT '包状态',
  rt DECIMAL(20,6) COMMENT '系数',
  dept_type VARCHAR(50) COMMENT '网点类型',
  prod_code VARCHAR(50) COMMENT '产品',
  remark VARCHAR(500) COMMENT '说明',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='动因逻辑配置表';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RA_DRIV
-- 用途: RA 分摊动因结果表，存储各作业在各功能中心的动因量
-- 在 ABC 模型中的角色: 动因事实表，是 RA 分摊计算的比例依据
--       例如：某网点"收件作业"的动因量=500票，"派件作业"=300票
--       则收件作业分摊资源成本的比例=500/(500+300)
--       输入: 由动因逻辑计算生成（ABC_REL_DRIV_LOGIC + ABC_BSL_OP_WAYBILL）
--       产出: 供 RA 分摊存储过程使用
-- 关键字段:
--   func_code   - 功能中心
--   acti_code   - 作业代码（如 A01=收件作业）
--   car_no      - 车牌（运输车辆作业需要按车区分）
--   driv_code   - 动因代码
--   qty         - 动因量
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RA_DRIV (
  month_code VARCHAR(10) COMMENT '月份',
  dept_code VARCHAR(30) COMMENT '机构代码',
  dept_type VARCHAR(100) COMMENT '机构类型',
  dept_type_name VARCHAR(100) COMMENT '机构类型名',
  func_code VARCHAR(30) COMMENT '功能中心代码',
  func_name VARCHAR(100) COMMENT '功能中心名称',
  acti_code VARCHAR(50) COMMENT '作业代码',
  acti_name VARCHAR(100) COMMENT '作业名',
  car_no VARCHAR(10) COMMENT '车牌',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名称',
  qty DECIMAL(20,6) COMMENT '动因量',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RA动因结果表';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AA_DRIV
-- 用途: AA 分摊动因结果表，存储辅助作业间分摊的动因量
-- 在 ABC 模型中的角色: 动因事实表，是 AA 分摊计算的比例依据
--       例如：调度作业（辅助）按各核心作业的票数分摊成本
--       输入: 由动因逻辑计算生成
--       产出: 供 AA 分摊存储过程使用
-- 关键字段:
--   func_code   - 功能中心
--   acti_code   - 作业代码
--   car_no      - 车牌
--   driv_code   - 动因代码
--   qty         - 动因量
-- 与 RA 动因的区别: AA 动因面向辅助作业间的分摊，RA 面向资源到作业
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AA_DRIV (
  month_code VARCHAR(10) COMMENT '月份',
  dept_code VARCHAR(30) COMMENT '机构代码',
  dept_type VARCHAR(100) COMMENT '机构类型',
  dept_type_name VARCHAR(100) COMMENT '机构类型名',
  func_code VARCHAR(30) COMMENT '功能中心代码',
  func_name VARCHAR(100) COMMENT '功能中心名称',
  acti_code VARCHAR(50) COMMENT '作业代码',
  acti_name VARCHAR(100) COMMENT '作业名',
  car_no VARCHAR(10) COMMENT '车牌',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名称',
  qty DECIMAL(20,6) COMMENT '动因量',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AA动因结果表';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AO_DRIV
-- 用途: AO 分摊动因结果表，存储每个运单在各作业上的动因量
-- 在 ABC 模型中的角色: 动因事实表，是 AO 分摊（最后一步）的比例依据
--       将运单操作记录通过动因逻辑规则转化为每个运单在各作业上的动因量
--       例如：运单 A 在"收件作业"上的动因量=1票、重量=5kg
--       输入: 由动因逻辑计算生成（ABC_REL_DRIV_LOGIC + ABC_BSL_OP_WAYBILL）
--       产出: 供 AO 分摊存储过程使用，最终汇入 ABC_BSL_COST_BASE
-- 关键字段:
--   acti_code   - 作业代码
--   waybill_no  - 运单号（AO 分摊的最终粒度）
--   driv_code   - 动因代码
--   qty         - 动因量（该运单在该作业上的动因贡献值）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AO_DRIV (
  month_code VARCHAR(10) COMMENT '月份',
  dept_code VARCHAR(30) COMMENT '机构代码',
  dept_type VARCHAR(100) COMMENT '机构类型',
  dept_type_name VARCHAR(100) COMMENT '机构类型名',
  func_code VARCHAR(30) COMMENT '功能中心代码',
  func_name VARCHAR(100) COMMENT '功能中心名称',
  acti_code VARCHAR(50) COMMENT '作业代码',
  acti_name VARCHAR(100) COMMENT '作业名',
  car_no VARCHAR(10) COMMENT '车牌',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名称',
  qty DECIMAL(20,6) COMMENT '动因量',
  waybill_no VARCHAR(100) COMMENT '运单号',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AO动因结果表';
