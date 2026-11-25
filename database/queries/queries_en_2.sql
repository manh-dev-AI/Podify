-- ===================================================================
-- PODIFY: BUSINESS TRIGGER + 8 ANALYTICAL QUERIES (podify_db_2 - English)
-- ===================================================================

USE podify_db_2;

-- ===================================================================
-- PART A: TRIGGER FOR CROSS-TABLE CONSTRAINTS & BUSINESS RULES
-- 1. start_offset_seconds < duration_seconds
-- 2. Episodes under 20 minutes (< 1200s) cannot have more than 3 distinct ad contracts
-- ===================================================================
DROP TRIGGER IF EXISTS TRG_AdSlots_Validate_BI;

DELIMITER $$
CREATE TRIGGER TRG_AdSlots_Validate_BI
BEFORE INSERT ON AdSlots
FOR EACH ROW
BEGIN
    DECLARE v_duration INT;
    DECLARE v_contract_count INT DEFAULT 0;
    DECLARE v_already_exists INT DEFAULT 0;

    SELECT duration_seconds INTO v_duration
    FROM Episodes
    WHERE episode_id = NEW.episode_id;

    IF NEW.start_offset_seconds < 0 OR NEW.start_offset_seconds >= v_duration THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Ad slot start_offset_seconds must be less than episode duration_seconds!';
    END IF;

    IF v_duration < 1200 THEN
        SELECT
            COUNT(DISTINCT contract_id),
            COALESCE(MAX(CASE WHEN contract_id = NEW.contract_id THEN 1 ELSE 0 END), 0)
        INTO v_contract_count, v_already_exists
        FROM AdSlots
        WHERE episode_id = NEW.episode_id;

        IF v_already_exists = 0 AND v_contract_count >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error: Episodes under 20 minutes cannot contain more than 3 ad contracts!';
        END IF;
    END IF;
END$$
DELIMITER ;

-- ===================================================================
-- PART B: 8 ANALYTICAL QUERIES (Q1..Q8)
-- ===================================================================

-- 1. BASIC: Find episodes between 15 and 30 minutes on channel "Tri Thức Vn"
SELECT
    e.episode_id,
    c.title AS channel_title,
    e.title AS episode_title,
    e.duration_seconds,
    SEC_TO_TIME(e.duration_seconds) AS duration_formatted,
    e.audio_url
FROM Episodes e
JOIN PodcastChannels c ON e.channel_id = c.channel_id
WHERE c.title = N'Tri Thức Vn'
  AND e.duration_seconds BETWEEN 900 AND 1800
ORDER BY e.duration_seconds ASC;

-- 2. JOIN: List advertisements scheduled in episode EP99
SELECT
    e.episode_id,
    e.title AS episode_title,
    s.slot_position,
    s.start_offset_seconds,
    ac.contract_number,
    ad.advertiser_name,
    ad.title AS ad_title,
    ad.target_url
FROM Episodes e
JOIN AdSlots s ON e.episode_id = s.episode_id
JOIN AdContracts ac ON s.contract_id = ac.contract_id
JOIN Advertisements ad ON ac.ad_id = ad.ad_id
WHERE e.title LIKE 'EP99%'
ORDER BY s.start_offset_seconds ASC;

-- 3. GROUP BY: Count new subscriptions per PodcastChannel in the current month
SELECT
    c.channel_id,
    c.title AS channel_title,
    COUNT(sub.subscription_id) AS new_subscribers_this_month
FROM PodcastChannels c
LEFT JOIN Subscriptions sub
    ON c.channel_id = sub.channel_id
   AND MONTH(sub.subscribed_at) = MONTH(CURDATE())
   AND YEAR(sub.subscribed_at) = YEAR(CURDATE())
GROUP BY c.channel_id, c.title
ORDER BY new_subscribers_this_month DESC;

-- 4. HAVING: Find PodcastChannels with average rating < 3.0
SELECT
    c.channel_id,
    c.title AS channel_title,
    COUNT(r.rating_id) AS rating_count,
    ROUND(AVG(r.score), 2) AS avg_rating
FROM PodcastChannels c
JOIN Episodes e ON c.channel_id = e.channel_id
JOIN Ratings r ON e.episode_id = r.episode_id
GROUP BY c.channel_id, c.title
HAVING AVG(r.score) < 3.0
ORDER BY avg_rating ASC;

-- 5. LEFT JOIN: List all episodes of "Tri Thức Vn" and their listen counts (including 0 listens)
SELECT
    e.episode_id,
    c.title AS channel_title,
    e.title AS episode_title,
    COUNT(lh.history_id) AS listen_count
FROM Episodes e
JOIN PodcastChannels c ON e.channel_id = c.channel_id
LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
WHERE c.title = N'Tri Thức Vn'
GROUP BY e.episode_id, c.title, e.title
ORDER BY listen_count DESC, e.episode_id ASC;

-- 6. CORRELATED SUBQUERY: Find episodes with listen counts higher than the average of OTHER episodes in the same channel
SELECT
    e1.episode_id,
    c.title AS channel_title,
    e1.title AS episode_title,
    (SELECT COUNT(*) FROM ListeningHistory lh1 WHERE lh1.episode_id = e1.episode_id) AS listen_count
FROM Episodes e1
JOIN PodcastChannels c ON e1.channel_id = c.channel_id
WHERE (SELECT COUNT(*) FROM ListeningHistory lh1 WHERE lh1.episode_id = e1.episode_id) > (
    SELECT COALESCE(AVG(sub.listen_cnt), 0)
    FROM (
        SELECT e2.episode_id, COUNT(lh2.history_id) AS listen_cnt
        FROM Episodes e2
        LEFT JOIN ListeningHistory lh2 ON e2.episode_id = lh2.episode_id
        WHERE e2.channel_id = e1.channel_id
          AND e2.episode_id <> e1.episode_id
        GROUP BY e2.episode_id
    ) AS sub
)
ORDER BY e1.channel_id, listen_count DESC;

-- 7. SUBQUERY WITH NOT IN: Find users registered > 6 months ago who have never subscribed to any channel
SELECT
    u.user_id,
    u.username,
    u.full_name,
    u.email,
    u.created_at
FROM Users u
WHERE u.created_at < DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND u.user_id NOT IN (
      SELECT DISTINCT sub.user_id
      FROM Subscriptions sub
      WHERE sub.user_id IS NOT NULL
  )
ORDER BY u.created_at ASC;

-- 8. WINDOW FUNCTIONS: Calculate cumulative monthly ad revenue per Creator
SELECT
    creator_id,
    display_name,
    rev_year,
    rev_month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY creator_id, rev_year
        ORDER BY rev_month ASC
    ) AS cumulative_revenue
FROM (
    SELECT
        cr.creator_id,
        cr.display_name,
        YEAR(ar.recorded_date) AS rev_year,
        MONTH(ar.recorded_date) AS rev_month,
        SUM(ar.revenue_amount) AS monthly_revenue
    FROM AdRevenue ar
    JOIN AdContracts ac ON ar.contract_id = ac.contract_id
    JOIN Creators cr ON ac.creator_id = cr.creator_id
    GROUP BY cr.creator_id, cr.display_name, YEAR(ar.recorded_date), MONTH(ar.recorded_date)
) AS monthly_summary
ORDER BY creator_id, rev_year, rev_month;
