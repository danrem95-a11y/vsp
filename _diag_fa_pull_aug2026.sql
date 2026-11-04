-- Diagnostik: kenapa pembelian Aug 2026 tidak tertarik ke Tarik Aktiva dari Pembelian
-- Jalankan tiap blok terpisah, lihat hasilnya.

-- 1) Akun aktiva yang dikenali sistem (site 101)
select category_code, asset_account, useful_life_month, depreciable_yn
from FA_CATEGORY where site_id='101';

-- 2) SEMUA debit gl_journal Agustus 2026 ke akun mana pun yang MIRIP akun aktiva
--    (longgar, untuk lihat apakah akunnya sedikit beda dari yang dikenal FA_CATEGORY)
select tgl, voucher, urut, modul_id, account_id, debet, posting, ket
from gl_journal
where site_id='101' and month(tgl)=8 and year(tgl)=2026 and debet>0
  and (account_id like '151-%' or account_id like '153-%' or account_id like '154-%' or account_id like '155-%')
order by tgl;

-- 3) Kandidat PERSIS yang seharusnya tertarik (query sama persis dgn sp_fa_pull_from_purchase)
select g.voucher, g.urut, cast(g.tgl as date) tgl, isnull(g.ket,'') nama_aset,
       cat.category_code golongan, g.posting, cast(g.debet as numeric(18,2)) harga,
       g.voucher || '#' || cast(g.urut as varchar) source_ref
  from gl_journal g
  join FA_CATEGORY cat on cat.site_id=g.site_id and cat.asset_account=g.account_id
 where g.site_id='101' and g.debet>0
   and cast(g.tgl as date) between '2026-08-01' and '2026-08-31'
 order by g.tgl;
-- kalau baris di sini KOSONG tapi baris di query #2 ADA -> akunnya tidak match FA_CATEGORY persis, atau posting<>'P'
-- kalau baris di sini ADA tapi tetap tidak muncul di preview aplikasi -> source_ref-nya sudah kepakai (cek FA_ASSET)

-- 4) Apakah source_ref dari kandidat di atas SUDAH ada di FA_ASSET (berarti sebenarnya sudah tertarik)?
select a.asset_code, a.asset_name, a.acquisition_date, a.source_ref, a.category_code
from FA_ASSET a
where a.site_id='101' and a.source_ref is not null and a.acquisition_date between '2026-08-01' and '2026-08-31';
