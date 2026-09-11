-- ============================================================
-- 文件名: 31-资源建表脚本.sql
-- 说明: 资源清单、科目资源映射、ODS 科目余额、资源维度表
--       属于 ABC 四级分摊模型的数据基础，为后续分摊提供资源分类和财务数据来源
-- 所属阶段: 基础数据（第1步）
-- ============================================================


-- ------------------------------------------------------------
-- 表名: ABC_FCT_RESO_LIST
-- 用途: 存储各机构各功能中心的资源清单及金额，是资源成本数据的起点
-- 在 ABC 模型中的角色: 基础事实表，由 ODS 源数据加工而来，
--       供 RR 分摊阶段作为发送方资源成本的来源
-- 关键字段:
--   month_code  - 月份（如 201906）
--   dept_code   - 机构代码
--   func_code   - 功能中心代码（如 1040=派送）
--   reso_code   - 资源代码（如 ZY0101=人工、ZY0201=设备、ZY0301=运输）
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
-- 表名: ABC_REL_SUBJ_RESO
-- 用途: 配置会计科目与资源代码的映射关系，用于将财务科目余额转换为资源成本
-- 在 ABC 模型中的角色: 规则配置表，在 ODS 科目余额→资源成本转换时使用
--       是科目余额归集到资源的关键桥梁
-- 关键字段:
--   subj_code   - 会计科目代码（如 6601=管理费用）
--   subj_name   - 科目名称
--   reso_code   - 映射到的资源代码（如 ZY0101=人工成本）
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
-- 表名: ODS_SUBJ_ACCO
-- 用途: ODS 层源数据表，存储从财务系统接口获取的科目余额明细
-- 在 ABC 模型中的角色: 原始数据入口，是四级分摊模型的源头数据
--       通过 ABC_REL_SUBJ_RESO 映射后形成资源成本
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
-- 表名: ABC_DIM_RESO
-- 用途: 资源维度表，定义资源的层级结构（如人工成本→基本工资/社保/公积金）
-- 在 ABC 模型中的角色: 维度表，贯穿整个四级分摊模型
--       所有分摊规则表和结果表中的 reso_code 都引用此表
-- 关键字段:
--   reso_code   - 资源代码（最细粒度）
--   reso_name   - 资源名称
--   l1_reso_code/l1_reso_name - 一级资源分类（如"人工成本"）
--   l2_reso_code/l2_reso_name - 二级资源分类（如"基本工资"）
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
