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
SELECT
    t.ma_tap,
    k.tieu_de_kenh,
    t.tieu_de_tap,
    t.thoi_luong_giay,
    SEC_TO_TIME(t.thoi_luong_giay) AS thoi_luong,
    t.duong_dan_audio
FROM TapPodcast t
JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
WHERE k.tieu_de_kenh = N'Tri Thức Vn'
  AND t.thoi_luong_giay BETWEEN 900 AND 1800
ORDER BY t.thoi_luong_giay ASC;

-- 2. JOIN: Hiển thị danh sách các quảng cáo được phát trong tập podcast EP99
SELECT
    t.ma_tap,
    t.tieu_de_tap,
    vt.vi_tri,
    vt.giay_bat_dau,
    hd.so_hop_dong,
    qc.nha_quang_cao,
    qc.tieu_de_qc,
    qc.link_dich
FROM TapPodcast t
JOIN ViTriQC vt ON t.ma_tap = vt.ma_tap
JOIN HopDongQC hd ON vt.ma_hop_dong = hd.ma_hop_dong
JOIN QuangCao qc ON hd.ma_quang_cao = qc.ma_quang_cao
WHERE t.tieu_de_tap LIKE 'EP99%'
ORDER BY vt.giay_bat_dau ASC;

-- 3. GROUP BY: Thống kê tổng số lượt đăng ký mới (Subscribers) của từng Kênh Podcast trong tháng
SELECT
    k.ma_kenh,
    k.tieu_de_kenh,
    COUNT(td.ma_theo_doi) AS tong_dang_ky_moi_trong_thang
FROM KenhPodcast k
LEFT JOIN TheoDoi td
    ON k.ma_kenh = td.ma_kenh
   AND MONTH(td.ngay_theo_doi) = MONTH(CURDATE())
   AND YEAR(td.ngay_theo_doi) = YEAR(CURDATE())
GROUP BY k.ma_kenh, k.tieu_de_kenh
ORDER BY tong_dang_ky_moi_trong_thang DESC;

-- 4. HAVING: Tìm các kênh podcast có điểm đánh giá trung bình < 3.0 sao
SELECT
    k.ma_kenh,
    k.tieu_de_kenh,
    COUNT(dg.ma_danh_gia) AS so_luot_danh_gia,
    ROUND(AVG(dg.so_sao), 2) AS diem_trung_binh
FROM KenhPodcast k
JOIN TapPodcast t ON k.ma_kenh = t.ma_kenh
JOIN DanhGia dg ON t.ma_tap = dg.ma_tap
GROUP BY k.ma_kenh, k.tieu_de_kenh
HAVING AVG(dg.so_sao) < 3.0
ORDER BY diem_trung_binh ASC;

-- 5. LEFT JOIN: Hiển thị tất cả tập của kênh "Tri Thức Vn" và số lượt nghe (kể cả tập 0 lượt nghe)
SELECT
    t.ma_tap,
    k.tieu_de_kenh,
    t.tieu_de_tap,
    COUNT(ls.ma_lich_su) AS so_luot_nghe
FROM TapPodcast t
JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
LEFT JOIN LichSuNghe ls ON t.ma_tap = ls.ma_tap
WHERE k.tieu_de_kenh = N'Tri Thức Vn'
GROUP BY t.ma_tap, k.tieu_de_kenh, t.tieu_de_tap
ORDER BY so_luot_nghe DESC, t.ma_tap ASC;

-- 6. CORRELATED SUBQUERY: Tìm các tập có lượt nghe cao hơn trung bình các tập KHÁC trong cùng kênh
SELECT
    t1.ma_tap,
    k.tieu_de_kenh,
    t1.tieu_de_tap,
    (SELECT COUNT(*) FROM LichSuNghe ls1 WHERE ls1.ma_tap = t1.ma_tap) AS so_luot_nghe
FROM TapPodcast t1
JOIN KenhPodcast k ON t1.ma_kenh = k.ma_kenh
WHERE (SELECT COUNT(*) FROM LichSuNghe ls1 WHERE ls1.ma_tap = t1.ma_tap) > (
    SELECT COALESCE(AVG(sub.luot_nghe), 0)
    FROM (
        SELECT t2.ma_tap, COUNT(ls2.ma_lich_su) AS luot_nghe
        FROM TapPodcast t2
        LEFT JOIN LichSuNghe ls2 ON t2.ma_tap = ls2.ma_tap
        WHERE t2.ma_kenh = t1.ma_kenh
          AND t2.ma_tap <> t1.ma_tap
        GROUP BY t2.ma_tap
    ) AS sub
)
ORDER BY t1.ma_kenh, so_luot_nghe DESC;

-- 7. SUBQUERY VỚI NOT IN: Tìm người dùng có tài khoản > 6 tháng nhưng chưa từng đăng ký kênh nào
SELECT
    nd.ma_nguoi_dung,
    nd.ten_dang_nhap,
    nd.ho_ten,
    nd.email,
    nd.ngay_tao
FROM NguoiDung nd
WHERE nd.ngay_tao < DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND nd.ma_nguoi_dung NOT IN (
      SELECT DISTINCT td.ma_nguoi_dung
      FROM TheoDoi td
      WHERE td.ma_nguoi_dung IS NOT NULL
  )
ORDER BY nd.ngay_tao ASC;

-- 8. WINDOW FUNCTIONS: Tính doanh thu tích lũy quảng cáo của Creator theo từng tháng trong năm
SELECT
    ma_creator,
    ten_hien_thi,
    nam,
    thang,
    doanh_thu_thang,
    SUM(doanh_thu_thang) OVER (
        PARTITION BY ma_creator, nam
        ORDER BY thang ASC
    ) AS doanh_thu_tich_luy
FROM (
    SELECT
        nst.ma_creator,
        nst.ten_hien_thi,
        YEAR(dt.ngay_ghi_nhan) AS nam,
        MONTH(dt.ngay_ghi_nhan) AS thang,
        SUM(dt.so_tien) AS doanh_thu_thang
    FROM DoanhThuQC dt
    JOIN HopDongQC hd ON dt.ma_hop_dong = hd.ma_hop_dong
    JOIN NhaSangTao nst ON hd.ma_creator = nst.ma_creator
    GROUP BY nst.ma_creator, nst.ten_hien_thi, YEAR(dt.ngay_ghi_nhan), MONTH(dt.ngay_ghi_nhan)
) AS bang_thang
ORDER BY ma_creator, nam, thang;
