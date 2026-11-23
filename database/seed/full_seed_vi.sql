-- ===================================================================
-- Dữ liệu mẫu Tiếng Việt cho podify_db_vi (12 Bảng)
-- Phục vụ kiểm thử đầy đủ Q1 -> Q8 và Trigger nghiệp vụ
-- ===================================================================

USE podify_db_vi;

-- 1. NguoiDung (bao gồm người dùng tạo > 6 tháng chưa theo dõi kênh nào cho Q7)
INSERT INTO NguoiDung (ma_nguoi_dung, ten_dang_nhap, email, mat_khau, ho_ten, vai_tro, ngay_tao) VALUES
(1, 'manh_creator', 'manh@podify.vn', 'hash_123456', N'Nguyễn Hữu Mạnh', 'nha_sang_tao', DATE_SUB(NOW(), INTERVAL 10 MONTH)),
(2, 'tranthi_b', 'b@podify.vn', 'hash_123456', N'Trần Thị B', 'nha_sang_tao', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
(3, 'levan_c', 'c@podify.vn', 'hash_123456', N'Lê Văn C', 'nguoi_nghe', DATE_SUB(NOW(), INTERVAL 7 MONTH)), -- > 6 tháng, chưa TheoDoi (Q7)
(4, 'pham_d', 'd@podify.vn', 'hash_123456', N'Phạm Minh D', 'nguoi_nghe', DATE_SUB(NOW(), INTERVAL 2 MONTH)),
(5, 'hoang_e', 'e@podify.vn', 'hash_123456', N'Hoàng Lan E', 'nguoi_nghe', DATE_SUB(NOW(), INTERVAL 9 MONTH)); -- > 6 tháng, chưa TheoDoi (Q7)

-- 2. NhaSangTao
INSERT INTO NhaSangTao (ma_creator, ma_nguoi_dung, ten_hien_thi, tieu_su, da_xac_minh) VALUES
(1, 1, N'Tech Talk VN', N'Chia sẻ kiến thức SQL, Backend và kỹ năng lập trình.', TRUE),
(2, 2, N'Góc Tâm Sự', N'Những câu chuyện radio cuối tuần về đời sống.', TRUE);

-- 3. KenhPodcast
INSERT INTO KenhPodcast (ma_kenh, ma_creator, tieu_de_kenh, mo_ta, the_loai) VALUES
(1, 1, N'Lập Trình Không Khó', N'Học thiết kế cơ sở dữ liệu và web từ cơ bản.', N'Công nghệ'),
(2, 1, N'AI & Tương Lai', N'Cập nhật xu hướng trí tuệ nhân tạo.', N'Khoa học'),
(3, 2, N'Trà Chiều Radio', N'Những mẩu chuyện nhẹ nhàng mỗi cuối tuần.', N'Đời sống');

-- 4. TapPodcast (Có tập 15-30p cho Q1, có tập EP99 cho Q2, có tập 0 lượt nghe cho Q5)
INSERT INTO TapPodcast (ma_tap, ma_kenh, tieu_de_tap, mo_ta, duong_dan_audio, thoi_luong_giay, trang_thai, ngay_phat_hanh) VALUES
(1, 1, N'Tập 1: Nhập môn Database và MySQL', N'Tổng quan bảng, khóa chính và khóa ngoại.', '/assets/audio/sample_1.mp3', 1200, 'da_phat_hanh', DATE_SUB(NOW(), INTERVAL 20 DAY)),
(2, 1, N'Tập 2: Chuẩn hóa 3NF trong thực tế', N'Cách đưa lược đồ về dạng chuẩn 3NF.', '/assets/audio/sample_2.mp3', 1500, 'da_phat_hanh', DATE_SUB(NOW(), INTERVAL 15 DAY)),
(3, 1, N'Tập 3: Câu lệnh SELECT nâng cao', N'Thực hành JOIN, GROUP BY và Subquery.', '/assets/audio/sample_3.mp3', 600, 'da_phat_hanh', DATE_SUB(NOW(), INTERVAL 10 DAY)),
(4, 1, N'Tập 4: Tối ưu chỉ mục Indexes', N'Tăng tốc truy vấn SQL.', '/assets/audio/sample_4.mp3', 2400, 'da_phat_hanh', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(99, 2, N'EP99 - Xu hướng AI năm 2026', N'Tập đặc biệt bàn về AI và ứng dụng.', '/assets/audio/sample_ep99.mp3', 1800, 'da_phat_hanh', DATE_SUB(NOW(), INTERVAL 8 DAY)),
(100, 3, N'Bình yên nơi góc phố', N'Những giai điệu và lời tự sự nhẹ nhàng.', '/assets/audio/sample_5.mp3', 950, 'da_phat_hanh', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(101, 2, N'Tập mới chưa có lượt nghe', N'Tập mới xuất bản để kiểm thử LEFT JOIN Q5.', '/assets/audio/sample_6.mp3', 1100, 'da_phat_hanh', NOW());

-- 5. TheoDoi (Chú ý: user 3 và 5 không có ở đây -> lọt vào Q7)
INSERT INTO TheoDoi (ma_nguoi_dung, ma_kenh, ngay_theo_doi) VALUES
(1, 3, NOW()),
(2, 1, NOW()),
(4, 1, NOW()),
(4, 2, DATE_SUB(NOW(), INTERVAL 2 DAY));

-- 6. LichSuNghe (Tập 101 cố tình không có lượt nghe nào cho Q5)
INSERT INTO LichSuNghe (ma_nguoi_dung, ma_tap, vi_tri_nghe_giay, da_nghe_xong) VALUES
(2, 1, 1200, TRUE),
(4, 1, 1200, TRUE),
(1, 1, 600, FALSE),
(4, 2, 1500, TRUE),
(4, 99, 900, FALSE),
(1, 100, 950, TRUE);

-- 7. DanhGia (Kênh 3 có điểm trung bình < 3 để test Q4)
INSERT INTO DanhGia (ma_nguoi_dung, ma_tap, so_sao, binh_luan) VALUES
(2, 1, 5, N'Giải thích rất dễ hiểu!'),
(4, 1, 5, N'Rất hữu ích cho đồ án.'),
(4, 99, 4, N'Nội dung AI rất hay.'),
(1, 100, 2, N'Âm thanh hơi nhỏ một chút.'),
(4, 100, 2, N'Cần cải thiện nhạc nền.');

-- 8. QuangCao
INSERT INTO QuangCao (ma_quang_cao, nha_quang_cao, tieu_de_qc, thoi_luong_giay, trang_thai) VALUES
(1, N'FPT Software', N'Tuyển dụng Fresher Backend 2026', 30, 'hoat_dong'),
(2, N'Highlands Coffee', N'Thức tỉnh năng lượng sáng tạo', 20, 'hoat_dong');

-- 9. HopDongQC
INSERT INTO HopDongQC (ma_hop_dong, ma_quang_cao, ma_creator, so_hop_dong, gia_tri_hd, don_gia_cpm, ngay_bat_dau, ngay_ket_thuc, trang_thai) VALUES
(1, 1, 1, 'HD-2026-001', 15000000.00, 50000.00, '2026-01-01', '2026-12-31', 'hieu_luc'),
(2, 2, 1, 'HD-2026-002', 8000000.00, 35000.00, '2026-02-01', '2026-12-31', 'hieu_luc');

-- 10. ViTriQC (Gắn vào EP99 để test Q2)
INSERT INTO ViTriQC (ma_vi_tri, ma_hop_dong, ma_tap, vi_tri, giay_bat_dau) VALUES
(1, 1, 99, 'dau_tap', 0),
(2, 2, 99, 'giua_tap', 600);

-- 11. DoanhThuQC (Nhiều tháng để test Window Function Q8)
INSERT INTO DoanhThuQC (ma_hop_dong, ma_vi_tri, ngay_ghi_nhan, luot_hien_thi, so_tien, ghi_chu) VALUES
(1, 1, '2026-09-15', 12000, 3500000.00, N'Doanh thu tháng 9'),
(1, 1, '2026-10-15', 18000, 5200000.00, N'Doanh thu tháng 10'),
(2, 2, '2026-11-10', 10000, 2800000.00, N'Doanh thu tháng 11');

-- 12. UngHo
INSERT INTO UngHo (ma_nguoi_ung_ho, ma_creator, ma_tap, so_tien_ung_ho, loi_nhan) VALUES
(4, 1, 1, 50000.00, N'Cảm ơn anh Mạnh vì bài giảng SQL!'),
(3, 2, NULL, 100000.00, N'Ủng hộ kênh Trà Chiều Radio.');
