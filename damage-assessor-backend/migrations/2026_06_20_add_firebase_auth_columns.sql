-- Migration: add Firebase auth + trial/subscription columns to users table.
-- Run this against your existing the `damage_assessor` database.
-- Adjust table/column names if your existing `users` table differs.

ALTER TABLE users
  ADD COLUMN firebase_uid VARCHAR(128) NULL UNIQUE AFTER id,
  ADD COLUMN phone VARCHAR(20) NULL AFTER firebase_uid,
  ADD COLUMN free_report_used TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN subscription_status ENUM('none', 'active', 'expired', 'grace') NOT NULL DEFAULT 'none',
  ADD COLUMN subscription_expires_at DATETIME NULL;

-- Index for fast lookup on login (every auth request hits this).
CREATE INDEX idx_users_firebase_uid ON users (firebase_uid);
