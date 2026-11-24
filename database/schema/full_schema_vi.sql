-- ===================================================================
-- Podify Database Schema - Phiên bản Tiếng Việt (MySQL 8.0 - 12 Bảng)
-- Đồng nhất 100% với sơ đồ E-R (podify_erd_chen_strict_hd.png)
-- và kiến trúc nhánh demo mới nhất (12 bảng chuẩn 3NF, bỏ DB Trigger)
-- ===================================================================

CREATE DATABASE IF NOT EXISTS podify_db_vi
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE podify_db_vi;

-- Xóa bảng theo thứ tự đảo ngược khóa ngoại (Bảng con trước, Bảng cha sau)
DROP TABLE IF EXISTS UngHo;
DROP TABLE IF EXISTS DoanhThuQC;
DROP TABLE IF EXISTS ViTriQC;
DROP TABLE IF EXISTS HopDongQC;
DROP TABLE IF EXISTS QuangCao;
DROP TABLE IF EXISTS DanhGia;
DROP TABLE IF EXISTS LichSuNghe;
DROP TABLE IF EXISTS TheoDoi;
DROP TABLE IF EXISTS TapPodcast;
DROP TABLE IF EXISTS KenhPodcast;
DROP TABLE IF EXISTS NhaSangTao;
DROP TABLE IF EXISTS NguoiDung;

-- ===================================================================
-- PHÂN HỆ 01: QUẢN LÝ NỘI DUNG (4 BẢNG - Mạnh)
-- ===================================================================

-- 1. NguoiDung (Users)
CREATE TABLE NguoiDung (
    ma_nguoi_dung INT AUTO_INCREMENT PRIMARY KEY,
    ten_dang_nhap VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    mat_khau VARCHAR(255) NOT NULL,
    ho_ten VARCHAR(100) NOT NULL,
    vai_tro ENUM('nguoi_nghe', 'nha_sang_tao', 'quan_tri') NOT NULL DEFAULT 'nguoi_nghe',
    anh_dai_dien VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX IDX_NguoiDung_NgayTao (ngay_tao),
    INDEX IDX_NguoiDung_VaiTro (vai_tro)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. NhaSangTao (Creators — Quan hệ 1 : 0..1 với NguoiDung)
CREATE TABLE NhaSangTao (
    ma_creator INT AUTO_INCREMENT PRIMARY KEY,
    ma_nguoi_dung INT NOT NULL UNIQUE,
    ten_hien_thi VARCHAR(100) NOT NULL,
    tieu_su TEXT NULL,
    da_xac_minh BOOLEAN NOT NULL DEFAULT FALSE, -- giống kiểu tích xanh trên tiktok với fb
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_NhaSangTao_NguoiDung FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. KenhPodcast (PodcastChannels — Quan hệ 1 : N với NhaSangTao)
CREATE TABLE KenhPodcast (
    ma_kenh INT AUTO_INCREMENT PRIMARY KEY,
    ma_creator INT NOT NULL,
    tieu_de_kenh VARCHAR(200) NOT NULL,
    mo_ta TEXT NULL,
    the_loai VARCHAR(50) NOT NULL,
    anh_bia VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT FK_KenhPodcast_NhaSangTao FOREIGN KEY (ma_creator)
        REFERENCES NhaSangTao(ma_creator) ON DELETE CASCADE,
    INDEX IDX_KenhPodcast_Creator (ma_creator),
    INDEX IDX_KenhPodcast_TheLoai (the_loai)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. TapPodcast (Episodes — Quan hệ 1 : N với KenhPodcast)
CREATE TABLE TapPodcast (
    ma_tap INT AUTO_INCREMENT PRIMARY KEY,
    ma_kenh INT NOT NULL,
    tieu_de_tap VARCHAR(255) NOT NULL,
    mo_ta TEXT NULL,
    duong_dan_audio VARCHAR(255) NOT NULL,
    thoi_luong_giay INT NOT NULL,
    ngay_phat_hanh DATETIME NULL,
    trang_thai ENUM('nhap', 'da_phat_hanh', 'luu_tru') NOT NULL DEFAULT 'nhap',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_TapPodcast_ThoiLuong CHECK (thoi_luong_giay > 0),
    CONSTRAINT FK_TapPodcast_KenhPodcast FOREIGN KEY (ma_kenh)
        REFERENCES KenhPodcast(ma_kenh) ON DELETE CASCADE,
    INDEX IDX_TapPodcast_Kenh_TrangThai_ThoiLuong (ma_kenh, trang_thai, thoi_luong_giay),
    INDEX IDX_TapPodcast_NgayPhatHanh (ngay_phat_hanh)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- PHÂN HỆ 02: NGHE & TƯƠNG TÁC NGƯỜI DÙNG (3 BẢNG - Quân)
-- ===================================================================

-- 5. TheoDoi (Subscriptions — Bảng trung gian M : N giữa NguoiDung và KenhPodcast)
CREATE TABLE TheoDoi (
    ma_theo_doi INT AUTO_INCREMENT PRIMARY KEY,
    ma_nguoi_dung INT NOT NULL,
    ma_kenh INT NOT NULL,
    ngay_theo_doi DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    bat_thong_bao BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT UQ_TheoDoi_NguoiDung_Kenh UNIQUE (ma_nguoi_dung, ma_kenh),
    CONSTRAINT FK_TheoDoi_NguoiDung FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    CONSTRAINT FK_TheoDoi_KenhPodcast FOREIGN KEY (ma_kenh)
        REFERENCES KenhPodcast(ma_kenh) ON DELETE CASCADE,
    INDEX IDX_TheoDoi_Kenh_Ngay (ma_kenh, ngay_theo_doi),
    INDEX IDX_TheoDoi_NguoiDung (ma_nguoi_dung)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. LichSuNghe (ListeningHistory — Bảng trung gian M : N giữa NguoiDung và TapPodcast)
CREATE TABLE LichSuNghe (
    ma_lich_su INT AUTO_INCREMENT PRIMARY KEY,
    ma_nguoi_dung INT NOT NULL,
    ma_tap INT NOT NULL,
    vi_tri_nghe_giay INT NOT NULL DEFAULT 0,
    da_nghe_xong BOOLEAN NOT NULL DEFAULT FALSE,
    thoi_diem_nghe DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT CHK_LichSuNghe_ViTri CHECK (vi_tri_nghe_giay >= 0),
    CONSTRAINT FK_LichSuNghe_NguoiDung FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    CONSTRAINT FK_LichSuNghe_TapPodcast FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE,
    INDEX IDX_LichSuNghe_NguoiDung_CapNhat (ma_nguoi_dung, ngay_cap_nhat),
    INDEX IDX_LichSuNghe_Tap (ma_tap)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. DanhGia (Ratings — Bảng trung gian M : N giữa NguoiDung và TapPodcast)
CREATE TABLE DanhGia (
    ma_danh_gia INT AUTO_INCREMENT PRIMARY KEY,
    ma_nguoi_dung INT NOT NULL,
    ma_tap INT NOT NULL,
    so_sao TINYINT NOT NULL,
    binh_luan TEXT NULL,
    ngay_danh_gia DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT CHK_DanhGia_SoSao CHECK (so_sao BETWEEN 1 AND 5),
    CONSTRAINT UQ_DanhGia_NguoiDung_Tap UNIQUE (ma_nguoi_dung, ma_tap),
    CONSTRAINT FK_DanhGia_NguoiDung FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    CONSTRAINT FK_DanhGia_TapPodcast FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE,
    INDEX IDX_DanhGia_Tap (ma_tap)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ===================================================================
-- PHÂN HỆ 03: QUẢNG CÁO & PHÂN TÍCH KINH DOANH (5 BẢNG - Quang)
-- ===================================================================

-- 8. QuangCao (Advertisements)
CREATE TABLE QuangCao (
    ma_quang_cao INT AUTO_INCREMENT PRIMARY KEY,
    nha_quang_cao VARCHAR(150) NOT NULL,
    tieu_de_qc VARCHAR(200) NOT NULL,
    mo_ta TEXT NULL,
    audio_qc VARCHAR(255) NULL,
    link_dich VARCHAR(255) NULL,
    thoi_luong_giay INT NOT NULL,
    trang_thai ENUM('hoat_dong', 'tam_dung', 'luu_tru') NOT NULL DEFAULT 'hoat_dong',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_QuangCao_ThoiLuong CHECK (thoi_luong_giay > 0),
    INDEX IDX_QuangCao_TrangThai (trang_thai)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. HopDongQC (AdContracts)
CREATE TABLE HopDongQC (
    ma_hop_dong INT AUTO_INCREMENT PRIMARY KEY,
    ma_quang_cao INT NOT NULL,
    ma_creator INT NOT NULL,
    so_hop_dong VARCHAR(50) NOT NULL UNIQUE,
    gia_tri_hd DECIMAL(12, 2) NOT NULL,
    don_gia_cpm DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    ngay_bat_dau DATE NOT NULL,
    ngay_ket_thuc DATE NOT NULL,
    trang_thai ENUM('nhap', 'hieu_luc', 'hoan_thanh', 'da_huy') NOT NULL DEFAULT 'hieu_luc',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_HopDongQC_GiaTri CHECK (gia_tri_hd >= 0),
    CONSTRAINT CHK_HopDongQC_CPM CHECK (don_gia_cpm >= 0),
    CONSTRAINT CHK_HopDongQC_Ngay CHECK (ngay_ket_thuc >= ngay_bat_dau),
    CONSTRAINT FK_HopDongQC_QuangCao FOREIGN KEY (ma_quang_cao)
        REFERENCES QuangCao(ma_quang_cao) ON DELETE CASCADE,
    CONSTRAINT FK_HopDongQC_NhaSangTao FOREIGN KEY (ma_creator)
        REFERENCES NhaSangTao(ma_creator) ON DELETE CASCADE,
    INDEX IDX_HopDongQC_Creator_TrangThai (ma_creator, trang_thai),
    INDEX IDX_HopDongQC_QuangCao (ma_quang_cao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. ViTriQC (AdSlots — Gắn HopDongQC vào TapPodcast)
CREATE TABLE ViTriQC (
    ma_vi_tri INT AUTO_INCREMENT PRIMARY KEY,
    ma_hop_dong INT NOT NULL,
    ma_tap INT NOT NULL,
    vi_tri ENUM('dau_tap', 'giua_tap', 'cuoi_tap') NOT NULL DEFAULT 'giua_tap',
    giay_bat_dau INT NOT NULL DEFAULT 0,
    trang_thai ENUM('da_len_lich', 'hoat_dong', 'tam_dung') NOT NULL DEFAULT 'hoat_dong',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_ViTriQC_GiayBatDau CHECK (giay_bat_dau >= 0),
    CONSTRAINT UQ_ViTriQC_HopDong_Tap_ViTri UNIQUE (ma_hop_dong, ma_tap, vi_tri),
    CONSTRAINT FK_ViTriQC_HopDongQC FOREIGN KEY (ma_hop_dong)
        REFERENCES HopDongQC(ma_hop_dong) ON DELETE CASCADE,
    CONSTRAINT FK_ViTriQC_TapPodcast FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE,
    INDEX IDX_ViTriQC_Tap (ma_tap),
    INDEX IDX_ViTriQC_HopDong (ma_hop_dong)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. DoanhThuQC (AdRevenue)
CREATE TABLE DoanhThuQC (
    ma_doanh_thu INT AUTO_INCREMENT PRIMARY KEY,
    ma_hop_dong INT NOT NULL,
    ma_vi_tri INT NULL,
    ngay_ghi_nhan DATE NOT NULL,
    luot_hien_thi INT NOT NULL DEFAULT 0,
    so_tien DECIMAL(12, 2) NOT NULL,
    ghi_chu VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_DoanhThuQC_LuotHienThi CHECK (luot_hien_thi >= 0),
    CONSTRAINT CHK_DoanhThuQC_SoTien CHECK (so_tien >= 0),
    CONSTRAINT FK_DoanhThuQC_HopDongQC FOREIGN KEY (ma_hop_dong)
        REFERENCES HopDongQC(ma_hop_dong) ON DELETE CASCADE,
    CONSTRAINT FK_DoanhThuQC_ViTriQC FOREIGN KEY (ma_vi_tri)
        REFERENCES ViTriQC(ma_vi_tri) ON DELETE SET NULL,
    INDEX IDX_DoanhThuQC_HopDong_Ngay (ma_hop_dong, ngay_ghi_nhan),
    INDEX IDX_DoanhThuQC_Ngay (ngay_ghi_nhan)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. UngHo (Donations)
CREATE TABLE UngHo (
    ma_ung_ho INT AUTO_INCREMENT PRIMARY KEY,
    ma_nguoi_ung_ho INT NOT NULL,
    ma_creator INT NOT NULL,
    ma_tap INT NULL,
    so_tien_ung_ho DECIMAL(12, 2) NOT NULL,
    loi_nhan VARCHAR(255) NULL,
    ngay_ung_ho DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_UngHo_SoTien CHECK (so_tien_ung_ho > 0),
    CONSTRAINT FK_UngHo_NguoiDung FOREIGN KEY (ma_nguoi_ung_ho)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    CONSTRAINT FK_UngHo_NhaSangTao FOREIGN KEY (ma_creator)
        REFERENCES NhaSangTao(ma_creator) ON DELETE CASCADE,
    CONSTRAINT FK_UngHo_TapPodcast FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE SET NULL,
    INDEX IDX_UngHo_Creator_Ngay (ma_creator, ngay_ung_ho),
    INDEX IDX_UngHo_NguoiUngHo (ma_nguoi_ung_ho)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lưu ý: Quy tắc nghiệp vụ (Tập < 20 phút tối đa 3 Hợp đồng QC) được kiểm tra tại tầng Backend Flask (đồng bộ với nhánh demo).
DROP TRIGGER IF EXISTS TRG_ViTriQC_GioiHanHopDong_BI;
DROP TRIGGER IF EXISTS TRG_ViTriQC_GioiHanHopDong_BU;
