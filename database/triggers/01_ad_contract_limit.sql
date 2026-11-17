-- ===================================================================
-- Business Rule Triggers: Module 03 (Advertisement & Analytics)
-- Owner: Member 3 - Quang
-- DBMS: MySQL 8.0
-- Rule:
--   1. Mỗi Episode có thời lượng dưới 20 phút (< 1200 giây) chỉ được gắn
--      tối đa 3 hợp đồng quảng cáo (AdContracts) khác nhau thông qua AdSlots.
--   2. Hợp đồng quảng cáo chỉ được gắn vào Episode thuộc cùng Creator.
--   3. Thời điểm chèn quảng cáo (start_offset_seconds) không vượt quá thời lượng Episode.
--   4. Khi giảm duration_seconds của Episode xuống < 1200s, không cho phép
--      nếu Episode đó đang gắn > 3 hợp đồng khác nhau.
-- ===================================================================

USE podify_db;

DROP TRIGGER IF EXISTS TRG_AdSlots_Limit_Contracts_BI;
DROP TRIGGER IF EXISTS TRG_AdSlots_Limit_Contracts_BU;
DROP TRIGGER IF EXISTS TRG_Episodes_Duration_Limit_BU;

DELIMITER $$

CREATE TRIGGER TRG_AdSlots_Limit_Contracts_BI
BEFORE INSERT ON AdSlots
FOR EACH ROW
BEGIN
    DECLARE v_duration_seconds INT;
    DECLARE v_episode_creator_id INT;
    DECLARE v_contract_creator_id INT;
    DECLARE v_distinct_contracts INT DEFAULT 0;
    DECLARE v_contract_already_on_ep INT DEFAULT 0;

    -- Lấy thông tin thời lượng Episode và Creator sở hữu Channel chứa Episode đó
    SELECT e.duration_seconds, c.creator_id
    INTO v_duration_seconds, v_episode_creator_id
    FROM Episodes e
    INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
    WHERE e.episode_id = NEW.episode_id;

    -- Lấy Creator sở hữu AdContract
    SELECT ac.creator_id
    INTO v_contract_creator_id
    FROM AdContracts ac
    WHERE ac.contract_id = NEW.contract_id;

    -- Kiểm tra tính đồng nhất Creator giữa Hợp đồng và Episode
    IF v_episode_creator_id IS NOT NULL AND v_contract_creator_id IS NOT NULL
       AND v_episode_creator_id <> v_contract_creator_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: Hop dong quang cao chi duoc gan vao Episode thuoc cung Creator.';
    END IF;

    -- Kiểm tra thời điểm chèn quảng cáo không vượt quá tổng thời lượng Episode
    IF v_duration_seconds IS NOT NULL AND NEW.start_offset_seconds > v_duration_seconds THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: Vi tri quang cao (start_offset_seconds) vuot qua thoi luong Episode.';
    END IF;

    -- Quy tắc chính: Episode < 20 phút (< 1200 giây) tối đa 3 AdContracts khác nhau
    IF v_duration_seconds IS NOT NULL AND v_duration_seconds < 1200 THEN
        SELECT
            COUNT(DISTINCT contract_id),
            COALESCE(MAX(CASE WHEN contract_id = NEW.contract_id THEN 1 ELSE 0 END), 0)
        INTO v_distinct_contracts, v_contract_already_on_ep
        FROM AdSlots
        WHERE episode_id = NEW.episode_id;

        IF v_contract_already_on_ep = 0 AND v_distinct_contracts >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Business Rule Violation: Episode duoi 20 phut (< 1200s) chi duoc gan toi da 3 hop dong quang cao.';
        END IF;
    END IF;
END$$

CREATE TRIGGER TRG_AdSlots_Limit_Contracts_BU
BEFORE UPDATE ON AdSlots
FOR EACH ROW
BEGIN
    DECLARE v_duration_seconds INT;
    DECLARE v_episode_creator_id INT;
    DECLARE v_contract_creator_id INT;
    DECLARE v_distinct_contracts INT DEFAULT 0;
    DECLARE v_contract_already_on_ep INT DEFAULT 0;

    SELECT e.duration_seconds, c.creator_id
    INTO v_duration_seconds, v_episode_creator_id
    FROM Episodes e
    INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
    WHERE e.episode_id = NEW.episode_id;

    SELECT ac.creator_id
    INTO v_contract_creator_id
    FROM AdContracts ac
    WHERE ac.contract_id = NEW.contract_id;

    IF v_episode_creator_id IS NOT NULL AND v_contract_creator_id IS NOT NULL
       AND v_episode_creator_id <> v_contract_creator_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: Hop dong quang cao chi duoc gan vao Episode thuoc cung Creator.';
    END IF;

    IF v_duration_seconds IS NOT NULL AND NEW.start_offset_seconds > v_duration_seconds THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Business Rule Violation: Vi tri quang cao (start_offset_seconds) vuot qua thoi luong Episode.';
    END IF;

    IF v_duration_seconds IS NOT NULL AND v_duration_seconds < 1200 THEN
        SELECT
            COUNT(DISTINCT contract_id),
            COALESCE(MAX(CASE WHEN contract_id = NEW.contract_id THEN 1 ELSE 0 END), 0)
        INTO v_distinct_contracts, v_contract_already_on_ep
        FROM AdSlots
        WHERE episode_id = NEW.episode_id
          AND slot_id <> OLD.slot_id;

        IF v_contract_already_on_ep = 0 AND v_distinct_contracts >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Business Rule Violation: Episode duoi 20 phut (< 1200s) chi duoc gan toi da 3 hop dong quang cao.';
        END IF;
    END IF;
END$$

CREATE TRIGGER TRG_Episodes_Duration_Limit_BU
BEFORE UPDATE ON Episodes
FOR EACH ROW
BEGIN
    DECLARE v_distinct_contracts INT DEFAULT 0;

    -- Ngăn việc giảm thời lượng Episode xuống < 20 phút nếu đã có hơn 3 hợp đồng quảng cáo
    IF NEW.duration_seconds < 1200 AND OLD.duration_seconds >= 1200 THEN
        SELECT COUNT(DISTINCT contract_id)
        INTO v_distinct_contracts
        FROM AdSlots
        WHERE episode_id = NEW.episode_id;

        IF v_distinct_contracts > 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Business Rule Violation: Khong the giam thoi luong Episode xuong duoi 20 phut vi da co hon 3 hop dong quang cao.';
        END IF;
    END IF;
END$$

DELIMITER ;
