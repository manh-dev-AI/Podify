-- ===================================================================
-- BỘ 8 CÂU TRUY VẤN SQL NGHIỆP VỤ (Q1 - Q8)
-- Dự án: Podcast & Audio Content Management System
-- Database: podify_db_vi
-- DBMS: MySQL 8.0
-- ===================================================================

USE podify_db_vi;


-- ===================================================================
-- Q1: Tìm các tập podcast có thời lượng từ 15 đến 30 phút
--     của kênh "Tri Thức Vn".
-- Owner: Member 1 - Mạnh
-- SQL Concepts: SELECT, WHERE, BETWEEN
-- ===================================================================

SELECT t.ma_tap, t.tieu_de_tap,
       k.tieu_de_kenh, t.thoi_luong_giay
FROM TapPodcast t
INNER JOIN KenhPodcast k
    ON t.ma_kenh = k.ma_kenh
WHERE k.tieu_de_kenh = 'Tri Thức Vn'
    AND t.thoi_luong_giay BETWEEN 900 AND 1800
ORDER BY t.thoi_luong_giay ASC;


-- ===================================================================
-- Q2: Hiển thị danh sách các quảng cáo được phát
--     trong tập podcast EP99.
-- Owner: Member 3 - Quang
-- SQL Concepts: INNER JOIN
-- ===================================================================

SELECT t.ma_tap, t.tieu_de_tap,
       qc.ma_quang_cao, qc.tieu_de_qc,
       qc.nha_quang_cao, v.giay_bat_dau
FROM TapPodcast t
INNER JOIN ViTriQC v
    ON t.ma_tap = v.ma_tap
INNER JOIN HopDongQC hd
    ON v.ma_hop_dong = hd.ma_hop_dong
INNER JOIN QuangCao qc
    ON hd.ma_quang_cao = qc.ma_quang_cao
WHERE t.tieu_de_tap = 'EP99'
    OR t.tieu_de_tap LIKE 'EP99 - %'
ORDER BY v.giay_bat_dau ASC;


-- ===================================================================
-- Q3: Thống kê tổng số lượt đăng ký mới (Subscribers)
--     của từng kênh Podcast trong tháng hiện tại.
-- Owner: Member 2 - Quân
-- SQL Concepts: GROUP BY, COUNT, LEFT JOIN
-- ===================================================================

SELECT k.ma_kenh, k.tieu_de_kenh,
       COUNT(td.ma_theo_doi) AS so_luot_theo_doi_moi
FROM KenhPodcast k
LEFT JOIN TheoDoi td
    ON k.ma_kenh = td.ma_kenh
    AND MONTH(td.ngay_theo_doi) = MONTH(CURDATE())
    AND YEAR(td.ngay_theo_doi) = YEAR(CURDATE())
GROUP BY k.ma_kenh, k.tieu_de_kenh
ORDER BY so_luot_theo_doi_moi DESC;


-- ===================================================================
-- Q4: Tìm các kênh Podcast có điểm đánh giá trung bình
--     dưới 3.0 sao (Kênh chất lượng kém).
-- Owner: Member 2 - Quân
-- SQL Concepts: INNER JOIN, GROUP BY, AVG, HAVING
-- ===================================================================

SELECT k.ma_kenh, k.tieu_de_kenh,
       ROUND(AVG(dg.so_sao), 2) AS diem_trung_binh
FROM DanhGia dg
INNER JOIN TapPodcast t
    ON dg.ma_tap = t.ma_tap
INNER JOIN KenhPodcast k
    ON t.ma_kenh = k.ma_kenh
GROUP BY k.ma_kenh, k.tieu_de_kenh
HAVING AVG(dg.so_sao) < 3.0
ORDER BY diem_trung_binh ASC;


-- ===================================================================
-- Q5: Hiển thị tất cả các tập Podcast của kênh X
--     và số lượt nghe của từng tập
--     (kể cả tập vừa đăng chưa có lượt nghe).
-- Owner: Member 2 - Quân
-- SQL Concepts: LEFT OUTER JOIN, COUNT, GROUP BY
-- ===================================================================

SELECT t.ma_tap, t.tieu_de_tap,
       COUNT(ls.ma_lich_su) AS tong_luot_nghe
FROM TapPodcast t
LEFT OUTER JOIN LichSuNghe ls
    ON t.ma_tap = ls.ma_tap
WHERE t.ma_kenh = 1
GROUP BY t.ma_tap, t.tieu_de_tap
ORDER BY tong_luot_nghe DESC;


-- ===================================================================
-- Q6: Tìm các tập Podcast có số lượt nghe vượt trội
--     so với số lượt nghe trung bình của các tập khác
--     trong cùng kênh đó.
-- Owner: Member 2 - Quân
-- SQL Concepts: CTE (WITH), LEFT JOIN, GROUP BY,
--               AVG, Correlated Subquery
-- ===================================================================

-- Đếm số lượt nghe của từng tập Podcast
WITH LuotNgheTheoTap AS (
    SELECT t.ma_tap, t.ma_kenh, t.tieu_de_tap,
           COUNT(ls.ma_lich_su) AS luot_nghe
    FROM TapPodcast t
    LEFT JOIN LichSuNghe ls
        ON t.ma_tap = ls.ma_tap
    GROUP BY t.ma_tap, t.ma_kenh, t.tieu_de_tap
)

-- So sánh với trung bình lượt nghe của các tập khác
-- trong cùng kênh bằng truy vấn con tương quan
SELECT ln.ma_tap, ln.ma_kenh,
       ln.tieu_de_tap, ln.luot_nghe
FROM LuotNgheTheoTap ln
WHERE ln.luot_nghe > (
    SELECT AVG(lt.luot_nghe)
    FROM LuotNgheTheoTap lt
    WHERE lt.ma_kenh = ln.ma_kenh
        AND lt.ma_tap <> ln.ma_tap
)
ORDER BY ln.ma_kenh ASC, ln.luot_nghe DESC;


-- ===================================================================
-- Q7: Tìm người dùng có tài khoản trên 6 tháng
--     nhưng chưa từng bấm đăng ký bất kỳ kênh Podcast nào.
-- Owner: Member 1 - Mạnh
-- SQL Concepts: Subquery, NOT IN, DATE_SUB
-- ===================================================================

SELECT nd.ma_nguoi_dung, nd.ten_dang_nhap,
       nd.ho_ten, nd.email, nd.ngay_tao
FROM NguoiDung nd
WHERE nd.ngay_tao < DATE_SUB(NOW(), INTERVAL 6 MONTH)
    AND nd.ma_nguoi_dung NOT IN (
        SELECT td.ma_nguoi_dung
        FROM TheoDoi td
        WHERE td.ma_nguoi_dung IS NOT NULL
    )
ORDER BY nd.ngay_tao ASC;


-- ===================================================================
-- Q8: Sử dụng SUM() OVER(PARTITION BY ... ORDER BY ...)
--     để tính doanh thu tích lũy tiền quảng cáo
--     của nhà sáng tạo theo từng tháng trong năm.
-- Owner: Member 3 - Quang
-- SQL Concepts: CTE (WITH), INNER JOIN, GROUP BY,
--               SUM, Window Functions, PARTITION BY
-- ===================================================================

-- Tính tổng doanh thu của từng nhà sáng tạo theo tháng
WITH DoanhThuThang AS (
    SELECT nst.ma_creator, nst.ten_hien_thi,
           YEAR(dt.ngay_ghi_nhan) AS nam,
           MONTH(dt.ngay_ghi_nhan) AS thang,
           SUM(dt.so_tien) AS doanh_thu_thang
    FROM DoanhThuQC dt
    INNER JOIN HopDongQC hd
        ON dt.ma_hop_dong = hd.ma_hop_dong
    INNER JOIN NhaSangTao nst
        ON hd.ma_creator = nst.ma_creator
    GROUP BY nst.ma_creator, nst.ten_hien_thi,
             YEAR(dt.ngay_ghi_nhan),
             MONTH(dt.ngay_ghi_nhan)
)

-- Tính doanh thu tích lũy theo từng tháng trong năm
SELECT ma_creator, ten_hien_thi,
       nam, thang, doanh_thu_thang,
       SUM(doanh_thu_thang) OVER (
           PARTITION BY ma_creator, nam
           ORDER BY thang ASC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS doanh_thu_tich_luy
FROM DoanhThuThang
ORDER BY ma_creator ASC, nam ASC, thang ASC;