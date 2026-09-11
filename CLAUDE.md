# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

ABC（Activity-Based Costing，作业成本法）财务成本分析系统。将物流企业的间接成本通过四级分摊模型精确分配到每个运单上，支持区部利润、流向利润、客户利润、产品利润等多维度分析。

数据库：Oracle（VARCHAR2、NUMBER、DATE 类型，PL/SQL 存储过程）。

## 四级分摊模型

成本流转路径：**资源 → 资源 → 作业 → 作业 → 运单**

| 阶段 | 缩写 | 含义 | 规则表 | 动因表 | 分摊结果表 | 存储过程 |
|------|------|------|--------|--------|-----------|---------|
| 资源→资源 | RR | 共享资源在各功能中心间分摊 | ABC_REL_RR_DIST | ABC_FCT_RR_DRIV | ABC_FCT_RR_DIST | 7.2-RR分摊程序.prc |
| 资源→作业 | RA | 资源成本分摊到作业 | ABC_REL_RA_DIST | ABC_FCT_RA_DRIV | ABC_FCT_RA_DIST | 7.2-RA分摊程序.prc |
| 作业→作业 | AA | 辅助作业间相互分摊 | ABC_REL_AA_DIST | ABC_FCT_AA_DRIV | ABC_FCT_AA_DIST | 8.2-AA分摊程序.prc |
| 作业→运单 | AO | 作业成本最终分摊到运单 | ABC_REL_AO_DIST | ABC_FCT_AO_DRIV | ABC_FCT_AO_DIST | 8.2-AO分摊程序.prc |

## 文件编号体系与执行顺序

文件按章节编号，每个章节包含建表脚本（*.1）、数据/存储过程（*.2/4.3）、运行脚本（*.3）：

| 章节 | 内容 | 执行顺序 |
|------|------|---------|
| 3.x | 资源维度表、科目资源映射、ODS 科目余额 | 1. 基础数据 |
| 4.x | 机构维表、运单信息、财务成本接口、资源清单 | 2. 业务数据准备 |
| 5.x | 四级分摊规则配置 | 3. 规则配置 |
| 6.x | 四级动因生成 | 4. 动因计算 |
| 7.x | RR 和 RA 分摊 | 5. 前半段分摊 |
| 8.x | AA 和 AO 分摊 + 分摊检测 | 6. 后半段分摊 |
| 9.x | 利润分析查询脚本 | 7. 分析 |
| 10.x | 成本分析基表（汇总最终结果） | 7. 最终汇总 |

运行脚本示例（`10.1-建表脚本.sql` 开头）：
```sql
begin
  p_abc_bsl_cost_base(date '2019-06-01');
end;
```

## 表命名规范

| 前缀 | 用途 | 示例 |
|------|------|------|
| ABC_DIM_ | 维度表 | ABC_DIM_LINE（线路）、ABC_DIM_RESO（资源） |
| ABC_FCT_ | 事实表（动因/分摊结果） | ABC_FCT_RR_DIST、ABC_FCT_AO_DRIV |
| ABC_REL_ | 关系/配置表 | ABC_REL_RR_DIST（分摊规则）、ABC_REL_DRIV_LOGIC（动因逻辑） |
| ABC_BSL_ | 业务分析表 | ABC_BSL_COST_BASE（成本分析基表，最终产出） |
| ODS_ | ODS 层源数据 | ODS_SUBJ_ACCO（科目余额接口表） |
| *_TMP* | 中间临时表 | ABC_FCT_RR_DIST_TMP01/02/03 |

## 关键成本分类

成本按资源代码（reso_code）分为五类，在 `p_abc_bsl_cost_base` 中通过 case when 归集：

| 资源代码 | 成本类型 | 字段 |
|---------|---------|------|
| ZY0201 | 设备成本 | dive_amt |
| ZY0301 | 运输成本 | car_amt |
| ZY0401/ZY0402 | 物料成本 | metr_amt |
| ZY0101 + func=1040 | 管理成本 | mgr_amt |
| ZY0101 + func≠1040 | 人工成本 | pep_amt |

## 最终产出表

**ABC_BSL_COST_BASE**（成本分析基表）：运单粒度的收入与成本匹配表，是利润分析的数据基础。关键字段：月份、区部、运单号、流向、客户、产品、收入、五类成本、总成本。`rn=1` 的记录才计入收入（避免运单重复计收入）。
