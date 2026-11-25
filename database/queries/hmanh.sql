USE podify_db;
SHOW TABLES;
select*
from danhgia;
-- cau1
select p.tieu_de_tap
from tappodcast p
join kenhpodcast k on p.ma_kenh = k.ma_kenh
where p.thoi_luong_giay >= (15 * 60) and p.thoi_luong_giay <= (30 * 60) and k.tieu_de_kenh LIKE '%Tri Thức Vn%';
-- cau2
select q.tieu_de_qc
from tappodcast t 
join vitriqc v on t.ma_tap = v.ma_tap
join hopdongqc h on h.ma_hop_dong = v.ma_hop_dong
join quangcao q on q.ma_quang_cao = h.ma_quang_cao
where t.tieu_de_tap LIKE '%EP99%';

-- cau 3
select k.tieu_de_kenh , count(td.ma_theo_doi) as luot_theo_doi ,YEAR(td.ngay_theo_doi) , month(td.ngay_theo_doi) 
from kenhpodcast k left join theodoi td on k.ma_kenh = td.ma_kenh and month(td.ngay_theo_doi) = month(current_date()) and year(td.ngay_theo_doi) = year(current_date())
group by k.tieu_de_kenh ,YEAR(td.ngay_theo_doi) , month(td.ngay_theo_doi) 
order by luot_theo_doi desc;

-- cau 4 Having: Tìm các kênh podcast có điểm đánh giá trung bình < 3.0 sao (Kênh chất lượng kém).
select k.tieu_de_kenh , avg(d.so_sao)
from tappodcast t left join danhgia d on t.ma_tap = d.ma_tap
join kenhpodcast k on t.ma_kenh = k.ma_kenh
group by k.tieu_de_kenh 
having avg(d.so_sao) < 3.0;

-- câu 7 Subquery với NOT IN: Tìm người dùng có tài khoản trên 6 tháng nhưng chưa từng bấm đăng ký bất kỳ kênh Podcast nào.
select nd.ho_ten , nd.vai_tro
from nguoidung nd
where nd.ngay_tao < date_sub(current_date() , INTERVAL 6 MONTH)
AND nd.ma_nguoi_dung not in(
	select distinct ma_nguoi_dung
    from theodoi
    where ma_nguoi_dung is not null
)


