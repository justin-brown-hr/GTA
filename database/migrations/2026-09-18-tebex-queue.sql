-- Tebex grant queue — run ONCE on a database created from an older schema.sql.
-- Fresh installs get this from database/schema.sql and should skip this file.
--
--   mysql -u root -p heartless_city < database/migrations/2026-09-18-tebex-queue.sql
--
-- Adds the columns that let a purchase be recorded before the buyer is online,
-- so buying from the website (the normal case) actually delivers a car.

USE `heartless_city`;

ALTER TABLE `hc_tebex_grants`
  ADD COLUMN IF NOT EXISTS `grant_identifier` VARCHAR(80) DEFAULT NULL AFTER `citizenid`,
  ADD COLUMN IF NOT EXISTS `package_id` VARCHAR(64) DEFAULT NULL AFTER `model`,
  ADD COLUMN IF NOT EXISTS `status` VARCHAR(16) NOT NULL DEFAULT 'pending' AFTER `package_id`,
  ADD COLUMN IF NOT EXISTS `delivered_at` TIMESTAMP NULL DEFAULT NULL AFTER `created_at`;

-- Rows written before this migration were delivered immediately by the old
-- code path, so mark them done rather than re-granting those cars on next login.
UPDATE `hc_tebex_grants` SET `status` = 'delivered', `delivered_at` = `created_at`
  WHERE `plate` IS NOT NULL AND `status` = 'pending';

CREATE INDEX IF NOT EXISTS `pending_lookup` ON `hc_tebex_grants` (`status`, `citizenid`);
CREATE INDEX IF NOT EXISTS `pending_identifier` ON `hc_tebex_grants` (`status`, `grant_identifier`);
