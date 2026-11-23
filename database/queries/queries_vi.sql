-- ===================================================================
-- Bộ 8 Câu Truy Vấn SQL Nghiệp Vụ (Q1 -> Q8) - Phiên bản Tiếng Việt
-- Chạy trên Database: podify_db_vi
-- ===================================================================

USE podify_db_vi;

-- Q1 (Mạnh): Tìm Tập Podcast có thời lượng từ 15–30 phút (900s–1800s) thuộc Kênh cụ thể
SELECT
    t.ma_tap,
    k.tieu_de_kenh,
    t.tieu_de_tap,
    t.thoi_luong_giay,
    SEC_TO_TIME(t.thoi_luong_giay) AS thoi_luong_dinh_dang,
    t.ngay_phat_hanh
FROM TapPodcast t
INNER JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
WHERE t.ma_kenh = 1
  AND t.trang_thai = 'da_phat_hanh'
  AND t.thoi_luong_giay BETWEEN 900 AND 1800
ORDER BY t.thoi_luong_giay ASC;

-- Q2 (Quang): Tìm các Quảng cáo xuất hiện trong EP99
SELECT
    t.ma_tap,
    t.tieu_de_tap,
    v.vi_tri,
    v.giay_bat_dau,
    hd.so_hop_dong,
    qc.nha_quang_cao,
    qc.tieu_de_qc
FROM TapPodcast t
INNER JOIN ViTriQC v ON t.ma_tap = v.ma_tap
INNER JOIN HopDongQC hd ON v.ma_hop_dong = hd.ma_hop_dong
INNER JOIN QuangCao qc ON hd.ma_quang_cao = qc.ma_quang_cao
WHERE t.tieu_de_tap LIKE 'EP99%'
ORDER BY v.giay_bat_dau ASC;

-- Q3 (Quân): Số lượng Người theo dõi mới theo từng Kênh trong tháng hiện tại
SELECT
    k.ma_kenh,
    k.tieu_de_kenh,
    COUNT(td.ma_theo_doi) AS so_luot_theo_doi_moi
FROM KenhPodcast k
LEFT JOIN TheoDoi td
    ON k.ma_kenh = td.ma_kenh
   AND YEAR(td.ngay_theo_doi) = YEAR(CURDATE())
   AND MONTH(td.ngay_theo_doi) = MONTH(CURDATE())
GROUP BY k.ma_kenh, k.tieu_de_kenh
ORDER BY so_luot_theo_doi_moi DESC;

-- Q4 (Quân): Các Kênh Podcast có điểm Đánh giá trung bình dưới 3
SELECT
    k.ma_kenh,
    k.tieu_de_kenh,
    nst.ten_hien_thi AS nha_sang_tao,
    COUNT(dg.ma_danh_gia) AS tong_danh_gia,
    ROUND(AVG(dg.so_sao), 2) AS diem_trung_binh
FROM KenhPodcast k
INNER JOIN NhaSangTao nst ON k.ma_creator = nst.ma_creator
INNER JOIN TapPodcast t ON k.ma_kenh = t.ma_kenh
INNER JOIN DanhGia dg ON t.ma_tap = dg.ma_tap
GROUP BY k.ma_kenh, k.tieu_de_kenh, nst.ten_hien_thi
HAVING AVG(dg.so_sao) < 3.0
ORDER BY diem_trung_binh ASC;

-- Q5 (Quân): Danh sách Tập Podcast và số lượt nghe, kể cả tập chưa có lượt nghe
SELECT
    t.ma_tap,
    k.tieu_de_kenh,
    t.tieu_de_tap,
    COUNT(ls.ma_lich_su) AS tong_luot_nghe
FROM TapPodcast t
INNER JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
LEFT JOIN LichSuNghe ls ON t.ma_tap = ls.ma_tap
GROUP BY t.ma_tap, k.tieu_de_kenh, t.tieu_de_tap
ORDER BY tong_luot_nghe DESC, t.ma_tap ASC;

-- Q6 (Quân): Các Tập Podcast có lượt nghe cao hơn trung bình các tập khác cùng Kênh
WITH LuotNgheTheoTap AS (
    SELECT
        t.ma_tap,
        t.ma_kenh,
        k.tieu_de_kenh,
        t.tieu_de_tap,
        COUNT(ls.ma_lich_su) AS luot_nghe
    FROM TapPodcast t
    INNER JOIN KenhPodcast k ON t.ma_kenh = k.ma_kenh
    LEFT JOIN LichSuNghe ls ON t.ma_tap = ls.ma_tap
    GROUP BY t.ma_tap, t.ma_kenh, k.tieu_de_kenh, t.tieu_de_tap
),
ThongKeKenh AS (
    SELECT
        ma_tap,
        ma_kenh,
        tieu_de_kenh,
        tieu_de_tap,
        luot_nghe,
        AVG(luot_nghe) OVER (PARTITION BY ma_kenh) AS tb_luot_nghe_kenh
    FROM LuotNgheTheoTap
)
SELECT
    ma_tap,
    tieu_de_kenh,
    tieu_de_tap,
    luot_nghe,
    ROUND(tb_luot_nghe_kenh, 2) AS tb_luot_nghe_kenh
FROM ThongKeKenh
WHERE luot_nghe > tb_luot_nghe_kenh
ORDER BY ma_kenh, luot_nghe DESC;

-- Q7 (Mạnh): Tìm Người dùng có tài khoản trên 6 tháng nhưng chưa từng Theo dõi kênh nào
SELECT
    nd.ma_nguoi_dung,
    nd.ten_dang_nhap,
    nd.ho_ten,
    nd.email,
    nd.ngay_tao,
    TIMESTAMPDIFF(DAY, nd.ngay_tao, NOW()) AS so_ngay_da_tao
FROM NguoiDung nd
WHERE nd.ngay_tao < DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND NOT EXISTS (
      SELECT 1
      FROM TheoDoi td
      WHERE td.ma_nguoi_dung = nd.ma_nguoi_dung
  )
ORDER BY nd.ngay_tao ASC;

-- Q8 (Quang): Tính doanh thu quảng cáo tích lũy theo Nhà sáng tạo qua từng tháng (Window Function)
WITH DoanhThuThang AS (
    SELECT
        nst.ma_creator,
        nst.ten_hien_thi,
        DATE_FORMAT(dt.ngay_ghi_nhan, '%Y-%m') AS thang,
        SUM(dt.so_tien) AS doanh_thu_thang
    FROM DoanhThuQC dt
    INNER JOIN HopDongQC hd ON dt.ma_hop_dong = hd.ma_hop_dong
    INNER JOIN NhaSangTao nst ON hd.ma_creator = nst.ma_creator
    GROUP BY nst.ma_creator, nst.ten_hien_thi, DATE_FORMAT(dt.ngay_ghi_nhan, '%Y-%m')
)
SELECT
    ma_creator,
    ten_hien_thi,
    thang,
    doanh_thu_thang,
    SUM(doanh_thu_thang) OVER (
        PARTITION BY ma_creator
        ORDER BY thang ASC
    ) AS doanh_thu_tich_luy
FROM DoanhThuThang
ORDER BY ma_creator, thang;
