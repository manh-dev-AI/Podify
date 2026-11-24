CREATE DATABASE IF NOT EXISTS podify_db_vi_2
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE podify_db_vi_2;

-- 1. XOA CAC BANG CU
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

-- 2. BANG NGUOI DUNG (Ma: ND0001..)
CREATE TABLE NguoiDung (
    ma_nguoi_dung VARCHAR(10) PRIMARY KEY,
    ten_dang_nhap VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    matkhau VARCHAR(255) NOT NULL,
    ten VARCHAR(150) NOT NULL,
    vaitro ENUM('nguoi_nghe','nha_sang_tao','quan_tri')
        NOT NULL DEFAULT 'nguoi_nghe',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    anh_dai_dien VARCHAR(255) NULL
);

-- 3. BANG NHA SANG TAO (Ma: NST0001..)
CREATE TABLE NhaSangTao (
    ma_nha_sang_tao VARCHAR(10) PRIMARY KEY,
    ma_nguoi_dung VARCHAR(10) UNIQUE NOT NULL,
    ten_hien_thi VARCHAR(150) NOT NULL UNIQUE,
    tieu_su TEXT NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    xac_minh BOOLEAN NOT NULL DEFAULT FALSE,

    FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE
);

-- 4. BANG KENH PODCAST (Ma: KP0001..)
CREATE TABLE KenhPodcast (
    ma_kenh VARCHAR(10) PRIMARY KEY,
    ma_nha_sang_tao VARCHAR(10) NOT NULL,
    tieu_de_kenh VARCHAR(255) NOT NULL UNIQUE,
    the_loai VARCHAR(200) NOT NULL,
    mo_ta TEXT NULL,
    anhbia VARCHAR(255) NULL,
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_nha_sang_tao)
        REFERENCES NhaSangTao(ma_nha_sang_tao) ON DELETE CASCADE
);

-- 5. BANG TAP PODCAST (Ma: EP0001.., EP0099)
CREATE TABLE TapPodcast (
    ma_tap VARCHAR(10) PRIMARY KEY,
    ma_kenh VARCHAR(10) NOT NULL,
    tieu_de_tap VARCHAR(255) NOT NULL UNIQUE,
    thoi_luong_giay INT NOT NULL CHECK (thoi_luong_giay > 0),
    duong_dan_audio VARCHAR(255) NOT NULL,
    trang_thai ENUM('nhap','phat_hanh','luu_tru')
        NOT NULL DEFAULT 'nhap',
    ngay_ph DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_kenh)
        REFERENCES KenhPodcast(ma_kenh) ON DELETE CASCADE
);

-- 6. BANG THEO DOI (Ma: TD0001..)
CREATE TABLE TheoDoi (
    ma_theo_doi VARCHAR(10) PRIMARY KEY,
    ma_nguoi_dung VARCHAR(10) NOT NULL,
    ma_kenh VARCHAR(10) NOT NULL,
    ngay_theo_doi DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tbao BOOLEAN NOT NULL DEFAULT FALSE,

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
    vitri INT NOT NULL CHECK (vitri >= 0),
    da_nghe BOOLEAN NOT NULL DEFAULT FALSE,
    thoidiem DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    so_sao INT NOT NULL,
    binh_luan VARCHAR(255) NULL,
    ngay DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

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
    ma_nguoi_dung VARCHAR(10) NOT NULL,
    ma_nha_sang_tao VARCHAR(10) NOT NULL,
    tien_ung_ho DECIMAL(12, 0) NOT NULL CHECK (tien_ung_ho > 0),
    loi_nhan TEXT NULL,
    ngay_ung_ho DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_nguoi_dung)
        REFERENCES NguoiDung(ma_nguoi_dung) ON DELETE CASCADE,
    FOREIGN KEY (ma_nha_sang_tao)
        REFERENCES NhaSangTao(ma_nha_sang_tao) ON DELETE CASCADE
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
    ma_nha_sang_tao VARCHAR(10) NOT NULL,
    so_hop_dong VARCHAR(50) NOT NULL UNIQUE,
    gia_tri_hd DECIMAL(12, 0) NOT NULL CHECK (gia_tri_hd >= 0),
    don_gia_cpm DECIMAL(10, 0) NOT NULL DEFAULT 0,
    ngay_bat_dau DATE NOT NULL,
    ngay_ket_thuc DATE NOT NULL,
    trang_thai ENUM('nhap', 'hieu_luc', 'hoan_thanh', 'da_huy')
        NOT NULL DEFAULT 'hieu_luc',
    ngay_tao DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ma_quang_cao)
        REFERENCES QuangCao(ma_quang_cao) ON DELETE CASCADE,
    FOREIGN KEY (ma_nha_sang_tao)
        REFERENCES NhaSangTao(ma_nha_sang_tao) ON DELETE CASCADE
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
        REFERENCES TapPodcast(ma_tap) ON DELETE CASCADE
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
