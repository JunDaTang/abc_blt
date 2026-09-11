-- ============================================================
-- 文件名: 00-创建数据库.sql
-- 说明: 创建 ABC 成本分析系统的 MySQL 数据库实例
-- 所属阶段: 基础数据（环境初始化）
-- ============================================================

-- 创建数据库，使用 utf8mb4 字符集以支持中文存储
CREATE DATABASE IF NOT EXISTS abc_blt DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE abc_blt;
