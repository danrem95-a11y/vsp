-- =====================================================================
-- FIX: pembelian PKT Jan 2026 (PKT-0178 AC GREE, PKT-0179 Monitor) cost=0 -> isi cost,
-- agar disusutkan MULAI Jan 2026 (bulan perolehan), sesuai WP.
-- Setelah ini PKT Jan: 3.835.716 -> ~4.017.696 (= WP). Metode engine TIDAK diubah (tetap WP: sisa-buku/sisa-umur).
-- Pembelian Jan 2026 otomatis disusutkan Jan 2026 (bukan Feb) karena Jan = periode pertama & book>0.
-- Jalankan di dbisql, aplikasi ditutup.
-- Sumber angka: WP_Aset tetap_TAM sheet 'Perl. Kantor' baris 208-209.
--   PKT-0178 Unit AC GREE 2PK  : harga 7.950.000, umur 48, peny/bln 165.625,00
--   PKT-0179 Unit Monitor 22"  : harga   785.000, umur 48, peny/bln  16.354,17
-- =====================================================================

-- Backup
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_pkt_purch_20260715') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_pkt_purch_20260715 FROM FA_ASSET WHERE site_id=''101'' AND asset_code IN (''PKT-0178'',''PKT-0179'')';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr_pkt_20260715 FROM FA_DEPRECIATION WHERE site_id=''101''';
END IF;
COMMIT;

-- Isi data pembelian (opening tetap: akum_awal=0 karena beli 2026; book=cost; umur penuh 48; mulai Jan 2026)
UPDATE FA_ASSET SET acquisition_cost=7950000, book_value_beginning=7950000, accum_dep_beginning=0,
       useful_life_month=48, remaining_life_begin=48, beginning_period='2026-01-01', status='A', bank_voucher='26012004P017'
 WHERE site_id='101' AND asset_code='PKT-0178';
UPDATE FA_ASSET SET acquisition_cost=785000, book_value_beginning=785000, accum_dep_beginning=0,
       useful_life_month=48, remaining_life_begin=48, beginning_period='2026-01-01', status='A', bank_voucher='26011003P086'
 WHERE site_id='101' AND asset_code='PKT-0179';
COMMIT;

-- Regenerate + repost Jan-Jul 2026 (2 aset ini kini ikut tersusut mulai Jan)
CALL sp_fa_regenerate_period('2026-01-31','101');  CALL sp_fa_build_gl_link('2026-01-31','101');
CALL sp_fa_regenerate_period('2026-02-28','101');  CALL sp_fa_build_gl_link('2026-02-28','101');
CALL sp_fa_regenerate_period('2026-03-31','101');  CALL sp_fa_build_gl_link('2026-03-31','101');
CALL sp_fa_regenerate_period('2026-04-30','101');  CALL sp_fa_build_gl_link('2026-04-30','101');
CALL sp_fa_regenerate_period('2026-05-31','101');  CALL sp_fa_build_gl_link('2026-05-31','101');
CALL sp_fa_regenerate_period('2026-06-30','101');  CALL sp_fa_build_gl_link('2026-06-30','101');
CALL sp_fa_regenerate_period('2026-07-31','101');  CALL sp_fa_build_gl_link('2026-07-31','101');
COMMIT;

-- =========================== VERIFIKASI vs WP =======================
-- 1) 2 aset PKT ini harus punya penyusutan Jan (165.625 & 16.354,17):
SELECT d.asset_code, d.period, d.depreciation_amount
  FROM FA_DEPRECIATION d WHERE d.site_id='101' AND d.asset_code IN ('PKT-0178','PKT-0179') AND d.period='2026-01-31';
-- 2) Total penyusutan Jan per golongan (PKT harus ~4.017.696):
SELECT a.category_code, ROUND(SUM(d.depreciation_amount),2) jan
  FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
 WHERE d.site_id='101' AND d.period='2026-01-31' GROUP BY a.category_code ORDER BY a.category_code;
-- Harapan: BGN 14.300.641 | KDR 36.888.945 | PBK 1.996.017 | PKT 4.017.696 ; TOTAL 57.203.299
-- 3) GL FA seimbang:
SELECT voucher, SUM(debet)-SUM(kredit) selisih FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%' GROUP BY voucher ORDER BY voucher;

-- =========================== ROLLBACK ==============================
-- UPDATE FA_ASSET a SET acquisition_cost=0, book_value_beginning=0, remaining_life_begin=0, status='F'
--   WHERE site_id='101' AND asset_code IN ('PKT-0178','PKT-0179');
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101'; INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr_pkt_20260715; COMMIT;
