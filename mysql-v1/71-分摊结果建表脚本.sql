-- ============================================================
-- 文件名: 71-分摊结果建表脚本.sql
-- 说明: 四级分摊（RR/RA/AA/AO）的中间结果表和最终结果表
--       每级分摊有 3~4 个 TMP 中间表（分步计算）和 1 个最终结果表
-- 所属阶段: 分摊计算（第5/6步）
-- ============================================================


-- ============================================================
--                      RR 分摊（资源→资源）
-- ============================================================

-- ------------------------------------------------------------
-- 表名: ABC_FCT_RR_DIST_TMP01
-- 用途: RR 分摊中间表（第1步）- 展开分摊规则，匹配发送方和接收方
-- 在 ABC 模型中的角色: 中间临时表，将 ABC_REL_RR_DIST 规则与
--       ABC_FCT_RESO_LIST 资源清单进行关联匹配
--       为后续计算分摊比例做准备
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RR_DIST_TMP01 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RR分摊中间表1-规则展开匹配';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RR_DIST_TMP02
-- 用途: RR 分摊中间表（第2步）- 关联发送方资源金额
-- 在 ABC 模型中的角色: 中间临时表，在 TMP01 基础上关联
--       ABC_FCT_RESO_LIST 获取发送方资源成本金额 fm_amt
-- 关键字段:
--   fm_car      - 发送方车牌（车辆资源需要按车区分）
--   fm_amt      - 发送方资源金额（待分摊的成本）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RR_DIST_TMP02 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RR分摊中间表2-关联发送方金额';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RR_DIST_TMP03
-- 用途: RR 分摊中间表（第3步）- 关联接收方动因量，计算分摊比例
-- 在 ABC 模型中的角色: 中间临时表，关联 ABC_FCT_RR_DRIV 获取动因量
--       计算每个接收方的分摊比例 = qty / all_qty
-- 关键字段:
--   qty         - 接收方动因量（如该功能中心人数=10）
--   all_qty     - 总动因量（如所有功能中心总人数=50）
--   分摊比例 = qty / all_qty
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RR_DIST_TMP03 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  qty DECIMAL(20,6) COMMENT '接收方动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RR分摊中间表3-关联动因量计算比例';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RR_DIST
-- 用途: RR 分摊最终结果表
-- 在 ABC 模型中的角色: RR 分摊的最终产出
--       to_amt = fm_amt × (qty / all_qty) 即分摊金额
--       作为 RA 分摊阶段的输入资源成本
-- 关键字段:
--   fm_amt      - 发送方资源金额（待分摊总额）
--   to_amt      - 分摊到接收方的金额（= fm_amt × qty/all_qty）
--   qty/all_qty - 动因量和总动因量（用于验证分摊比例）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RR_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  month_code CHAR(6) COMMENT '月份',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  qty DECIMAL(20,6) COMMENT '动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量',
  to_amt DECIMAL(20,6) COMMENT '分摊金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RR分摊结果表';


-- ============================================================
--                      RA 分摊（资源→作业）
-- ============================================================

-- ------------------------------------------------------------
-- 表名: ABC_FCT_RA_DIST_TMP01
-- 用途: RA 分摊中间表（第1步）- 展开分摊规则，匹配发送方资源和接收方作业
-- 在 ABC 模型中的角色: 中间临时表，将 ABC_REL_RA_DIST 规则展开
--       匹配发送方功能中心/资源与接收方作业
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RA_DIST_TMP01 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_code VARCHAR(10) COMMENT '接收方作业代码',
  to_acti_name VARCHAR(100) COMMENT '接收方作业名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RA分摊中间表1-规则展开匹配';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RA_DIST_TMP02
-- 用途: RA 分摊中间表（第2步）- 汇总发送方资源金额
-- 在 ABC 模型中的角色: 中间临时表，按网点/功能/资源/车牌汇总
--       RR 分摊后的资源成本金额
-- 关键字段:
--   fm_amt      - 汇总后的发送方资源金额
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RA_DIST_TMP02 (
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_func_code VARCHAR(30) COMMENT '发送方功能中心代码',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方汇总金额'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RA分摊中间表2-发送方金额汇总';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RA_DIST_TMP03
-- 用途: RA 分摊中间表（第3步）- 关联发送方金额和接收方作业信息
-- 在 ABC 模型中的角色: 中间临时表，将 TMP01 的规则匹配结果
--       与 TMP02 的发送方金额关联，并补充车牌信息
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RA_DIST_TMP03 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_car VARCHAR(10) COMMENT '接收方车牌',
  to_acti_code VARCHAR(10) COMMENT '接收方作业代码',
  to_acti_name VARCHAR(100) COMMENT '接收方作业名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RA分摊中间表3-关联金额与作业';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RA_DIST_TMP04
-- 用途: RA 分摊中间表（第4步）- 关联动因量，计算分摊比例
-- 在 ABC 模型中的角色: 中间临时表，关联 ABC_FCT_RA_DRIV 获取动因量
--       计算每个作业的分摊比例 = qty / all_qty
-- 关键字段:
--   qty         - 接收方作业动因量（如收件作业票数=500）
--   all_qty     - 总动因量（如所有作业总票数=800）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RA_DIST_TMP04 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_car VARCHAR(10) COMMENT '接收方车牌',
  to_acti_type_code VARCHAR(10) COMMENT '接收方作业类型代码',
  to_acti_type_name VARCHAR(100) COMMENT '接收方作业类型名称',
  to_acti_code VARCHAR(50) COMMENT '接收方作业代码',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  qty DECIMAL(20,6) COMMENT '接收方动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RA分摊中间表4-关联动因量计算比例';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RA_DIST
-- 用途: RA 分摊最终结果表
-- 在 ABC 模型中的角色: RA 分摊的最终产出
--       to_amt = fm_amt × (qty / all_qty)
--       作为 AA 分摊阶段的输入（作业成本）
-- 关键字段:
--   to_acti_code - 接收方作业代码（成本分摊到了哪个作业）
--   to_amt       - 分摊到该作业的资源成本金额
--   qty/all_qty  - 动因量和总动因量
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_RA_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  month_code CHAR(6) COMMENT '月份',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_car VARCHAR(10) COMMENT '接收方车牌',
  to_acti_type_code VARCHAR(10) COMMENT '接收方作业类型代码',
  to_acti_type_name VARCHAR(100) COMMENT '接收方作业类型名',
  to_acti_code VARCHAR(50) COMMENT '接收方作业代码',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  qty DECIMAL(20,6) COMMENT '动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量',
  to_amt DECIMAL(20,6) COMMENT '分摊金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RA分摊结果表';


-- ============================================================
--                      AA 分摊（作业→作业）
-- ============================================================

-- ------------------------------------------------------------
-- 表名: ABC_FCT_AA_DIST_TMP01
-- 用途: AA 分摊中间表（第1步）- 展开分摊规则，匹配发送方和接收方作业
-- 在 ABC 模型中的角色: 中间临时表，将 ABC_REL_AA_DIST 规则展开
--       匹配发送方辅助作业与接收方核心作业
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AA_DIST_TMP01 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_code VARCHAR(10) COMMENT '发送方作业代码',
  fm_acti_name VARCHAR(100) COMMENT '发送方作业名称',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_code VARCHAR(10) COMMENT '接收方作业代码',
  to_acti_name VARCHAR(100) COMMENT '接收方作业名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AA分摊中间表1-规则展开匹配';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AA_DIST_TMP02
-- 用途: AA 分摊中间表（第2步）- 汇总发送方作业成本
-- 在 ABC 模型中的角色: 中间临时表，按网点/功能/资源/作业/车牌汇总
--       RA 分摊后的作业成本金额
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AA_DIST_TMP02 (
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方汇总金额'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AA分摊中间表2-发送方作业成本汇总';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AA_DIST_TMP03
-- 用途: AA 分摊中间表（第3步）- 关联发送方作业成本和接收方作业信息
-- 在 ABC 模型中的角色: 中间临时表，将 TMP01 的规则与 TMP02 的金额关联
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AA_DIST_TMP03 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '发送方作业类型名称',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_code VARCHAR(10) COMMENT '接收方作业代码',
  to_acti_name VARCHAR(100) COMMENT '接收方作业名称',
  to_car VARCHAR(10) COMMENT '接收方车牌',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AA分摊中间表3-关联作业成本与接收方';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AA_DIST_TMP04
-- 用途: AA 分摊中间表（第4步）- 关联动因量，计算分摊比例
-- 在 ABC 模型中的角色: 中间临时表，关联 ABC_FCT_AA_DRIV 获取动因量
--       计算每个接收方作业的分摊比例 = qty / all_qty
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AA_DIST_TMP04 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '发送方作业类型名称',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_type_code VARCHAR(10) COMMENT '接收方作业类型代码',
  to_acti_type_name VARCHAR(100) COMMENT '接收方作业类型名称',
  to_acti_code VARCHAR(50) COMMENT '接收方作业代码',
  to_car VARCHAR(10) COMMENT '接收方车牌',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  qty DECIMAL(20,6) COMMENT '接收方动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AA分摊中间表4-关联动因量计算比例';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AA_DIST
-- 用途: AA 分摊最终结果表
-- 在 ABC 模型中的角色: AA 分摊的最终产出
--       to_amt = fm_amt × (qty / all_qty)
--       辅助作业成本已分摊到核心作业（收件/派件/运输等）
--       作为 AO 分摊阶段的输入
-- 关键字段:
--   fm_acti_code - 发送方辅助作业代码（如"调度作业""客服作业"）
--   to_acti_code - 接收方核心作业代码（如"收件作业""派件作业"）
--   to_amt       - 分摊到接收方作业的成本金额
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AA_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  month_code CHAR(6) COMMENT '月份',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '发送方作业类型名称',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  to_dept_code VARCHAR(30) COMMENT '接收方网点代码',
  to_dept_name VARCHAR(100) COMMENT '接收方网点名称',
  to_dept_type_code VARCHAR(10) COMMENT '接收方网点类型代码',
  to_dept_type_name VARCHAR(100) COMMENT '接收方网点类型名称',
  to_func_code VARCHAR(10) COMMENT '接收方功能中心代码',
  to_func_name VARCHAR(100) COMMENT '接收方功能中心名称',
  to_reso_code VARCHAR(10) COMMENT '接收方资源代码',
  to_reso_name VARCHAR(100) COMMENT '接收方资源名称',
  to_acti_type_code VARCHAR(10) COMMENT '接收方作业类型代码',
  to_acti_type_name VARCHAR(100) COMMENT '接收方作业类型名',
  to_acti_code VARCHAR(50) COMMENT '接收方作业代码',
  to_car VARCHAR(10) COMMENT '接收方车牌',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  qty DECIMAL(20,6) COMMENT '动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量',
  to_amt DECIMAL(20,6) COMMENT '分摊金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AA分摊结果表';


-- ============================================================
--                      AO 分摊（作业→运单）
-- ============================================================

-- ------------------------------------------------------------
-- 表名: ABC_FCT_AO_DIST_TMP01
-- 用途: AO 分摊中间表（第1步）- 展开分摊规则，获取需要分摊到运单的作业
-- 在 ABC 模型中的角色: 中间临时表，将 ABC_REL_AO_DIST 规则展开
--       匹配需要分摊成本的核心作业（收件/派件/运输等）
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AO_DIST_TMP01 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_code VARCHAR(10) COMMENT '发送方作业代码',
  fm_acti_name VARCHAR(100) COMMENT '发送方作业名称',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AO分摊中间表1-规则展开匹配';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AO_DIST_TMP02
-- 用途: AO 分摊中间表（第2步）- 汇总发送方作业成本
-- 在 ABC 模型中的角色: 中间临时表，按网点/功能/资源/作业/车牌汇总
--       AA 分摊后的核心作业成本金额
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AO_DIST_TMP02 (
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方汇总金额'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AO分摊中间表2-发送方作业成本汇总';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AO_DIST_TMP03
-- 用途: AO 分摊中间表（第3步）- 关联作业成本与分摊规则
-- 在 ABC 模型中的角色: 中间临时表，将 TMP01 的规则与 TMP02 的金额关联
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AO_DIST_TMP03 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '发送方作业类型名称',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AO分摊中间表3-关联作业成本与规则';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AO_DIST_TMP04
-- 用途: AO 分摊中间表（第4步）- 关联运单动因量，计算分摊比例
-- 在 ABC 模型中的角色: 中间临时表，关联 ABC_FCT_AO_DRIV 获取每个运单的动因量
--       计算每个运单的分摊比例 = qty / all_qty
-- 关键字段:
--   waybill_no  - 运单号（分摊的最终粒度）
--   qty         - 该运单的动因量
--   all_qty     - 该作业所有运单的总动因量
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AO_DIST_TMP04 (
  mode_code VARCHAR(10) COMMENT '模型代码',
  fm_dept_code VARCHAR(30) COMMENT '发送方网点代码',
  fm_dept_name VARCHAR(100) COMMENT '发送方网点名称',
  fm_dept_type_code VARCHAR(10) COMMENT '发送方网点类型代码',
  fm_dept_type_name VARCHAR(100) COMMENT '发送方网点类型名称',
  fm_func_code VARCHAR(10) COMMENT '发送方功能中心代码',
  fm_func_name VARCHAR(100) COMMENT '发送方功能中心名称',
  fm_reso_code VARCHAR(10) COMMENT '发送方资源代码',
  fm_reso_name VARCHAR(100) COMMENT '发送方资源名称',
  fm_acti_type_code VARCHAR(10) COMMENT '发送方作业类型代码',
  fm_acti_type_name VARCHAR(100) COMMENT '发送方作业类型名称',
  fm_acti_code VARCHAR(50) COMMENT '发送方作业代码',
  fm_car VARCHAR(10) COMMENT '发送方车牌',
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  waybill_no VARCHAR(100) COMMENT '运单号',
  qty DECIMAL(20,6) COMMENT '运单动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AO分摊中间表4-关联运单动因量';


-- ------------------------------------------------------------
-- 表名: ABC_FCT_AO_DIST
-- 用途: AO 分摊最终结果表 - 四级分摊的最终产出
-- 在 ABC 模型中的角色: AO 分摊的最终产出，是四级分摊模型的最后一步
--       to_amt = fm_amt × (qty / all_qty)，即每个运单分摊到的作业成本
--       该表的数据最终汇入 ABC_BSL_COST_BASE（成本分析基表）
--       按资源代码分类汇总，得到五类成本：设备/运输/物料/管理/人工
-- 关键字段:
--   fm_acti_code - 作业代码（成本来自哪个作业）
--   waybill_no   - 运单号（成本分摊到了哪个运单）
--   to_amt       - 该运单分摊到的成本金额
--   qty/all_qty  - 动因量和总动因量
-- ------------------------------------------------------------
CREATE TABLE ABC_FCT_AO_DIST (
  mode_code VARCHAR(10) COMMENT '模型代码',
  month_code CHAR(6) COMMENT '月份',
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
  fm_amt DECIMAL(20,6) COMMENT '发送方金额',
  dist_type VARCHAR(10) COMMENT '分摊类型',
  driv_code VARCHAR(10) COMMENT '动因代码',
  driv_name VARCHAR(100) COMMENT '动因名',
  waybill_no VARCHAR(100) COMMENT '运单号',
  qty DECIMAL(20,6) COMMENT '动因量',
  all_qty DECIMAL(20,6) COMMENT '总动因量',
  to_amt DECIMAL(20,6) COMMENT '分摊金额',
  load_tm DATETIME COMMENT '加载时间'
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AO分摊结果表';
