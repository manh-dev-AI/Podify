-- ===================================================================
-- ĐỀ 18: TRIGGER NGHIỆP VỤ + 8 TRUY VẤN DỮ LIỆU (podify_db)
-- Dùng tên bảng/cột chuẩn từ full_schema_vi.sql + cú pháp JOIN gọn
-- ===================================================================

USE podify_db;

-- ===================================================================
-- PHẦN A: TRIGGER KIỂM TRA RÀNG BUỘC LIÊN BẢNG & BUSINESS RULES
-- 1. giay_bat_dau < thoi_luong_giay
-- 2. Tập dưới 20 phút (< 1200s) không được chèn quá 3 hợp đồng QC khác nhau
-- ===================================================================
DROP TRIGGER IF EXISTS TRG_ViTriQC_KiemTra_BI;

DELIMITER $$
CREATE TRIGGER TRG_ViTriQC_KiemTra_BI
BEFORE INSERT ON ViTriQC
FOR EACH ROW
BEGIN
    DECLARE v_thoi_luong INT;
    DECLARE v_so_hop_dong INT DEFAULT 0;
    DECLARE v_da_ton_tai INT DEFAULT 0;

    SELECT thoi_luong_giay INTO v_thoi_luong
    FROM TapPodcast
    WHERE ma_tap = NEW.ma_tap;

    IF NEW.giay_bat_dau < 0 OR NEW.giay_bat_dau >= v_thoi_luong THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loi: Thoi diem chen quang cao phai nho hon thoi luong tap podcast!';
    END IF;

    IF v_thoi_luong < 1200 THEN
        SELECT
            COUNT(DISTINCT ma_hop_dong),
            COALESCE(MAX(CASE WHEN ma_hop_dong = NEW.ma_hop_dong THEN 1 ELSE 0 END), 0)
        INTO v_so_hop_dong, v_da_ton_tai
        FROM ViTriQC
        WHERE ma_tap = NEW.ma_tap;

        IF v_da_ton_tai = 0 AND v_so_hop_dong >= 3 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Loi: Tap podcast duoi 20 phut khong duoc chen qua 3 hop dong quang cao!';
        END IF;
    END IF;
END$$
DELIMITER ;

-- ===================================================================
-- PHẦN B: HỆ THỐNG 8 TRUY VẤN DỮ LIỆU THEO ĐỀ 18
-- ===================================================================

-- 1. CƠ BẢN: Tìm các tập podcast có thời lượng từ 15 đến 30 phút của kênh "Tri Thức Vn"
SELECT t.ma_tap, t.tieu_de_tap, t.thoi_luong_giay
FROM TapPodcast t
INNER JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
WHERE k.tieu_de_kenh = 'Tri Thức Vn'
    AND t.thoi_luong_giay BETWEEN 900 AND 1800
ORDER BY t.thoi_luong_giay ASC;

-- 2. JOIN: Hiển thị danh sách các quảng cáo được phát trong tập podcast EP99

SELECT t.ma_tap, t.tieu_de_tap,
       qc.tieu_de_qc, qc.nha_quang_cao,
       vt.giay_bat_dau
FROM TapPodcast t
INNER JOIN ViTriQC vt ON t.ma_tap = vt.ma_tap
INNER JOIN HopDongQC hd ON vt.ma_hop_dong = hd.ma_hop_dong
INNER JOIN QuangCao qc ON hd.ma_quang_cao = qc.ma_quang_cao
WHERE t.tieu_de_tap = 'EP99'
   OR t.tieu_de_tap LIKE 'EP99 - %'
ORDER BY vt.giay_bat_dau ASC;

-- 3. GROUP BY: Thống kê tổng số lượt đăng ký mới (Subscribers) của từng Kênh Podcast trong tháng
SELECT k.ma_kenh, k.tieu_de_kenh,
       COUNT(td.ma_theo_doi) AS luot_dang_ky_moi
FROM KenhPodcast k
LEFT JOIN TheoDoi td
    ON k.ma_kenh = td.ma_kenh
    AND MONTH(td.ngay_theo_doi) = MONTH(CURDATE())
    AND YEAR(td.ngay_theo_doi) = YEAR(CURDATE())
GROUP BY k.ma_kenh, k.tieu_de_kenh
ORDER BY luot_dang_ky_moi DESC;

-- 4. HAVING: Tìm các kênh podcast có điểm đánh giá trung bình < 3.0 sao
SELECT k.ma_kenh, k.tieu_de_kenh,
       ROUND(AVG(dg.so_sao), 2) AS diem_trung_binh
FROM KenhPodcast k
INNER JOIN TapPodcast t ON k.ma_kenh = t.ma_kenh
INNER JOIN DanhGia dg ON t.ma_tap = dg.ma_tap
GROUP BY k.ma_kenh, k.tieu_de_kenh
HAVING AVG(dg.so_sao) < 3.0
ORDER BY diem_trung_binh ASC;

-- 5. LEFT JOIN: Hiển thị tất cả tập của kênh "Tri Thức Vn" và số lượt nghe (kể cả tập 0 lượt nghe)
SELECT t.ma_tap, t.tieu_de_tap,
       COUNT(ls.ma_lich_su) AS so_luot_nghe
FROM TapPodcast t
INNER JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
LEFT OUTER JOIN LichSuNghe ls ON t.ma_tap = ls.ma_tap
WHERE k.tieu_de_kenh = 'Tri Thức Vn'
GROUP BY t.ma_tap, t.tieu_de_tap
ORDER BY so_luot_nghe DESC;

-- 6. CORRELATED SUBQUERY: Tìm các tập có lượt nghe cao hơn trung bình các tập KHÁC trong cùng kênh
USE podify_db_vi;

-- thống kê số lượt nghe của từng tập Podcast
WITH LuotNgheTheoTap AS (
    SELECT t.ma_tap, t.ma_kenh, t.tieu_de_tap, COUNT(ls.ma_lich_su) AS luot_nghe
    FROM TapPodcast t
    LEFT JOIN LichSuNghe ls ON t.ma_tap = ls.ma_tap
    GROUP BY t.ma_tap, t.ma_kenh, t.tieu_de_tap
)
-- Lấy thông tin của tập Podcast đang xét
SELECT ln.ma_tap, ln.ma_kenh,
       ln.tieu_de_tap, ln.luot_nghe
FROM LuotNgheTheoTap ln
-- So sánh lượt nghe của tập đang xét với trung bình lượt nghe của các tập khác cùng kênh
WHERE ln.luot_nghe > (
    SELECT AVG(lt.luot_nghe)
    FROM LuotNgheTheoTap lt
    WHERE lt.ma_kenh = ln.ma_kenh AND lt.ma_tap <> ln.ma_tap
)
ORDER BY ln.ma_kenh ASC, ln.luot_nghe DESC;

-- 7. SUBQUERY VỚI NOT IN: Tìm người dùng có tài khoản > 6 tháng nhưng chưa từng đăng ký kênh nào
SELECT nd.ma_nguoi_dung, nd.ten_dang_nhap,
       nd.ho_ten, nd.email, nd.ngay_tao
FROM NguoiDung nd
-- Lọc tài khoản đã tạo trên 6 tháng
WHERE nd.ngay_tao < DATE_SUB(NOW(), INTERVAL 6 MONTH)
-- Loại bỏ người dùng đã đăng ký kênh
    AND nd.ma_nguoi_dung NOT IN (
        SELECT td.ma_nguoi_dung
        FROM TheoDoi td
        WHERE td.ma_nguoi_dung IS NOT NULL
    )
ORDER BY nd.ngay_tao ASC;

-- 8. WINDOW FUNCTIONS: Tính doanh thu tích lũy quảng cáo của Creator theo từng tháng trong năm
-- Thống kê tổng doanh thu theo từng tháng
WITH DoanhThuThang AS (
    SELECT nst.ma_creator, nst.ten_hien_thi,
           YEAR(dt.ngay_ghi_nhan) AS nam,
           MONTH(dt.ngay_ghi_nhan) AS thang,
           SUM(dt.so_tien) AS doanh_thu_thang
    FROM DoanhThuQC dt
    INNER JOIN HopDongQC hd ON dt.ma_hop_dong = hd.ma_hop_dong
    INNER JOIN NhaSangTao nst ON hd.ma_creator = nst.ma_creator
    GROUP BY nst.ma_creator, nst.ten_hien_thi,
             YEAR(dt.ngay_ghi_nhan),
             MONTH(dt.ngay_ghi_nhan)
)

-- Tính doanh thu tích lũy theo từng nhà sáng tạo và năm
SELECT ma_creator, ten_hien_thi,
       nam, thang, doanh_thu_thang,
       SUM(doanh_thu_thang) OVER (
           PARTITION BY ma_creator, nam
           ORDER BY thang ASC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS doanh_thu_tich_luy
FROM DoanhThuThang
ORDER BY ma_creator, nam, thang;
