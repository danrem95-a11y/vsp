-- =====================================================================
-- ATURAN PAK WIRA (akuntan):
--   * Opening = jurnal akhir Des 2025 / saldo awal 2026 -> TETAP DESIMAL, = Ledger DB (JANGAN diubah).
--   * Penyusutan mulai Jan 2026 dst -> DIBULATKAN (rupiah bulat).
-- Maka: opening (accum_dep_beginning) TIDAK disentuh; hanya engine yang membulatkan penyusutan.
-- Konsekuensi wajar: NBV akhir-umur menyisakan pecahan desimal opening (<1 rupiah) yg tampil bulat di laporan.
-- JANGAN jalankan RUNBOOK_FA_opening_ledger_round.sql (itu membulatkan opening - salah).
-- Jalankan di dbisql, aplikasi ditutup.
-- =====================================================================

-- Backup penyusutan + jurnal (opening TIDAK diubah, tak perlu backup FA_ASSET)
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_depr_rnd_20260715') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr_rnd_20260715 FROM FA_DEPRECIATION WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_gl_rnd_20260715 FROM gl_journal WHERE modul_id=''FA'' AND voucher LIKE ''FA101202%''';
END IF;
COMMIT;

-- Engine: metode WP (sisa buku/sisa umur) + penyusutan bulanan DIBULATKAN (ROUND ke-0).
-- Opening accum_dep_beginning tetap desimal (dipakai apa adanya sebagai basis).
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_generate_sl')
   THEN DROP PROCEDURE sp_fa_generate_sl END IF;
CREATE PROCEDURE sp_fa_generate_sl(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status IN ('P','C')) THEN
      RAISERROR 17001 'Periode sudah diposting/closed - pakai regenerate';
   END IF;
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period AND posting_status='D';
   INSERT INTO FA_DEPRECIATION (site_id,asset_code,period,depreciation_amount,accum_depreciation,book_value,posting_status)
   SELECT a.site_id, a.asset_code, p_period, dep.amt,
          a.accum_dep_beginning + prior.acc + dep.amt,
          a.acquisition_cost - (a.accum_dep_beginning + prior.acc + dep.amt), 'D'
   FROM FA_ASSET a
   JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   , LATERAL (SELECT COALESCE(SUM(d.depreciation_amount),0) AS acc, COUNT(*) AS cnt
                FROM FA_DEPRECIATION d
               WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period<p_period) prior
   , LATERAL (SELECT CASE
                        WHEN (prior.cnt + 1) >= a.remaining_life_begin THEN ROUND(a.book_value_beginning - prior.acc,0)
                        WHEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),0) < (a.book_value_beginning - prior.acc)
                             THEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),0)
                        ELSE ROUND(a.book_value_beginning - prior.acc,0) END AS amt) dep
   WHERE a.site_id=p_site AND a.status='A' AND c.depreciable_yn='Y'
     AND a.remaining_life_begin>0
     AND p_period >= a.beginning_period
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

-- ===== VERIFIKASI =====
-- 1) Opening TETAP desimal (tidak berubah) & = Ledger gl_balance:
SELECT a.category_code, CAST(ROUND(SUM(a.accum_dep_beginning),2) AS varchar) opening_db,
  CAST((SELECT b.AmountCredit-b.AmountDebet FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01'
   AND b.AccountCode=CASE a.category_code WHEN 'BGN' THEN '158-001' WHEN 'PKT' THEN '158-101' WHEN 'PBK' THEN '158-201' WHEN 'KDR' THEN '158-301' END) AS varchar) ledger
 FROM FA_ASSET a WHERE a.site_id='101' AND a.status<>'D' AND a.category_code<>'TNH'
 GROUP BY a.category_code ORDER BY a.category_code;
-- 2) Penyusutan Jan 2026 dst BULAT (harus 0 baris berdesimal):
SELECT COUNT(*) n_desimal FROM FA_DEPRECIATION WHERE site_id='101' AND depreciation_amount<>ROUND(depreciation_amount,0);
-- 3) Penyusutan Jan per golongan (bulat, cocok Sheet JURNAL WP):
SELECT a.category_code, ROUND(SUM(d.depreciation_amount),0) jan
 FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
 WHERE d.site_id='101' AND d.period='2026-01-31' GROUP BY a.category_code ORDER BY a.category_code;
-- 4) GL FA seimbang Dr=Cr:
SELECT voucher, SUM(debet)-SUM(kredit) selisih FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%' GROUP BY voucher ORDER BY voucher;

-- ===== ROLLBACK =====
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101'; INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr_rnd_20260715;
-- DELETE FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%'; INSERT INTO gl_journal SELECT * FROM fa_bkp_gl_rnd_20260715; COMMIT;
