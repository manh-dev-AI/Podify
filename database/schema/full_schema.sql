-- ===================================================================
-- Podify Official Shared Database Schema (MySQL 8.0 - 12 Tables)
-- Managed by Schema Owner: Mạnh (tổng hợp đủ 3 phân hệ)
-- Order of Creation: Module 01 (Content) -> Module 02 (Listening) -> Module 03 (Ads & Analytics)
-- ===================================================================

CREATE DATABASE IF NOT EXISTS podify_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE podify_db;

-- Xóa bảng theo đúng thứ tự đảo ngược phụ thuộc Khóa ngoại (Con trước, Cha sau)
DROP TABLE IF EXISTS Donations;
DROP TABLE IF EXISTS AdRevenue;
DROP TABLE IF EXISTS AdSlots;
DROP TABLE IF EXISTS AdContracts;
DROP TABLE IF EXISTS Advertisements;
DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS ListeningHistory;
DROP TABLE IF EXISTS Subscriptions;
DROP TABLE IF EXISTS Episodes;
DROP TABLE IF EXISTS PodcastChannels;
DROP TABLE IF EXISTS Creators;
DROP TABLE IF EXISTS Users;

-- ===================================================================
-- MODULE 01: CONTENT MANAGEMENT (4 TABLES)
-- ===================================================================

-- 1. Users
CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('user', 'creator', 'admin') NOT NULL DEFAULT 'user',
    avatar_url VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX IDX_Users_CreatedAt (created_at),
    INDEX IDX_Users_Role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Creators (1:0..1 với Users)
CREATE TABLE Creators (
    creator_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    bio TEXT NULL,
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_Creators_Users FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. PodcastChannels (1:N với Creators)
CREATE TABLE PodcastChannels (
    channel_id INT AUTO_INCREMENT PRIMARY KEY,
    creator_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    category VARCHAR(50) NOT NULL,
    cover_image_url VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT FK_Channels_Creators FOREIGN KEY (creator_id)
        REFERENCES Creators(creator_id) ON DELETE CASCADE,
    INDEX IDX_Channels_Creator (creator_id),
    INDEX IDX_Channels_Category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Episodes (1:N với PodcastChannels)
CREATE TABLE Episodes (
    episode_id INT AUTO_INCREMENT PRIMARY KEY,
    channel_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    audio_url VARCHAR(255) NOT NULL,
    duration_seconds INT NOT NULL,
    published_at DATETIME NULL,
    status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Episodes_Duration CHECK (duration_seconds > 0),
    CONSTRAINT FK_Episodes_Channels FOREIGN KEY (channel_id)
        REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE,
    INDEX IDX_Episodes_Channel_Status_Duration (channel_id, status, duration_seconds),
    INDEX IDX_Episodes_PublishedAt (published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- MODULE 02: LISTENING & USER INTERACTION (3 TABLES)
-- ===================================================================

-- 5. Subscriptions
CREATE TABLE Subscriptions (
    subscription_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    channel_id INT NOT NULL,
    subscribed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notify_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT UQ_Subscriptions_User_Channel UNIQUE (user_id, channel_id),
    CONSTRAINT FK_Subscriptions_Users FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT FK_Subscriptions_Channels FOREIGN KEY (channel_id)
        REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE,
    INDEX IDX_Subscriptions_Channel_Date (channel_id, subscribed_at),
    INDEX IDX_Subscriptions_User (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. ListeningHistory
CREATE TABLE ListeningHistory (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    episode_id INT NOT NULL,
    last_position_seconds INT NOT NULL DEFAULT 0,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    listened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT CHK_ListeningHistory_Position CHECK (last_position_seconds >= 0),
    CONSTRAINT FK_History_Users FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT FK_History_Episodes FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE CASCADE,
    INDEX IDX_History_User_Updated (user_id, updated_at),
    INDEX IDX_History_Episode (episode_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Ratings
CREATE TABLE Ratings (
    rating_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    episode_id INT NOT NULL,
    score TINYINT NOT NULL,
    comment TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Ratings_Score CHECK (score BETWEEN 1 AND 5),
    CONSTRAINT UQ_Ratings_User_Episode UNIQUE (user_id, episode_id),
    CONSTRAINT FK_Ratings_Users FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT FK_Ratings_Episodes FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE CASCADE,
    INDEX IDX_Ratings_Episode (episode_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- MODULE 03: ADVERTISEMENT & ANALYTICS (5 TABLES)
-- ===================================================================

-- 8. Advertisements
CREATE TABLE Advertisements (
    ad_id INT AUTO_INCREMENT PRIMARY KEY,
    advertiser_name VARCHAR(150) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    ad_audio_url VARCHAR(255) NULL,
    target_url VARCHAR(255) NULL,
    duration_seconds INT NOT NULL,
    status ENUM('active', 'paused', 'archived') NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Ads_Duration CHECK (duration_seconds > 0),
    INDEX IDX_Ads_Status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. AdContracts
CREATE TABLE AdContracts (
    contract_id INT AUTO_INCREMENT PRIMARY KEY,
    ad_id INT NOT NULL,
    creator_id INT NOT NULL,
    contract_code VARCHAR(50) NOT NULL UNIQUE,
    contract_value DECIMAL(12, 2) NOT NULL,
    cpm_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status ENUM('draft', 'active', 'completed', 'cancelled') NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_AdContracts_Value CHECK (contract_value >= 0),
    CONSTRAINT CHK_AdContracts_Cpm CHECK (cpm_rate >= 0),
    CONSTRAINT CHK_AdContracts_Dates CHECK (end_date >= start_date),
    CONSTRAINT FK_AdContracts_Ads FOREIGN KEY (ad_id)
        REFERENCES Advertisements(ad_id) ON DELETE CASCADE,
    CONSTRAINT FK_AdContracts_Creators FOREIGN KEY (creator_id)
        REFERENCES Creators(creator_id) ON DELETE CASCADE,
    INDEX IDX_AdContracts_Creator_Status (creator_id, status),
    INDEX IDX_AdContracts_Ad (ad_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. AdSlots
CREATE TABLE AdSlots (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    contract_id INT NOT NULL,
    episode_id INT NOT NULL,
    slot_position ENUM('pre-roll', 'mid-roll', 'post-roll') NOT NULL DEFAULT 'mid-roll',
    start_offset_seconds INT NOT NULL DEFAULT 0,
    status ENUM('scheduled', 'active', 'paused') NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_AdSlots_Offset CHECK (start_offset_seconds >= 0),
    CONSTRAINT UQ_AdSlots_Contract_Episode_Pos UNIQUE (contract_id, episode_id, slot_position),
    CONSTRAINT FK_AdSlots_Contracts FOREIGN KEY (contract_id)
        REFERENCES AdContracts(contract_id) ON DELETE CASCADE,
    CONSTRAINT FK_AdSlots_Episodes FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE CASCADE,
    INDEX IDX_AdSlots_Episode (episode_id),
    INDEX IDX_AdSlots_Contract (contract_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. AdRevenue
CREATE TABLE AdRevenue (
    revenue_id INT AUTO_INCREMENT PRIMARY KEY,
    contract_id INT NOT NULL,
    slot_id INT NULL,
    revenue_date DATE NOT NULL,
    impressions INT NOT NULL DEFAULT 0,
    amount DECIMAL(12, 2) NOT NULL,
    notes VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_AdRevenue_Impressions CHECK (impressions >= 0),
    CONSTRAINT CHK_AdRevenue_Amount CHECK (amount >= 0),
    CONSTRAINT FK_AdRevenue_Contracts FOREIGN KEY (contract_id)
        REFERENCES AdContracts(contract_id) ON DELETE CASCADE,
    CONSTRAINT FK_AdRevenue_Slots FOREIGN KEY (slot_id)
        REFERENCES AdSlots(slot_id) ON DELETE SET NULL,
    INDEX IDX_AdRevenue_Contract_Date (contract_id, revenue_date),
    INDEX IDX_AdRevenue_Date (revenue_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Donations
CREATE TABLE Donations (
    donation_id INT AUTO_INCREMENT PRIMARY KEY,
    donor_user_id INT NOT NULL,
    creator_id INT NOT NULL,
    episode_id INT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    message VARCHAR(255) NULL,
    donated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Donations_Amount CHECK (amount > 0),
    CONSTRAINT FK_Donations_Users FOREIGN KEY (donor_user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT FK_Donations_Creators FOREIGN KEY (creator_id)
        REFERENCES Creators(creator_id) ON DELETE CASCADE,
    CONSTRAINT FK_Donations_Episodes FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE SET NULL,
    INDEX IDX_Donations_Creator_Date (creator_id, donated_at),
    INDEX IDX_Donations_Donor (donor_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
