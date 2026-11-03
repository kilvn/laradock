-- New API 初始化（在 laradock-mariadb-1 容器里执行）
-- 密码从 laradock/.env 的 NEW_API_DB_PASSWORD 取，不要在这里写死真实值
--
-- 用法：
--   ROOTPW=$(grep '^MARIADB_ROOT_PASSWORD=' ../.env | cut -d= -f2-)
--   docker exec -i laradock-mariadb-1 mariadb -uroot -p"$ROOTPW" < init.sql
--
-- 说明：New API 官方要求 MySQL >= 5.7.8；本机是 MariaDB 13，属未正式支持组合，
-- 启动后必须确认迁移日志无报错。

CREATE DATABASE IF NOT EXISTS new_api
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

CREATE USER IF NOT EXISTS 'newapi'@'%' IDENTIFIED BY '__NEW_API_DB_PASSWORD__';
ALTER USER 'newapi'@'%' IDENTIFIED BY '__NEW_API_DB_PASSWORD__';

GRANT ALL PRIVILEGES ON new_api.* TO 'newapi'@'%';
FLUSH PRIVILEGES;

SHOW DATABASES LIKE 'new_api';
