-- ===================================================================
-- Module 02: Listening & User Interaction
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- Tables: Subscriptions, ListeningHistory, Ratings
-- ===================================================================

USE podify_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS ListeningHistory;
DROP TABLE IF EXISTS Subscriptions;
SET FOREIGN_KEY_CHECKS = 1;

-- 5. Bảng Subscriptions: Theo dõi kênh Podcast (Ràng buộc UNIQUE chống đăng ký trùng)
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

-- 6. Bảng ListeningHistory: Lưu lịch sử lượt nghe & tiến trình phát (Continue Listening)
CREATE TABLE ListeningHistory (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    episode_id INT NOT NULL,
    last_position_seconds INT NOT NULL DEFAULT 0, -- Vị trí dừng tính bằng giây
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

-- 7. Bảng Ratings: Đánh giá Episode (CHECK score 1..5, mỗi user 1 đánh giá/tập)
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
