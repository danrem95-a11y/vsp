-- =====================================================================
-- FIX PKT-0180: penyusutan Juli 2026 = 0 karena field turunan kosong.
-- Engine sp_fa_generate_sl meng-skip aset jika: p_period >= beginning_period (NULL -> skip),
-- dan butuh akun untuk posting. Entry manual tidak mengisi: beginning_period + 3 akun.
-- Perbaikan = isi field itu (beginning_period = AWAL BULAN perolehan = 2026-07-01),
-- lalu regenerate Juli. NON-DESTRUKTIF (hanya isi field kosong).
-- =====================================================================

update FA_ASSET
set beginning_period   = '2026-07-01',            -- awal bulan perolehan (08-07-2026 -> 01-07-2026)
    asset_account       = '153-001',
    accum_dep_account   = '158-101',
    dep_expense_account = '412-066'
where site_id='101' and asset_code='PKT-0180';
commit;

-- Regenerate + posting penyusutan Juli (idempotent; sama dgn tombol Generate di app).
-- CATATAN: ini MEM-POSTING jurnal GL Juli. Boleh dijalankan di sini, ATAU cukup
-- klik tombol Generate periode Jul 2026 di aplikasi setelah UPDATE di atas.
call sp_fa_regenerate_period('2026-07-31','101');
commit;

-- verifikasi hasil PKT-0180 Juli (harusnya penyusutan 51.435):
select asset_code, cast(period as date) period,
  cast(depreciation_amount as numeric(18,2)) penyusutan,
  cast(accum_depreciation as numeric(18,2)) akum,
  cast(book_value as numeric(18,2)) nbv
from FA_DEPRECIATION where asset_code='PKT-0180';
