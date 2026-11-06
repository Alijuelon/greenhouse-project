-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: agrisense_db
-- ------------------------------------------------------
-- Server version	8.0.46-0ubuntu0.24.04.4

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `activity_log`
--

DROP TABLE IF EXISTS `activity_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `timestamp` datetime DEFAULT NULL,
  `event_type` varchar(50) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `details` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=843 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ai_model`
--

DROP TABLE IF EXISTS `ai_model`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_model` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) DEFAULT NULL,
  `version` int NOT NULL,
  `W1_json` text NOT NULL,
  `B1_json` text NOT NULL,
  `W2_json` text NOT NULL,
  `B2_json` text NOT NULL,
  `max_out_json` text,
  `r2` float DEFAULT NULL,
  `source` varchar(50) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `device_id` (`device_id`),
  CONSTRAINT `ai_model_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `device_state` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ai_performance`
--

DROP TABLE IF EXISTS `ai_performance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_performance` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(64) NOT NULL,
  `timestamp` datetime DEFAULT NULL,
  `period_start` datetime DEFAULT NULL,
  `period_end` datetime DEFAULT NULL,
  `window_hours` float DEFAULT NULL,
  `stats_json` text,
  `n_samples` int DEFAULT NULL,
  `overall_score` float DEFAULT NULL,
  `verdict` varchar(32) DEFAULT NULL,
  `recommendation` text,
  PRIMARY KEY (`id`),
  KEY `ix_ai_performance_timestamp` (`timestamp`),
  KEY `ix_ai_performance_device_id` (`device_id`),
  CONSTRAINT `ai_performance_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `device_state` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `app_settings`
--

DROP TABLE IF EXISTS `app_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `app_settings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_name` varchar(100) DEFAULT NULL,
  `user_role` varchar(100) DEFAULT NULL,
  `avatar_url` text,
  `wifi_signal` varchar(50) DEFAULT NULL,
  `firmware_version` varchar(50) DEFAULT NULL,
  `ip_address` varchar(50) DEFAULT NULL,
  `api_key` varchar(100) DEFAULT NULL,
  `notif_critical_alert` tinyint(1) DEFAULT NULL,
  `notif_daily_report` tinyint(1) DEFAULT NULL,
  `notif_haptic_feedback` tinyint(1) DEFAULT NULL,
  `notif_high_contrast` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `automation_rule`
--

DROP TABLE IF EXISTS `automation_rule`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `automation_rule` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `sensor_target` varchar(50) DEFAULT NULL,
  `operator` varchar(5) DEFAULT NULL,
  `threshold` float DEFAULT NULL,
  `duration` int DEFAULT NULL,
  `actuator_target` int DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT NULL,
  `last_triggered` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `device_state`
--

DROP TABLE IF EXISTS `device_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `device_state` (
  `id` varchar(50) NOT NULL,
  `air_suhu` float DEFAULT NULL,
  `air_hum` float DEFAULT NULL,
  `tanah_suhu` float DEFAULT NULL,
  `tanah_lembap` float DEFAULT NULL,
  `ph` float DEFAULT NULL,
  `ec` float DEFAULT NULL,
  `n` int DEFAULT NULL,
  `p` int DEFAULT NULL,
  `k` int DEFAULT NULL,
  `soil_ok` tinyint(1) DEFAULT NULL,
  `uptime` int DEFAULT NULL,
  `last_seen` datetime DEFAULT NULL,
  `relay_state_json` text,
  `target_relay_state_json` text,
  `ai_mode` varchar(20) DEFAULT 'off',
  `phase` int DEFAULT '0',
  `ec_setpoint` float DEFAULT '2',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dose_log`
--

DROP TABLE IF EXISTS `dose_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dose_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) DEFAULT NULL,
  `timestamp` datetime DEFAULT NULL,
  `src` varchar(20) DEFAULT NULL,
  `phase` int DEFAULT NULL,
  `x_json` text,
  `ml_json` text,
  `ai_ml_json` text,
  `rating` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `device_id` (`device_id`),
  CONSTRAINT `dose_log_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `device_state` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2393 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `manual_command`
--

DROP TABLE IF EXISTS `manual_command`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `manual_command` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) DEFAULT NULL,
  `pump` varchar(20) DEFAULT NULL,
  `ml` float DEFAULT NULL,
  `queued_at` datetime DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `device_id` (`device_id`),
  CONSTRAINT `manual_command_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `device_state` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `telemetry`
--

DROP TABLE IF EXISTS `telemetry`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `telemetry` (
  `id` int NOT NULL AUTO_INCREMENT,
  `device_id` varchar(50) DEFAULT NULL,
  `timestamp` datetime DEFAULT NULL,
  `air_suhu` float DEFAULT NULL,
  `air_hum` float DEFAULT NULL,
  `tanah_suhu` float DEFAULT NULL,
  `tanah_lembap` float DEFAULT NULL,
  `ph` float DEFAULT NULL,
  `ec` float DEFAULT NULL,
  `n` int DEFAULT NULL,
  `p` int DEFAULT NULL,
  `k` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `device_id` (`device_id`),
  KEY `ix_telemetry_timestamp` (`timestamp`),
  CONSTRAINT `telemetry_ibfk_1` FOREIGN KEY (`device_id`) REFERENCES `device_state` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12014 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'agrisense_db'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-05 15:12:36
