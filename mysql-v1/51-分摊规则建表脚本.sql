-- ============================================================
-- 文件名: 51-分摊规则建表脚本.sql
-- 说明: 四级分摊规则配置表（RR/RA/AA/AO），定义每个分摊阶段的
--       发送方→接收方映射关系、使用的动因类型和分摊方式
-- 所属阶段: 规则配置（第3步）
-- ============================================================


-- ------------------------------------------------------------
-- 表名: ABC_REL_RR_DIST
-- 用途: RR（资源→资源）分摊规则配置表
--       定义共享资源在各功能中心之间的分摊方式
-- 在 ABC 模型中的角色: 规则配置表，是 RR 分摊阶段的驱动配置
--       决定哪些资源从哪个功能中心分摊到哪些目标功能中心
--       输入: ABC_FCT_RESO_LIST（资源清单）
--       产出: ABC_FCT_RR_DIST（RR 分摊结果）
-- 关键字段:
--   fm_func_code/fm_reso_code - 发送方功能中心和资源（成本来源）
--   to_func_code/to_reso_code - 接收方功能中心和资源（成本去向）
--   driv_code                 - 使用的动因代码（如人数、面积）
--   dist_type                 - 分摊类型（直接/比例）
-- ------------------------------------------------------------
CREATE TABLE ABC_REL_RR_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dt DATETIME COMMENT '开始日期',
  to_dt DATETIME COMMENT '结束日期',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC模型RR分摊规则';


-- ------------------------------------------------------------
-- 表名: ABC_REL_RA_DIST
-- 用途: RA（资源→作业）分摊规则配置表
--       定义功能中心内的资源成本如何分摊到具体作业上
-- 在 ABC 模型中的角色: 规则配置表，是 RA 分摊阶段的驱动配置
--       将功能中心归集的资源成本（含 RR 分摊后的结果）分配到各作业
--       输入: ABC_FCT_RR_DIST（RR 分摊结果）
--       产出: ABC_FCT_RA_DIST（RA 分摊结果）
-- 关键字段:
--   fm_func_code/fm_reso_code - 发送方功能中心和资源
--   to_acti_code              - 接收方作业代码（如"收件作业""派件作业"）
--   driv_code                 - 使用的动因代码
--   dist_type                 - 分摊类型
-- 与 RR 规则的区别: RA 规则的接收方多了作业维度（to_acti_code）
-- ------------------------------------------------------------
CREATE TABLE ABC_REL_RA_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dt DATETIME COMMENT '开始日期',
  to_dt DATETIME COMMENT '结束日期',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_code VARCHAR(10) COMMENT '接收方作业代码',
  to_acti_name VARCHAR(100) COMMENT '接收方作业名称',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC模型RA分摊规则';


-- ------------------------------------------------------------
-- 表名: ABC_REL_AA_DIST
-- 用途: AA（作业→作业）分摊规则配置表
--       定义辅助作业的成本如何分摊到其他作业上
-- 在 ABC 模型中的角色: 规则配置表，是 AA 分摊阶段的驱动配置
--       辅助作业（如调度、客服）的成本需要分摊到核心作业（收件/派件/运输）
--       输入: ABC_FCT_RA_DIST（RA 分摊结果）
--       产出: ABC_FCT_AA_DIST（AA 分摊结果）
-- 关键字段:
--   fm_acti_code - 发送方辅助作业代码
--   to_acti_code - 接收方核心作业代码
--   driv_code    - 使用的动因代码
-- 与 RA 规则的区别: AA 规则的发送方和接收方都是作业维度
-- ------------------------------------------------------------
CREATE TABLE ABC_REL_AA_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dt DATETIME COMMENT '开始日期',
  to_dt DATETIME COMMENT '结束日期',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_code VARCHAR(10) COMMENT '发送方作业代码',
  fm_acti_name VARCHAR(100) COMMENT '发送方作业名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_code VARCHAR(10) COMMENT '接收方作业代码',
  to_acti_name VARCHAR(100) COMMENT '接收方作业名称',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC模型AA分摊规则';


-- ------------------------------------------------------------
-- 表名: ABC_REL_AO_DIST
-- 用途: AO（作业→运单）分摊规则配置表
--       定义作业成本如何最终分摊到每个运单上
-- 在 ABC 模型中的角色: 规则配置表，是 AO 分摊阶段的驱动配置
--       这是四级分摊的最后一步，将作业成本按动因分配到运单
--       输入: ABC_FCT_AA_DIST（AA 分摊结果）
--       产出: ABC_FCT_AO_DIST（AO 分摊结果）→ 最终汇入 ABC_BSL_COST_BASE
-- 关键字段:
--   fm_acti_code - 发送方作业代码（如"收件作业""运输作业"）
--   driv_code    - 使用的动因代码（如票数、重量）
-- 与 AA 规则的区别: AO 规则没有接收方，因为运单在动因表中匹配
-- ------------------------------------------------------------
CREATE TABLE ABC_REL_AO_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dt DATETIME COMMENT '开始日期',
  to_dt DATETIME COMMENT '结束日期',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_code VARCHAR(10) COMMENT '发送方作业代码',
  fm_acti_name VARCHAR(100) COMMENT '发送方作业名称',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='ABC模型AO分摊规则';
