-- Heartless City RP — base schema extensions
-- Import AFTER qb-core / ox_inventory tables exist (or adapt to your qb SQL dump).

CREATE DATABASE IF NOT EXISTS `heartless_city` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `heartless_city`;

-- Purchasable businesses
CREATE TABLE IF NOT EXISTS `hc_businesses` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `business_key` VARCHAR(64) NOT NULL,
  `label` VARCHAR(128) NOT NULL,
  `owner_citizenid` VARCHAR(50) DEFAULT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `balance` INT NOT NULL DEFAULT 0,
  `employees` LONGTEXT DEFAULT NULL,
  `metadata` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `business_key` (`business_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Exclusive Tebex vehicle grants log
CREATE TABLE IF NOT EXISTS `hc_tebex_grants` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `transaction_id` VARCHAR(128) NOT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `model` VARCHAR(64) NOT NULL,
  `plate` VARCHAR(16) DEFAULT NULL,
  `payload` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `transaction_id` (`transaction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Heist cooldowns
CREATE TABLE IF NOT EXISTS `hc_heist_cooldowns` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `heist_key` VARCHAR(64) NOT NULL,
  `citizenid` VARCHAR(50) DEFAULT NULL,
  `expires_at` TIMESTAMP NOT NULL,
  PRIMARY KEY (`id`),
  KEY `heist_key` (`heist_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed example businesses (owner NULL = for sale)
INSERT INTO `hc_businesses` (`business_key`, `label`, `price`, `balance`) VALUES
  ('ls_customs', 'Heartless Customs', 250000, 0),
  ('vinewood_bar', 'Vinewood Pour House', 175000, 0),
  ('grove_247', 'Grove 24/7', 120000, 0),
  ('mirror_gunlease', 'Mirror Park Armory Lease', 300000, 0)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);
