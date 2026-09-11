# ABC 四级分摊数据流转教学指南

本文档通过实际 SQL 查询，展示 ABC 成本分摊系统从资源到运单的完整数据流转过程。

**前提条件**：已执行 `mysql-v1/00-创建数据库.sql`，数据库 `abc_blt` 中有完整数据。

---

## 目录

1. [概览：四级分摊模型](#1-概览四级分摊模型)
2. [第 0 步：初始资源数据](#2-第-0-步初始资源数据)
3. [第 1 步：RR 分摊 — 资源 → 资源](#3-第-1-步rr-分摊--资源--资源)
4. [第 2 步：RA 分摊 — 资源 → 作业](#4-第-2-步ra-分摊--资源--作业)
5. [第 3 步：AA 分摊 — 作业 → 作业](#5-第-3-步aa-分摊--作业--作业)
6. [第 4 步：AO 分摊 — 作业 → 运单](#6-第-4-步ao-分摊--作业--运单)
7. [最终产出：成本分析基表](#7-最终产出成本分析基表)
8. [全链路验证查询](#8-全链路验证查询)

---

## 1. 概览：四级分摊模型

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ABC 四级分摊数据流                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  第 0 步：初始资源                                                   │
│    直接归属 50 万 + 共享资源 50 万 = 100 万                         │
│                          ↓                                          │
│  第 1 步：RR 分摊（资源 → 资源）                                     │
│    共享资源按"收派票数"分到各功能中心                                │
│    运输部 50 万 + 分拣部 38 万 + 管理部 12 万 = 100 万              │
│                          ↓                                          │
│  第 2 步：RA 分摊（资源 → 作业）                                     │
│    各部门成本按作业动因分到具体作业                                   │
│    干线 40 万 + 分拣 30 万 + 打包 20 万 + 闲置 5 万 + 管理 5 万    │
│                          ↓                                          │
│  第 3 步：AA 分摊（作业 → 作业）                                     │
│    闲置容量成本转入干线运输                                          │
│    干线 45 万 + 分拣 30 万 + 打包 20 万 + 管理 5 万 = 100 万        │
│                          ↓                                          │
│  第 4 步：AO 分摊（作业 → 运单）                                     │
│    作业成本按重量/票数分到每张运单                                   │
│    跨省件：3.43 元/票  同城件：1.55 元/票                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. 第 0 步：初始资源数据

### 2.1 查看资源清单

```sql
-- 查看所有资源及其类型
SELECT
    reso_code AS 资源代码,
    reso_name AS 资源名称,
    reso_type AS 资源类型
FROM abc_dim_reso
ORDER BY reso_code;
```

**预期结果**：
```
资源代码   资源名称           资源类型
--------  ----------------  --------
ZY0101    人工成本           共享资源
ZY0201    设备成本           共享资源
ZY0301    运输成本           共享资源
ZY0401    物料成本-物料      共享资源
ZY0402    物料成本-物料耗用  共享资源
ZY0501    直接归属成本       直接资源
```

### 2.2 查看各资源的总成本

```sql
-- 各资源科目的余额（来自 ODS 接口表）
SELECT
    subj_code AS 科目代码,
    subj_name AS 科目名称,
    acco_amt AS 科目余额
FROM ods_subj_acco
WHERE year_month = '201906'
ORDER BY subj_code;
```

**关键理解**：
- **共享资源**（ZY0101-ZY0402）：需要通过 RR 分摊到各功能中心
- **直接资源**（ZY0501）：已经可以直接归属到功能中心

### 2.3 查看功能中心（部门）

```sql
-- 查看所有功能中心
SELECT
    func_code AS 功能中心代码,
    func_name AS 功能中心名称,
    func_type AS 类型
FROM abc_dim_func
ORDER BY func_code;
```

**预期结果**：
```
功能中心代码  功能中心名称      类型
------------  ----------------  ----
1010          收件功能中心      运营
1020          派件功能中心      运营
1030          分拣功能中心      运营
1040          管理功能中心      管理
```

---

## 3. 第 1 步：RR 分摊 — 资源 → 资源

### 3.1 RR 分摊的目的

将**共享资源**（如办公楼租金、行政人员工资）按"收派票数"分摊到各功能中心。

**关键规则**：管理部(1040)**不参与** RR 分摊，因为管理部不直接处理运单。

### 3.2 查看 RR 分摊规则

```sql
-- RR 分摊规则配置
SELECT
    reso_code AS 资源代码,
    func_code_from AS 源功能中心,
    func_code_to AS 目标功能中心,
    dist_pct AS 分摊比例
FROM abc_rel_rr_dist
ORDER BY reso_code, func_code_to;
```

**预期结果**（示例）：
```
资源代码   源功能中心  目标功能中心  分摊比例
--------  ----------  ------------  --------
ZY0101    共享池      1010          0.40    ← 收件 40%
ZY0101    共享池      1020          0.30    ← 派件 30%
ZY0101    共享池      1030          0.30    ← 分拣 30%
ZY0101    共享池      1040          0.00    ← 管理不参与 RR
```

### 3.3 查看 RR 动因（收派票数）

```sql
-- RR 动因：各功能中心的收派票数
SELECT
    func_code AS 功能中心,
    driv_qty AS 动因数量,
    driv_pct AS 动因占比
FROM abc_fct_rr_driv
ORDER BY func_code;
```

**关键理解**：
- 动因数量 = 该功能中心处理的收件 + 派件票数
- 占比 = 票数 / 总票数
- 管理部(1040)的动因数量为 0

### 3.4 查看 RR 分摊结果

```sql
-- RR 分摊后，各功能中心获得多少共享资源
SELECT
    reso_code AS 资源代码,
    func_code AS 功能中心,
    dist_amt AS 分摊金额,
    CASE func_code
        WHEN '1010' THEN '收件'
        WHEN '1020' THEN '派件'
        WHEN '1030' THEN '分拣'
        WHEN '1040' THEN '管理'
    END AS 部门名称
FROM abc_fct_rr_dist
ORDER BY reso_code, func_code;
```

### 3.5 验证 RR 分摊平衡

```sql
-- 验证：每类资源的 RR 分摊总额 = 共享资源池总额
SELECT
    r.reso_code AS 资源代码,
    s.subj_amt AS 共享资源池,
    SUM(r.dist_amt) AS 分摊总额,
    s.subj_amt - SUM(r.dist_amt) AS 差异
FROM abc_fct_rr_dist r
JOIN (
    SELECT reso_code, SUM(dist_amt) AS subj_amt
    FROM abc_fct_rr_dist
    GROUP BY reso_code
) s ON r.reso_code = s.reso_code
GROUP BY r.reso_code, s.subj_amt;
```

**预期结果**：差异应该全部为 0。

---

## 4. 第 2 步：RA 分摊 — 资源 → 作业

### 4.1 RA 分摊的目的

将各功能中心的资源成本，按作业动因分摊到具体作业（干线运输、分拣、打包等）。

### 4.2 查看作业清单

```sql
-- 查看所有作业
SELECT
    acti_code AS 作业代码,
    acti_name AS 作业名称,
    func_code AS 所属功能中心
FROM abc_dim_acti
ORDER BY func_code, acti_code;
```

**预期结果**：
```
作业代码   作业名称       所属功能中心
--------  ------------  ------------
AA001     干线运输       1010（收件）
AA002     闲置容量       1010（收件）
AA003     分拣作业       1030（分拣）
AA004     打包作业       1030（分拣）
AA005     管理作业       1040（管理）
```

### 4.3 查看 RA 分摊规则

```sql
-- RA 分摊规则
SELECT
    reso_code AS 资源代码,
    func_code AS 功能中心,
    acti_code AS 目标作业,
    dist_rule AS 分摊规则,
    dist_pct AS 分摊比例
FROM abc_rel_ra_dist
ORDER BY func_code, acti_code;
```

### 4.4 查看 RA 动因

```sql
-- RA 动因：不同作业使用不同动因
SELECT
    acti_code AS 作业代码,
    driv_code AS 动因代码,
    driv_qty AS 动因数量,
    driv_pct AS 动因占比
FROM abc_fct_ra_driv
ORDER BY acti_code;
```

**关键理解**：
- 干线运输(AA001)的动因 = 里程数
- 分拣(AA003)、打包(AA004)的动因 = 加权票数
- 闲置容量(AA002)的动因 = 装载重量

### 4.5 查看 RA 分摊结果

```sql
-- RA 分摊后，各作业获得多少成本
SELECT
    reso_code AS 资源代码,
    acti_code AS 作业代码,
    SUM(dist_amt) AS 分摊金额
FROM abc_fct_ra_dist
GROUP BY reso_code, acti_code
ORDER BY acti_code;
```

### 4.6 按作业汇总 RA 结果

```sql
-- 每个作业的总成本
SELECT
    acti_code AS 作业代码,
    SUM(dist_amt) AS 作业总成本
FROM abc_fct_ra_dist
GROUP BY acti_code
ORDER BY 作业总成本 DESC;
```

**验证**：所有作业成本之和应该等于全公司资源总额（100万）。

---

## 5. 第 3 步：AA 分摊 — 作业 → 作业

### 5.1 AA 分摊的目的

辅助作业（如闲置容量）的成本需要转入主要作业（如干线运输）。

**关键规则**：闲置容量(AA002)的成本全部转入干线运输(AA001)。

### 5.2 查看 AA 分摊规则

```sql
-- AA 分摊规则
SELECT
    acti_code_from AS 源作业,
    acti_code_to AS 目标作业,
    dist_pct AS 分摊比例
FROM abc_rel_aa_dist
ORDER BY acti_code_from;
```

**预期结果**：
```
源作业     目标作业    分摊比例
--------  ----------  --------
AA002     AA001       1.00    ← 闲置容量 100% 转入干线
```

### 5.3 查看 AA 动因

```sql
-- AA 动因：闲置容量按什么转入干线
SELECT
    acti_code_from AS 源作业,
    acti_code_to AS 目标作业,
    driv_code AS 动因代码,
    driv_qty AS 动因数量
FROM abc_fct_aa_driv;
```

### 5.4 查看 AA 分摊结果

```sql
-- AA 分摊结果
SELECT
    acti_code_from AS 源作业,
    acti_code_to AS 目标作业,
    dist_amt AS 分摊金额
FROM abc_fct_aa_dist;
```

### 5.5 AA 分摊后的作业成本

```sql
-- AA 分摊后，各作业的最终成本
-- = RA 分到的成本 + AA 转入的成本 - AA 转出的成本
SELECT
    acti_code AS 作业代码,
    SUM(
        CASE WHEN dist_type = 'RA' THEN dist_amt
             WHEN dist_type = 'AA_IN' THEN dist_amt
             WHEN dist_type = 'AA_OUT' THEN -dist_amt
        END
    ) AS AA后最终成本
FROM (
    -- RA 分摊到的成本
    SELECT acti_code, dist_amt, 'RA' AS dist_type
    FROM abc_fct_ra_dist

    UNION ALL

    -- AA 转入的成本
    SELECT acti_code_to AS acti_code, dist_amt, 'AA_IN' AS dist_type
    FROM abc_fct_aa_dist

    UNION ALL

    -- AA 转出的成本
    SELECT acti_code_from AS acti_code, dist_amt, 'AA_OUT' AS dist_type
    FROM abc_fct_aa_dist
) t
GROUP BY acti_code
ORDER BY 作业代码;
```

**验证**：AA 后各作业成本之和仍然等于 100 万（成本守恒）。

---

## 6. 第 4 步：AO 分摊 — 作业 → 运单

### 6.1 AO 分摊的目的

将作业成本最终分摊到每张运单上，实现"成本可视化"。

### 6.2 查看 AO 动因

```sql
-- AO 动因：运单维度
SELECT
    waybill_no AS 运单号,
    acti_code AS 作业代码,
    driv_code AS 动因代码,
    driv_qty AS 动因数量
FROM abc_fct_ao_driv
LIMIT 20;
```

**关键理解**：
- 干线运输(AA001)的动因 = 运单重量（kg）
- 分拣(AA003)、打包(AA004)的动因 = 运单票数（= 1）
- 管理作业(AA005)的动因 = 运单票数（= 1）

### 6.3 查看 AO 分摊结果

```sql
-- AO 分摊：每张运单分摊到多少作业成本
SELECT
    waybill_no AS 运单号,
    acti_code AS 作业代码,
    dist_amt AS 分摊金额
FROM abc_fct_ao_dist
LIMIT 20;
```

### 6.4 按作业汇总 AO 结果

```sql
-- 验证：每个作业的 AO 分摊总额 = AA 后的作业成本
SELECT
    acti_code AS 作业代码,
    SUM(dist_amt) AS AO分摊总额,
    (SELECT SUM(dist_amt) FROM abc_fct_aa_dist WHERE acti_code_to = a.acti_code)
    + (SELECT SUM(dist_amt) FROM abc_fct_ra_dist WHERE acti_code = a.acti_code)
    - (SELECT SUM(dist_amt) FROM abc_fct_aa_dist WHERE acti_code_from = a.acti_code)
    AS AA后作业成本,
    '差异' AS 差异
FROM abc_fct_ao_dist a
GROUP BY acti_code;
```

### 6.5 按运单汇总总成本

```sql
-- 每张运单的总成本
SELECT
    waybill_no AS 运单号,
    SUM(dist_amt) AS 运单总成本
FROM abc_fct_ao_dist
GROUP BY waybill_no
ORDER BY 运单总成本 DESC
LIMIT 20;
```

### 6.6 按产品类型分析成本

```sql
-- 不同产品类型的平均成本
SELECT
    w.prod_type AS 产品类型,
    COUNT(DISTINCT w.waybill_no) AS 运单数,
    SUM(o.dist_amt) AS 总成本,
    SUM(o.dist_amt) / COUNT(DISTINCT w.waybill_no) AS 平均成本
FROM abc_fct_ao_dist o
JOIN abc_bsl_waybill w ON o.waybill_no = w.waybill_no
GROUP BY w.prod_type;
```

**预期结果**：跨省件的平均成本 > 同城件的平均成本。

---

## 7. 最终产出：成本分析基表

### 7.1 查看成本分析基表结构

```sql
-- 成本分析基表：运单粒度的收入与成本匹配
SELECT
    year_month AS 月份,
    area_code AS 区部代码,
    waybill_no AS 运单号,
    flow_code AS 流向代码,
    cust_code AS 客户代码,
    prod_type AS 产品类型,
    revenue_amt AS 收入金额,
    dive_amt AS 设备成本,
    car_amt AS 运输成本,
    metr_amt AS 物料成本,
    mgr_amt AS 管理成本,
    pep_amt AS 人工成本,
    total_cost AS 总成本,
    profit_amt AS 利润金额
FROM abc_bsl_cost_base
LIMIT 20;
```

### 7.2 理解 rn=1 的含义

```sql
-- 为什么需要 rn=1 才计入收入？
-- 一张运单可能经过多个作业，产生多条记录
SELECT
    waybill_no,
    COUNT(*) AS 记录数,
    SUM(revenue_amt) AS 收入合计,
    MAX(CASE WHEN rn = 1 THEN revenue_amt END) AS rn=1时的收入
FROM abc_bsl_cost_base
GROUP BY waybill_no
HAVING COUNT(*) > 1
LIMIT 10;
```

**关键理解**：
- 一张运单会被分摊到多个作业（干线+分拣+打包+管理）
- 所以 `abc_bsl_cost_base` 中一张运单有多条记录
- 收入只在 `rn=1` 的记录上计一次，避免重复计收
- 成本则分布在多条记录上

### 7.3 区部利润分析

```sql
-- 各区部的利润分析
SELECT
    area_code AS 区部,
    COUNT(DISTINCT CASE WHEN rn = 1 THEN waybill_no END) AS 运单数,
    SUM(CASE WHEN rn = 1 THEN revenue_amt ELSE 0 END) AS 总收入,
    SUM(total_cost) AS 总成本,
    SUM(CASE WHEN rn = 1 THEN revenue_amt ELSE 0 END) - SUM(total_cost) AS 利润,
    (SUM(CASE WHEN rn = 1 THEN revenue_amt ELSE 0 END) - SUM(total_cost))
    / SUM(CASE WHEN rn = 1 THEN revenue_amt ELSE 0 END) * 100 AS 利润率
FROM abc_bsl_cost_base
GROUP BY area_code
ORDER BY 利润 DESC;
```

### 7.4 产品类型利润分析

```sql
-- 各产品类型的利润分析
SELECT
    prod_type AS 产品类型,
    COUNT(DISTINCT CASE WHEN rn = 1 THEN waybill_no END) AS 运单数,
    SUM(CASE WHEN rn = 1 THEN revenue_amt ELSE 0 END) AS 总收入,
    SUM(total_cost) AS 总成本,
    SUM(CASE WHEN rn = 1 THEN revenue_amt ELSE 0 END) - SUM(total_cost) AS 利润
FROM abc_bsl_cost_base
GROUP BY prod_type;
```

### 7.5 客户利润分析

```sql
-- 大客户利润分析（Top 10）
SELECT
    c.cust_name AS 客户名称,
    COUNT(DISTINCT CASE WHEN b.rn = 1 THEN b.waybill_no END) AS 运单数,
    SUM(CASE WHEN b.rn = 1 THEN b.revenue_amt ELSE 0 END) AS 总收入,
    SUM(b.total_cost) AS 总成本,
    SUM(CASE WHEN b.rn = 1 THEN b.revenue_amt ELSE 0 END) - SUM(b.total_cost) AS 利润
FROM abc_bsl_cost_base b
JOIN abc_dim_cust c ON b.cust_code = c.cust_code
GROUP BY c.cust_name
ORDER BY 总收入 DESC
LIMIT 10;
```

---

## 8. 全链路验证查询

### 8.1 验证每级分摊总额守恒

```sql
-- 全链路成本守恒验证
SELECT '第 0 步：初始资源' AS 步骤, SUM(acct_amt) AS 成本总额
FROM ods_subj_acco
WHERE year_month = '201906'

UNION ALL

SELECT '第 1 步：RR 分摊后', SUM(dist_amt)
FROM abc_fct_rr_dist

UNION ALL

SELECT '第 2 步：RA 分摊后', SUM(dist_amt)
FROM abc_fct_ra_dist

UNION ALL

SELECT '第 3 步：AA 分摊后', SUM(dist_amt)
FROM abc_fct_aa_dist

UNION ALL

SELECT '第 4 步：AO 分摊后', SUM(dist_amt)
FROM abc_fct_ao_dist;
```

**预期结果**：所有步骤的成本总额应该相等（都是 100 万）。

### 8.2 验证 AO 分摊与成本基表一致

```sql
-- AO 分摊总额 vs 成本基表总成本
SELECT
    'AO 分摊表' AS 来源,
    SUM(dist_amt) AS 总成本
FROM abc_fct_ao_dist

UNION ALL

SELECT
    '成本分析基表',
    SUM(total_cost)
FROM abc_bsl_cost_base;
```

**预期结果**：两个数字应该相等。

---

## 附录：关键概念速查

### A. 功能中心 vs 作业

| 概念 | 含义 | 示例 |
|------|------|------|
| **功能中心** | 部门 | 收件部、派件部、分拣部、管理部 |
| **作业** | 具体工作内容 | 干线运输、分拣、打包、管理 |

### B. 四级分摊速记

| 步骤 | 方向 | 动因 | 说明 |
|------|------|------|------|
| **RR** | 共享资源 → 部门 | 收派票数 | 谁处理的运单多，谁分摊的共享成本多 |
| **RA** | 部门 → 作业 | 里程/加权票数 | 运输按里程，分拣/打包按票数 |
| **AA** | 辅助作业 → 主要作业 | 装载重量 | 闲置容量成本转入干线 |
| **AO** | 作业 → 运单 | 重量/票数 | 最终分到每张运单 |

### C. 成本类型对应关系

| 资源代码 | 成本类型 | 基表字段 |
|---------|---------|---------|
| ZY0201 | 设备成本 | dive_amt |
| ZY0301 | 运输成本 | car_amt |
| ZY0401/ZY0402 | 物料成本 | metr_amt |
| ZY0101 + func=1040 | 管理成本 | mgr_amt |
| ZY0101 + func≠1040 | 人工成本 | pep_amt |

---

## 学习建议

1. **按顺序执行**：从第 0 步到第 4 步，逐步执行 SQL，观察数据变化
2. **关注总额**：每一步都要验证成本总额不变（成本守恒）
3. **对比动因**：注意不同层级使用的动因不同
4. **理解 rn=1**：成本基表中收入只在 rn=1 记录上计一次

---

*文档版本：v1.0*
*适用数据库：abc_blt (MySQL)*
