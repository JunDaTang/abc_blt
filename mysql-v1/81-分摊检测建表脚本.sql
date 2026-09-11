-- ============================================================
-- 文件名: 81-分摊检测建表脚本.sql
-- 说明: 分摊检测结果表和未分摊明细表，用于验证四级分摊的完整性
--       检测分摊前后金额是否平衡，以及列出未能成功分摊的成本项
-- 所属阶段: 检测（第6步之后）
-- ============================================================


-- ------------------------------------------------------------
-- 表名: ABC_FCT_CHK_DIST
-- 用途: 分摊检测结果表，记录每级分摊的金额汇总，用于校验分摊平衡
-- 在 ABC 模型中的角色: 检测表，在 RR/RA/AA/AO 每级分摊完成后记录
--       发送方总额和接收方总额，验证两者是否相等（分摊平衡检测）
--       如果发送方总额 ≠ 接收方总额，说明存在分摊异常
-- 关键字段:
--   dist_type   - 分摊类型（RR/RA/AA/AO）
--   dist_step   - 分摊步骤序号
--   amt         - 该步骤的金额（发送方或接收方汇总）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_CHK_DIST (
  month_code CHAR(6) COMMENT '月份',
  dist_type CHAR(2) COMMENT '分摊类型',
  dist_step DECIMAL(20,6) COMMENT '分摊步骤',
  amt DECIMAL(20,6) COMMENT '金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分摊检测结果表';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_NO_DIST_LIST
-- 用途: 未分摊明细表，记录未能成功分摊到下游的成本项
-- 在 ABC 模型中的角色: 异常检测表，列出分摊过程中"挂起"的成本
--       即发送方有成本，但找不到匹配的接收方（缺少动因或规则）
--       这些成本需要人工核查，可能是规则配置遗漏或动因数据缺失
-- 关键字段:
--   dist_type   - 分摊类型（RR/RA/AA/AO，标识哪一级分摊异常）
--   fm_dept_code/fm_func_code/fm_reso_code - 发送方定位（哪个网点的哪个资源的成本未分摊）
--   fm_acti_code - 作业代码（AA/AO 级别时标识哪个作业）
--   driv_code   - 动因代码（标识缺少哪种动因）
--   amt         - 未分摊的金额
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_NO_DIST_LIST (
  month_code CHAR(6) COMMENT '月份',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  fm_dept_code VARCHAR(30) COMMENT '网点代码',
  fm_dept_name VARCHAR(100) COMMENT '网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '资源代码',
  fm_reso_name VARCHAR(100) COMMENT '资源名称',
  fm_acti_type_code VARCHAR(10) COMMENT '作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '作业类型名称',
  fm_acti_code VARCHAR(50) COMMENT '作业',
  fm_car VARCHAR(10) COMMENT '车牌',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  amt DECIMAL(20,6) COMMENT '金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='未分摊明细';
