CREATE DATABASE IF NOT EXISTS `nutrition`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `nutrition`;

CREATE TABLE IF NOT EXISTS `sports` (
  `sport_id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `description` TEXT NULL,
  PRIMARY KEY (`sport_id`),
  UNIQUE KEY `uq_sports_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `athletes` (
  `athlete_id` INT NOT NULL AUTO_INCREMENT,
  `first_name` VARCHAR(100) NOT NULL,
  `last_name` VARCHAR(100) NOT NULL,
  `birth_date` DATE NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  `email` VARCHAR(150) NOT NULL,
  `height_cm` SMALLINT NOT NULL,
  `weight_kg` DECIMAL(5,2) NOT NULL,
  `sport_id` INT NOT NULL,
  PRIMARY KEY (`athlete_id`),
  UNIQUE KEY `uq_athletes_email` (`email`),
  KEY `idx_athletes_sport_id` (`sport_id`),
  CONSTRAINT `fk_athletes_sports` FOREIGN KEY (`sport_id`)
    REFERENCES `sports` (`sport_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `competitions` (
  `competition_id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(200) NOT NULL,
  `location` VARCHAR(200) NOT NULL,
  `start_date` DATE NOT NULL,
  `end_date` DATE NOT NULL,
  `sport_id` INT NOT NULL,
  PRIMARY KEY (`competition_id`),
  KEY `idx_competitions_sport_id` (`sport_id`),
  CONSTRAINT `fk_competitions_sports` FOREIGN KEY (`sport_id`)
    REFERENCES `sports` (`sport_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `competition_participation` (
  `participation_id` INT NOT NULL AUTO_INCREMENT,
  `competition_id` INT NOT NULL,
  `athlete_id` INT NOT NULL,
  `role` VARCHAR(100) NOT NULL,
  `result` VARCHAR(200) NOT NULL,
  PRIMARY KEY (`participation_id`),
  KEY `idx_participation_competition_id` (`competition_id`),
  KEY `idx_participation_athlete_id` (`athlete_id`),
  CONSTRAINT `fk_participation_competitions` FOREIGN KEY (`competition_id`)
    REFERENCES `competitions` (`competition_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_participation_athletes` FOREIGN KEY (`athlete_id`)
    REFERENCES `athletes` (`athlete_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
