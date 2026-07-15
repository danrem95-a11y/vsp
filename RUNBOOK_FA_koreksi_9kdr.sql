-- =====================================================================
-- KOREKSI OPENING 2026: keluarkan 9 aset KDR ekstra (KDR-0023..0031) dari
-- daftar aktif FA agar = Excel master (287 aset). status='D' (arsip audit-safe).
-- TANPA jurnal GL / tanpa rugi: ini koreksi subledger (aset tak ada di Excel 287,
-- sudah keluar pra-2026 / bukan aset 2026), BUKAN penjualan 2026.
-- Hasil: FA aktif 296 -> 287 ; total NBV awal 24.068.095.869,75 -> 22.956.313.829,75 (= Excel).
-- Jalankan di dbisql. (9 aset ini remaining_life_begin=0 -> tak punya baris penyusutan,
--  jadi total penyusutan bulanan & voucher FA TIDAK berubah.)
-- =====================================================================

-- 1) Backup 9 baris (jaring pengaman + sumber rollback)
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_kdr9_20260715') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_kdr9_20260715 FROM FA_ASSET WHERE site_id=''101'' AND created_by=''PRESERVE-KDR''';
END IF;
COMMIT;

-- 2) Arsipkan ke FA_DISPOSAL sebagai KOREKSI (journal_no=NULL, gain_loss=0) utk jejak audit
INSERT INTO FA_DISPOSAL(site_id,disposal_no,asset_code,disposal_date,disposal_type,
       acquisition_cost,accum_dep,book_value,proceeds,gain_loss,journal_no,reason,disposed_by,created_date)
SELECT '101', 'KOR'||a.asset_code, a.asset_code, '2025-12-31', 'KOREKSI',
       a.acquisition_cost, a.accum_dep_beginning, a.book_value_beginning, 0, 0, NULL,
       'Koreksi opening 2026 - tidak ada di Excel master (287), keluar pra-2026', CURRENT USER, CURRENT TIMESTAMP
  FROM FA_ASSET a
 WHERE a.site_id='101' AND a.created_by='PRESERVE-KDR' AND a.status<>'D'
   AND NOT EXISTS(SELECT 1 FROM FA_DISPOSAL d WHERE d.site_id='101' AND d.asset_code=a.asset_code);

-- 3) Set status='D' (hilang dari daftar aktif; baris & histori TETAP ada)
UPDATE FA_ASSET SET status='D', disposal_date='2025-12-31',
       remarks=COALESCE(remarks,'')||' [KOREKSI opening 2026 - tak ada di Excel 287]'
 WHERE site_id='101' AND created_by='PRESERVE-KDR' AND status<>'D';
COMMIT;

-- =========================== VERIFIKASI =============================
SELECT COUNT(*) n_aktif, CAST(ROUND(SUM(book_value_beginning),2) AS varchar) nbv_awal
  FROM FA_ASSET WHERE site_id='101' AND status<>'D';
-- Harapan: 287 aset ; NBV 22.956.313.829,75 (= Excel)
SELECT category_code, COUNT(*) n, CAST(ROUND(SUM(book_value_beginning),0) AS varchar) nbv
  FROM FA_ASSET WHERE site_id='101' AND status<>'D' GROUP BY category_code ORDER BY category_code;
-- Harapan: TNH 11 ; BGN 38 ; KDR 22 ; PBK 38 ; PKT 178
SELECT COUNT(*) n_disposal FROM FA_ASSET WHERE site_id='101' AND status='D';  -- 9

-- =========================== ROLLBACK ==============================
-- UPDATE FA_ASSET SET status=(SELECT b.status FROM fa_bkp_kdr9_20260715 b
--        WHERE b.site_id=FA_ASSET.site_id AND b.asset_code=FA_ASSET.asset_code),
--        disposal_date=NULL
--  WHERE site_id='101' AND created_by='PRESERVE-KDR';
-- DELETE FROM FA_DISPOSAL WHERE site_id='101' AND disposal_no LIKE 'KORKDR-%';
-- COMMIT;
