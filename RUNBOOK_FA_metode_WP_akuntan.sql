-- =====================================================================
-- KEMBALIKAN metode penyusutan ke METODE WP AKUNTAN:
--   penyusutan/bln = ROUND(sisa Nilai Buku / sisa umur, 2)  (book_value_beginning/remaining_life_begin)
--   bulan terakhir menyerap sisa -> NBV = 0 tepat di akhir umur.
-- Ini MEMBATALKAN fix straight-line (Harga/umur) yg sempat dipasang, agar DB = WP_Aset tetap_TAM 2026.
-- Contoh acuan BGN-0029 'PL.Pembuatan Khusen Pintu Ko. Asem':
--   opening NBV 674.081,92 / sisa 10 bln -> 67.408,19/bln (SAMA dgn WP), bukan 69.166,67 (Harga/umur).
-- Jalankan di dbisql, aplikasi ditutup (repost voucher FA101202601..07).
-- =====================================================================

-- Backup pengaman
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_depr_wp_20260715') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr_wp_20260715 FROM FA_DEPRECIATION WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_gl_wp_20260715 FROM gl_journal WHERE modul_id=''FA'' AND voucher LIKE ''FA101202%''';
END IF;
COMMIT;

-- Engine: rate = sisa buku / sisa umur (metode WP), di-cap & bulan terakhir serap sisa.
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_generate_sl')
   THEN DROP PROCEDURE sp_fa_generate_sl END IF;
CREATE PROCEDURE sp_fa_generate_sl(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status IN ('P','C')) THEN
      RAISERROR 17001 'Periode sudah diposting/closed - pakai regenerate';
   END IF;
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period AND posting_status='D';
   INSERT INTO FA_DEPRECIATION (site_id,asset_code,period,depreciation_amount,accum_depreciation,book_value,posting_status)
   SELECT a.site_id, a.asset_code, p_period,
          dep.amt,
          a.accum_dep_beginning + prior.acc + dep.amt,
          a.acquisition_cost - (a.accum_dep_beginning + prior.acc + dep.amt),
          'D'
   FROM FA_ASSET a
   JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   , LATERAL (SELECT COALESCE(SUM(d.depreciation_amount),0) AS acc, COUNT(*) AS cnt
                FROM FA_DEPRECIATION d
               WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period<p_period) prior
   , LATERAL (SELECT CASE
                        WHEN (prior.cnt + 1) >= a.remaining_life_begin
                             THEN (a.book_value_beginning - prior.acc)
                        WHEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2)
                             < (a.book_value_beginning - prior.acc)
                             THEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2)
                        ELSE (a.book_value_beginning - prior.acc) END AS amt) dep
   WHERE a.site_id=p_site AND a.status='A' AND c.depreciable_yn='Y'
     AND a.remaining_life_begin>0
     AND (a.book_value_beginning - prior.acc) > 0
     AND dep.amt > 0;
END;

-- Regenerate + repost Jan-Jul 2026
CALL sp_fa_regenerate_period('2026-01-31','101');  CALL sp_fa_build_gl_link('2026-01-31','101');
CALL sp_fa_regenerate_period('2026-02-28','101');  CALL sp_fa_build_gl_link('2026-02-28','101');
CALL sp_fa_regenerate_period('2026-03-31','101');  CALL sp_fa_build_gl_link('2026-03-31','101');
CALL sp_fa_regenerate_period('2026-04-30','101');  CALL sp_fa_build_gl_link('2026-04-30','101');
CALL sp_fa_regenerate_period('2026-05-31','101');  CALL sp_fa_build_gl_link('2026-05-31','101');
CALL sp_fa_regenerate_period('2026-06-30','101');  CALL sp_fa_build_gl_link('2026-06-30','101');
CALL sp_fa_regenerate_period('2026-07-31','101');  CALL sp_fa_build_gl_link('2026-07-31','101');
COMMIT;

-- =========================== VERIFIKASI vs WP =======================
-- BGN-0029 Januari harus 67.408,19 (= WP), BUKAN 69.166,67:
SELECT d.asset_code, d.period, d.depreciation_amount,
       ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2) rate_wp
  FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
 WHERE d.site_id='101' AND d.asset_code='BGN-0029' ORDER BY d.period;
-- Tidak ada residu NBV (0<book<1):
SELECT period, COUNT(*) n FROM FA_DEPRECIATION WHERE site_id='101' AND book_value>0 AND book_value<1 GROUP BY period;
-- Total per bulan (Jan diperkirakan ~57.021.320):
SELECT period, COUNT(*) n, ROUND(SUM(depreciation_amount),2) tot FROM FA_DEPRECIATION WHERE site_id='101' GROUP BY period ORDER BY period;
-- GL FA seimbang Dr=Cr:
SELECT voucher, SUM(debet)-SUM(kredit) selisih FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%' GROUP BY voucher ORDER BY voucher;

-- =========================== ROLLBACK ==============================
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101'; INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr_wp_20260715;
-- DELETE FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%'; INSERT INTO gl_journal SELECT * FROM fa_bkp_gl_wp_20260715; COMMIT;
