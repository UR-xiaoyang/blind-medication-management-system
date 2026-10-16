-- ==========================================
-- 盲人智能用药管理系统 - 数据库初始化脚本
-- ==========================================

CREATE DATABASE IF NOT EXISTS blind_medication
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE blind_medication;

-- 以下是 GORM AutoMigrate 自动建表，此脚本仅做数据库创建
-- 表结构在 Go model 中定义，服务启动时自动迁移

-- 如果需要手动插入初始数据，可取消注释以下内容：

-- 初始化管理员请通过 /api/init-admin 使用现场设置的强密码。
-- 不要在 SQL 文件中保存管理员密码或哈希值。
