-- P0 hardening migration — run this ONCE against a database that was already
-- created from an older schema.sql (i.e. the live VPS). Fresh installs get all
-- of this from database/schema.sql and should skip this file.
--
--   mysql -u root -p heartless_city < database/migrations/2026-09-18-p0-hardening.sql

USE `heartless_city`;

-- Money audit trail written by hc-core/server/security.lua
CREATE TABLE IF NOT EXISTS `hc_transaction_log` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) DEFAULT NULL,
  `player_name` VARCHAR(64) DEFAULT NULL,
  `category` VARCHAR(64) NOT NULL,
  `amount` BIGINT NOT NULL DEFAULT 0,
  `detail` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`),
  KEY `category` (`category`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Heist cooldown lookup index (MariaDB supports IF NOT EXISTS here; on MySQL 8
-- drop the IF NOT EXISTS and ignore a duplicate-key-name error on re-run).
CREATE INDEX IF NOT EXISTS `hc_heist_cooldowns_lookup`
  ON `hc_heist_cooldowns` (`citizenid`, `heist_key`, `expires_at`);

-- Plates must be unique: hc-dealership now retries until it finds a free plate,
-- but the database is what actually guarantees it.
-- Check for existing duplicates first:
--   SELECT plate, COUNT(*) c FROM player_vehicles GROUP BY plate HAVING c > 1;
-- Resolve any rows that come back, then:
-- ALTER TABLE `player_vehicles` ADD UNIQUE KEY `plate_unique` (`plate`);
