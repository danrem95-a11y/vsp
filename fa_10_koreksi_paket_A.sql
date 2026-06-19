-- ============================================================================
-- PAKET A — Koreksi Master Aset FA (AMAN / value-neutral)
-- DB: vspnew (site 101) | Cutoff saldo awal: 31/12/2025
-- Sumber nilai: WP_Aset tetap_TAM 2026-rekonsiliasi.xlsx (tab detail) = GL
-- Dibuat: 2026-06-20 | Lihat MEMO_REKONSILIASI_FA_FINAL.md
--
-- TIDAK menyentuh: gl_journal, FA_DEPRECIATION, voucher FA, penyusutan 2026.
-- Aset Bangunan baru = fully-depreciated (book_value=0); Tanah = non-depresiasi
-- => engine menghasilkan 0 penyusutan untuk semuanya.
--
-- CARA PAKAI: jalankan dulu blok VERIFIKASI (bagian 4) SEBELUM koreksi untuk
-- baseline, lalu jalankan 1-3, lalu VERIFIKASI lagi. COMMIT hanya bila cocok GL.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BANGUNAN — 6 aset 2014 habis-susut (belum dimigrasi). cost=akum, NBV=0.
--    Target: 151-100 cost 3.712.136.932 ; 158-001 akum 1.469.198.390
-- ----------------------------------------------------------------------------
INSERT INTO FA_ASSET
  (site_id, asset_code, asset_name, category_code, acquisition_date,
   acquisition_cost, residual_value, useful_life_month,
   accum_dep_beginning, book_value_beginning, remaining_life_begin,
   beginning_period, asset_account, accum_dep_account, dep_expense_account,
   status, remarks, created_by, created_date)
SELECT '101', t.code, 'Bangunan (migrasi WP 2014, habis susut)', 'BGN', t.acq,
       t.cost, 0, 120, t.cost, 0, 0,
       '2025-12-31', '151-100', '158-001', '412-066',
       'F', 'Paket A: migrasi WP detail, fully depreciated', 'FA-RECON', current timestamp
FROM (
  SELECT 'BGN-0033' code, CAST('2014-03-24' AS date) acq, 124000000 cost UNION ALL
  SELECT 'BGN-0034', '2014-04-20', 93000000 UNION ALL
  SELECT 'BGN-0035', '2014-06-26', 77500000 UNION ALL
  SELECT 'BGN-0036', '2014-06-26', 39000000 UNION ALL
  SELECT 'BGN-0037', '2014-10-13', 40000000 UNION ALL
  SELECT 'BGN-0038', '2014-10-21', 21000000
) t;

-- ----------------------------------------------------------------------------
-- 2. TANAH — 11 bidang (belum dimigrasi). Non-depresiasi: akum=0, NBV=cost.
--    Target: 151-001 cost 17.934.062.500
-- ----------------------------------------------------------------------------
INSERT INTO FA_ASSET
  (site_id, asset_code, asset_name, category_code, acquisition_date,
   acquisition_cost, residual_value, useful_life_month,
   accum_dep_beginning, book_value_beginning, remaining_life_begin,
   beginning_period, asset_account, accum_dep_account, dep_expense_account,
   status, remarks, created_by, created_date)
SELECT '101', t.code, t.nm, 'TNH', t.acq,
       t.cost, 0, 0, 0, t.cost, 0,
       '2025-12-31', '151-001', NULL, NULL,
       'A', 'Paket A: migrasi WP Tanah (non-depresiasi)', 'FA-RECON', current timestamp
FROM (
  SELECT 'TNH-0001' code, CAST('2016-12-31' AS date) acq, 180500000   cost, 'Tanah Sukoharjo' nm UNION ALL
  SELECT 'TNH-0002', '2016-12-31', 373012500,   'Tanah Semarang' UNION ALL
  SELECT 'TNH-0003', '2016-12-31', 155000000,   'Tanah Surabaya' UNION ALL
  SELECT 'TNH-0004', '2016-12-31', 264450000,   'Tanah Bekasi' UNION ALL
  SELECT 'TNH-0005', '2016-12-31', 86558000,    'Tanah Bekasi' UNION ALL
  SELECT 'TNH-0006', '2016-12-31', 74992000,    'Tanah Bekasi' UNION ALL
  SELECT 'TNH-0007', '2022-04-15', 1493850000,  'Tanah Bali' UNION ALL
  SELECT 'TNH-0008', '2023-03-23', 7500000,     'Tanah Bali - Turun Hak' UNION ALL
  SELECT 'TNH-0009', '2023-04-17', 14500000000, 'Tanah Bali 1.810 M2 Desa Sanur Kauh, Denpasar Selatan' UNION ALL
  SELECT 'TNH-0010', '2023-04-29', 721000000,   'Tanah Bali - BPHTB 1.810 M2' UNION ALL
  SELECT 'TNH-0011', '2023-04-29', 77200000,    'Tanah Bali - Validasi/Akte/BBN/PNB/Notaris'
) t;

-- ----------------------------------------------------------------------------
-- 3. KENDARAAN — koreksi 3 aset inkonsistensi internal (cost<>akum+NBV).
--    Habis-susut sejak 2020 => set akum=cost, NBV=0. (Tidak ada penyusutan 2026)
-- ----------------------------------------------------------------------------
UPDATE FA_ASSET
SET accum_dep_beginning = acquisition_cost,
    book_value_beginning = 0,
    remaining_life_begin = 0,
    updated_by = 'FA-RECON', updated_date = current timestamp
WHERE site_id='101' AND category_code='KDR'
  AND asset_code IN ('KDR-0002','KDR-0003','KDR-0004');

-- ----------------------------------------------------------------------------
-- 4. VERIFIKASI (harus = GL 31/12/2025 setelah koreksi)
--    151-100=3.712.136.932 / 158-001=1.469.198.390 ; 151-001=17.934.062.500
-- ----------------------------------------------------------------------------
SELECT category_code,
       CAST(SUM(acquisition_cost)   AS numeric(20,2)) cost,
       CAST(SUM(accum_dep_beginning)AS numeric(20,2)) akum,
       CAST(SUM(book_value_beginning)AS numeric(20,2)) nbv,
       COUNT(*) n
FROM FA_ASSET WHERE site_id='101' GROUP BY category_code ORDER BY category_code;

-- cek tidak ada lagi inkonsistensi internal (selisih harus 0 baris)
SELECT asset_code, category_code,
       CAST(acquisition_cost-(accum_dep_beginning+book_value_beginning) AS numeric(18,2)) selisih
FROM FA_ASSET WHERE site_id='101'
  AND ABS(acquisition_cost-(accum_dep_beginning+book_value_beginning))>1;

-- ----------------------------------------------------------------------------
-- COMMIT hanya bila verifikasi cocok GL. (Hapus komentar untuk eksekusi)
-- COMMIT;
-- ----------------------------------------------------------------------------

-- ROLLBACK paket A bila perlu:
-- DELETE FROM FA_ASSET WHERE site_id='101' AND asset_code LIKE 'TNH-%';
-- DELETE FROM FA_ASSET WHERE site_id='101' AND asset_code IN
--   ('BGN-0033','BGN-0034','BGN-0035','BGN-0036','BGN-0037','BGN-0038');
-- UPDATE FA_ASSET SET accum_dep_beginning=0, book_value_beginning=0
--   WHERE site_id='101' AND asset_code IN ('KDR-0002','KDR-0003','KDR-0004');
-- COMMIT;
