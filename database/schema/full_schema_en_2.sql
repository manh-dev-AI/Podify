CREATE DATABASE IF NOT EXISTS podify_db_2
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE podify_db_2;

-- 1. DROP EXISTING TABLES
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

-- 2. USERS TABLE (ID: ND0001..)
CREATE TABLE Users (
    user_id VARCHAR(10) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('listener', 'creator', 'admin')
        NOT NULL DEFAULT 'listener',
    avatar_url VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
);

-- 3. CREATORS TABLE (ID: NST0001..)
CREATE TABLE Creators (
    creator_id VARCHAR(10) PRIMARY KEY,
    user_id VARCHAR(10) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL UNIQUE,
    bio TEXT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE
);

-- 4. PODCAST CHANNELS TABLE (ID: KP0001..)
CREATE TABLE PodcastChannels (
    channel_id VARCHAR(10) PRIMARY KEY,
    creator_id VARCHAR(10) NOT NULL,
    title VARCHAR(200) NOT NULL UNIQUE,
    description TEXT NULL,
    category VARCHAR(50) NOT NULL,
    cover_url VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (creator_id)
        REFERENCES Creators(creator_id) ON DELETE CASCADE
);

-- 5. EPISODES TABLE (ID: EP0001.., EP0099)
CREATE TABLE Episodes (
    episode_id VARCHAR(10) PRIMARY KEY,
    channel_id VARCHAR(10) NOT NULL,
    title VARCHAR(255) NOT NULL UNIQUE,
    description TEXT NULL,
    audio_url VARCHAR(255) NOT NULL,
    duration_seconds INT NOT NULL CHECK (duration_seconds > 0),
    published_at DATETIME NULL,
    status ENUM('draft', 'published', 'archived')
        NOT NULL DEFAULT 'draft',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (channel_id)
        REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE
);

-- 6. SUBSCRIPTIONS TABLE (ID: TD0001..)
CREATE TABLE Subscriptions (
    subscription_id VARCHAR(10) PRIMARY KEY,
    user_id VARCHAR(10) NOT NULL,
    channel_id VARCHAR(10) NOT NULL,
    subscribed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,

    FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (channel_id)
        REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE,
    UNIQUE (user_id, channel_id)
);

-- 7. LISTENING HISTORY TABLE (ID: LS0001..)
CREATE TABLE ListeningHistory (
    history_id VARCHAR(10) PRIMARY KEY,
    user_id VARCHAR(10) NOT NULL,
    episode_id VARCHAR(10) NOT NULL,
    last_position_seconds INT NOT NULL DEFAULT 0 CHECK (last_position_seconds >= 0),
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    listened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE CASCADE
);

-- 8. RATINGS TABLE (ID: DG0001..)
CREATE TABLE Ratings (
    rating_id VARCHAR(10) PRIMARY KEY,
    user_id VARCHAR(10) NOT NULL,
    episode_id VARCHAR(10) NOT NULL,
    score TINYINT NOT NULL,
    comment TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE CASCADE,
    CHECK (score BETWEEN 1 AND 5),
    UNIQUE (user_id, episode_id)
);

-- 9. DONATIONS TABLE (ID: UH0001..)
CREATE TABLE Donations (
    donation_id VARCHAR(10) PRIMARY KEY,
    donor_user_id VARCHAR(10) NOT NULL,
    creator_id VARCHAR(10) NOT NULL,
    amount DECIMAL(12, 0) NOT NULL CHECK (amount > 0),
    message VARCHAR(255) NULL,
    donated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (donor_user_id)
        REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (creator_id)
        REFERENCES Creators(creator_id) ON DELETE CASCADE
);

-- 10. ADVERTISEMENTS TABLE (ID: QC0001..)
CREATE TABLE Advertisements (
    ad_id VARCHAR(10) PRIMARY KEY,
    advertiser_name VARCHAR(150) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    ad_audio_url VARCHAR(255) NULL,
    target_url VARCHAR(255) NULL,
    duration_seconds INT NOT NULL CHECK (duration_seconds > 0),
    status ENUM('active', 'paused', 'archived')
        NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 11. AD CONTRACTS TABLE (ID: HD0001..)
CREATE TABLE AdContracts (
    contract_id VARCHAR(10) PRIMARY KEY,
    ad_id VARCHAR(10) NOT NULL,
    creator_id VARCHAR(10) NOT NULL,
    contract_number VARCHAR(50) NOT NULL UNIQUE,
    contract_value DECIMAL(12, 0) NOT NULL CHECK (contract_value >= 0),
    cpm_rate DECIMAL(10, 0) NOT NULL DEFAULT 0 CHECK (cpm_rate >= 0),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status ENUM('draft', 'active', 'completed', 'cancelled')
        NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CHECK (end_date >= start_date),
    FOREIGN KEY (ad_id)
        REFERENCES Advertisements(ad_id) ON DELETE CASCADE,
    FOREIGN KEY (creator_id)
        REFERENCES Creators(creator_id) ON DELETE CASCADE
);

-- 12. AD SLOTS TABLE (ID: VT0001..)
CREATE TABLE AdSlots (
    slot_id VARCHAR(10) PRIMARY KEY,
    contract_id VARCHAR(10) NOT NULL,
    episode_id VARCHAR(10) NOT NULL,
    slot_position ENUM('pre_roll', 'mid_roll', 'post_roll')
        NOT NULL DEFAULT 'mid_roll',
    start_offset_seconds INT NOT NULL DEFAULT 0 CHECK (start_offset_seconds >= 0),
    status ENUM('scheduled', 'active', 'paused')
        NOT NULL DEFAULT 'active',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (contract_id)
        REFERENCES AdContracts(contract_id) ON DELETE CASCADE,
    FOREIGN KEY (episode_id)
        REFERENCES Episodes(episode_id) ON DELETE CASCADE,
    UNIQUE (contract_id, episode_id, slot_position)
);

-- 13. AD REVENUE TABLE (ID: DT0001..)
CREATE TABLE AdRevenue (
    revenue_id VARCHAR(10) PRIMARY KEY,
    contract_id VARCHAR(10) NOT NULL,
    slot_id VARCHAR(10) NULL,
    recorded_date DATE NOT NULL,
    impressions INT NOT NULL DEFAULT 0 CHECK (impressions >= 0),
    revenue_amount DECIMAL(12, 0) NOT NULL CHECK (revenue_amount >= 0),
    notes VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (contract_id)
        REFERENCES AdContracts(contract_id) ON DELETE CASCADE,
    FOREIGN KEY (slot_id)
        REFERENCES AdSlots(slot_id) ON DELETE SET NULL
);

SHOW TABLES;
