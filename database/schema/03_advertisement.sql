-- ===================================================================
-- Module 03: Advertisement & Analytics
-- Owner: Member 3 - Quang (Integration Coordinator)
-- DBMS: MySQL 8.0
-- Tables: Advertisements, AdContracts, AdSlots, AdRevenue, Donations
-- ===================================================================

USE podify_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Donations;
DROP TABLE IF EXISTS AdRevenue;
DROP TABLE IF EXISTS AdSlots;
DROP TABLE IF EXISTS AdContracts;
DROP TABLE IF EXISTS Advertisements;
SET FOREIGN_KEY_CHECKS = 1;

-- 8. Bảng Advertisements: Danh mục mẫu quảng cáo và đơn vị quảng cáo
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

-- 9. Bảng AdContracts: Thỏa thuận thương mại giữa Creator và Quảng cáo
CREATE TABLE AdContracts (
    contract_id INT AUTO_INCREMENT PRIMARY KEY,
    ad_id INT NOT NULL,
    creator_id INT NOT NULL,
    contract_code VARCHAR(50) NOT NULL UNIQUE,
    contract_value DECIMAL(12, 2) NOT NULL,
    cpm_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00, -- Chi phí trên 1000 lượt nghe (VNĐ)
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

-- 10. Bảng AdSlots: Vị trí chèn quảng cáo (từ AdContracts) vào từng Episode cụ thể
CREATE TABLE AdSlots (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    contract_id INT NOT NULL,
    episode_id INT NOT NULL,
    slot_position ENUM('pre-roll', 'mid-roll', 'post-roll') NOT NULL DEFAULT 'mid-roll',
    start_offset_seconds INT NOT NULL DEFAULT 0, -- Thời điểm chèn trong Episode (giây)
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

-- 11. Bảng AdRevenue: Ghi nhận doanh thu quảng cáo theo hợp đồng/vị trí và ngày
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

-- 12. Bảng Donations: Lịch sử ủng hộ tài chính từ User tới Creator
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
