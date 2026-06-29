-- Run this FIRST if the `users` table doesn't exist yet in your `damage_assessor` DB.
-- If you already have a users table from existing the work,
-- SKIP this file and only run 2026_06_20_add_firebase_auth_columns.sql,
-- adjusting it if any of these columns already exist under different names.

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  firebase_uid VARCHAR(128) NULL UNIQUE,
  phone VARCHAR(20) NULL,
  name VARCHAR(255) NULL,
  email VARCHAR(255) NULL,
  company VARCHAR(255) NULL,
  free_report_used TINYINT(1) NOT NULL DEFAULT 0,
  subscription_status ENUM('none', 'active', 'expired', 'grace') NOT NULL DEFAULT 'none',
  subscription_expires_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_firebase_uid ON users (firebase_uid);
