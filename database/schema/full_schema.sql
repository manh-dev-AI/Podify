CREATE DATABASE IF NOT EXISTS podify_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE podify_db;

-- 1. XOA CAC BANG CU (ke ca ban tieng Anh cu neu con ton tai)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS Donations;
DROP TABLE IF EXISTS AdRevenue;
DROP TABLE IF EXISTS AdSlots;
DROP TABLE IF EXISTS AdContracts;
DROP TABLE IF EXISTS Advertisements;
DROP TABLE IF EXISTS Ratings;
DROP TABLE IF EXISTS ListeningHistory;
DROP TABLE IF EXISTS Subscriptions;
DROP TABLE IF EXISTS Episodes;
DROP TABLE IF EXISTS PodcastChannels;
DROP TABLE IF EXISTS Creators;
DROP TABLE IF EXISTS Users;

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
SET FOREIGN_KEY_CHECKS = 1;

-- 2. BANG NGUOI DUNG (Ma: ND0001..)
CREATE TABLE NguoiDung (
    ma_nguoi_dung VARCHAR(10) PRIMARY KEY,
    ten_dang_nhap VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    mat_khau VARCHAR(255) NOT NULL,
    ho_ten VARCHAR(100) NOT NULL,
    vai_tro ENUM('nguoi_nghe','nha_sang_tao','quan_tri')
        NOT NULL DEFAULT 'nguoi_nghe',
    anh_dai_dien VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
);

-- 3. BANG NHA SANG TAO (Ma: NST0001..)
CREATE TABLE NhaSangTao (
    ma_creator VARCHAR(10) PRIMARY KEY,
    ma_nguoi_dung VARCHAR(10) UNIQUE NOT NULL,
    ten_hien_thi VARCHAR(100) NOT NULL UNIQUE,
    tieu_su TEXT NULL,
    da_xac_minh BOOLEAN NOT NULL DEFAULT FALSE,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE
);

-- 4. BANG KENH PODCAST (Ma: KP0001..)
CREATE TABLE KenhPodcast (
    ma_kenh VARCHAR(10) PRIMARY KEY,
    ma_creator VARCHAR(10) NOT NULL,
    tieu_de_kenh VARCHAR(200) NOT NULL UNIQUE,
    mo_ta TEXT NULL,
    the_loai VARCHAR(50) NOT NULL,
    anh_bia VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_creator)
        REFERENCES NhaSangTao(ma_creator) ON DELETE CASCADE
);

-- 5. BANG TAP PODCAST (Ma: EP0001.., EP0099)
CREATE TABLE TapPodcast (
    ma_tap VARCHAR(10) PRIMARY KEY,
    ma_kenh VARCHAR(10) NOT NULL,
    tieu_de_tap VARCHAR(255) NOT NULL UNIQUE,
    mo_ta TEXT NULL,
    duong_dan_audio VARCHAR(255) NOT NULL,
    thoi_luong_giay INT NOT NULL CHECK (thoi_luong_giay > 0),
    ngay_phat_hanh DATETIME NULL,
    trang_thai ENUM('nhap','da_phat_hanh','luu_tru')
        NOT NULL DEFAULT 'nhap',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_kenh)
        REFERENCES KenhPodcast(ma_kenh) ON DELETE CASCADE
);

-- 6. BANG THEO DOI (Ma: TD0001..)
CREATE TABLE TheoDoi (
    ma_theo_doi VARCHAR(10) PRIMARY KEY,
    ma_nguoi_dung VARCHAR(10) NOT NULL,
    ma_kenh VARCHAR(10) NOT NULL,
    ngay_theo_doi DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    bat_thong_bao BOOLEAN NOT NULL DEFAULT TRUE,

    FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    FOREIGN KEY (ma_kenh)
        REFERENCES KenhPodcast(ma_kenh) ON DELETE CASCADE,
    UNIQUE (ma_nguoi_dung, ma_kenh)
);

-- 7. BANG LICH SU NGHE (Ma: LS0001..)
CREATE TABLE LichSuNghe (
    ma_lich_su VARCHAR(10) PRIMARY KEY,
    ma_nguoi_dung VARCHAR(10) NOT NULL,
    ma_tap VARCHAR(10) NOT NULL,
    vi_tri_nghe_giay INT NOT NULL DEFAULT 0 CHECK (vi_tri_nghe_giay >= 0),
    da_nghe_xong BOOLEAN NOT NULL DEFAULT FALSE,
    thoi_diem_nghe DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE
);

-- 8. BANG DANH GIA (Ma: DG0001..)
CREATE TABLE DanhGia (
    ma_danh_gia VARCHAR(10) PRIMARY KEY,
    ma_nguoi_dung VARCHAR(10) NOT NULL,
    ma_tap VARCHAR(10) NOT NULL,
    so_sao TINYINT NOT NULL,
    binh_luan TEXT NULL,
    ngay_danh_gia DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ngay_cap_nhat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE,
    CHECK (so_sao BETWEEN 1 AND 5),
    UNIQUE (ma_nguoi_dung, ma_tap)
);

-- 9. BANG UNG HO (Ma: UH0001..)
CREATE TABLE UngHo (
    ma_ung_ho VARCHAR(10) PRIMARY KEY,
    ma_nguoi_ung_ho VARCHAR(10) NOT NULL,
    ma_creator VARCHAR(10) NOT NULL,
    so_tien_ung_ho DECIMAL(12, 0) NOT NULL CHECK (so_tien_ung_ho > 0),
    loi_nhan VARCHAR(255) NULL,
    ngay_ung_ho DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_nguoi_ung_ho)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    FOREIGN KEY (ma_creator)
        REFERENCES NhaSangTao(ma_creator) ON DELETE CASCADE
);

-- 10. BANG QUANG CAO (Ma: QC0001..)
CREATE TABLE QuangCao (
    ma_quang_cao VARCHAR(10) PRIMARY KEY,
    nha_quang_cao VARCHAR(150) NOT NULL,
    tieu_de_qc VARCHAR(200) NOT NULL,
    mo_ta TEXT NULL,
    audio_qc VARCHAR(255) NULL,
    link_dich VARCHAR(255) NULL,
    thoi_luong_giay INT NOT NULL CHECK (thoi_luong_giay > 0),
    trang_thai ENUM('hoat_dong', 'tam_dung', 'luu_tru')
        NOT NULL DEFAULT 'hoat_dong',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 11. BANG HOP DONG QUANG CAO (Ma: HD0001..)
CREATE TABLE HopDongQC (
    ma_hop_dong VARCHAR(10) PRIMARY KEY,
    ma_quang_cao VARCHAR(10) NOT NULL,
    ma_creator VARCHAR(10) NOT NULL,
    so_hop_dong VARCHAR(50) NOT NULL UNIQUE,
    gia_tri_hd DECIMAL(12, 0) NOT NULL CHECK (gia_tri_hd >= 0),
    don_gia_cpm DECIMAL(10, 0) NOT NULL DEFAULT 0 CHECK (don_gia_cpm >= 0),
    ngay_bat_dau DATE NOT NULL,
    ngay_ket_thuc DATE NOT NULL,
    trang_thai ENUM('nhap', 'hieu_luc', 'hoan_thanh', 'da_huy')
        NOT NULL DEFAULT 'hieu_luc',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CHECK (ngay_ket_thuc >= ngay_bat_dau),
    FOREIGN KEY (ma_quang_cao)
        REFERENCES QuangCao(ma_quang_cao) ON DELETE CASCADE,
    FOREIGN KEY (ma_creator)
        REFERENCES NhaSangTao(ma_creator) ON DELETE CASCADE
);

-- 12. BANG VI TRI QUANG CAO (Ma: VT0001..)
CREATE TABLE ViTriQC (
    ma_vi_tri VARCHAR(10) PRIMARY KEY,
    ma_hop_dong VARCHAR(10) NOT NULL,
    ma_tap VARCHAR(10) NOT NULL,
    vi_tri ENUM('dau_tap', 'giua_tap', 'cuoi_tap')
        NOT NULL DEFAULT 'giua_tap',
    giay_bat_dau INT NOT NULL DEFAULT 0 CHECK (giay_bat_dau >= 0),
    trang_thai ENUM('da_len_lich', 'hoat_dong', 'tam_dung')
        NOT NULL DEFAULT 'hoat_dong',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_hop_dong)
        REFERENCES HopDongQC(ma_hop_dong) ON DELETE CASCADE,
    FOREIGN KEY (ma_tap)
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE,
    UNIQUE (ma_hop_dong, ma_tap, vi_tri)
);

-- 13. BANG DOANH THU QUANG CAO (Ma: DT0001..)
CREATE TABLE DoanhThuQC (
    ma_doanh_thu VARCHAR(10) PRIMARY KEY,
    ma_hop_dong VARCHAR(10) NOT NULL,
    ma_vi_tri VARCHAR(10) NULL,
    ngay_ghi_nhan DATE NOT NULL,
    luot_hien_thi INT NOT NULL DEFAULT 0 CHECK (luot_hien_thi >= 0),
    so_tien DECIMAL(12, 0) NOT NULL CHECK (so_tien >= 0),
    ghi_chu VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_hop_dong)
        REFERENCES HopDongQC(ma_hop_dong) ON DELETE CASCADE,
    FOREIGN KEY (ma_vi_tri)
        REFERENCES ViTriQC(ma_vi_tri) ON DELETE SET NULL
);

SHOW TABLES;
