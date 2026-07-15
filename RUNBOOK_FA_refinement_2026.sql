-- ================================================================
-- RUNBOOK Refinement Fixed Asset 2026 (permintaan Pak Wira, 2026-07)
-- Jalankan di Interactive SQL / dbisql pada DB produksi vspnew.
-- Site 101. Jalankan URUT dari atas. Bagian B & C butuh jendela
-- BEBAS-LOCK (aplikasi ditutup / minim aktivitas) karena ALTER &
-- repost bisa ke-blok SHARE-lock aplikasi.
-- ================================================================

-- ========== BACKUP (jaring pengaman, jangan drop s/d tutup buku) ==========
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_depr_20260713')
   THEN
     EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr_20260713 FROM FA_DEPRECIATION WHERE site_id=''101'' AND period BETWEEN ''2026-01-01'' AND ''2026-06-30''';
     EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_gl_20260713 FROM gl_journal WHERE modul_id=''FA'' AND voucher IN (''FA101202601'',''FA101202602'',''FA101202603'',''FA101202604'',''FA101202605'',''FA101202606'')';
END IF;
COMMIT;

-- ========== A. ENGINE: bulan terakhir serap sisa -> NBV = 0 (Point 5) ==========
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

-- ========== B. MASTER: kolom No. Voucher Bank (Point 3) — perlu bebas-lock ==========
IF NOT EXISTS(SELECT 1 FROM SYS.SYSCOLUMNS WHERE tname='FA_ASSET' AND cname='bank_voucher')
   THEN EXECUTE IMMEDIATE 'ALTER TABLE FA_ASSET ADD bank_voucher varchar(30) NULL' END IF;
COMMIT;

-- ========== C. Regenerate Jan-Jun 2026 URUT (Point 5 data + Point 4) ==========
-- Mengubah FA_DEPRECIATION & repost voucher FA101202601-06 (modul FA).
-- Nilai berubah hanya sen-an di bulan-terakhir aset; total GL (rounded rupiah) praktis tetap.
CALL sp_fa_regenerate_period('2026-01-31','101');
CALL sp_fa_regenerate_period('2026-02-28','101');
CALL sp_fa_regenerate_period('2026-03-31','101');
CALL sp_fa_regenerate_period('2026-04-30','101');
CALL sp_fa_regenerate_period('2026-05-31','101');
CALL sp_fa_regenerate_period('2026-06-30','101');
COMMIT;

-- ========== VERIFIKASI ==========
-- 1) Tidak boleh ada residu NBV (0<book_value<1) di bulan mana pun:
SELECT period, COUNT(*) n_residu, ROUND(SUM(book_value),2) tot
  FROM FA_DEPRECIATION WHERE site_id='101' AND book_value>0 AND book_value<1
 GROUP BY period ORDER BY period;
-- 2) Total penyusutan per bulan (bandingkan dgn sebelum, harus ~sama):
SELECT period, COUNT(*) n, ROUND(SUM(depreciation_amount),2) tot_depr
  FROM FA_DEPRECIATION WHERE site_id='101' AND period BETWEEN '2026-01-01' AND '2026-06-30'
 GROUP BY period ORDER BY period;
-- 3) GL FA balance (Dr=Cr) per voucher:
SELECT voucher, SUM(debet) dr, SUM(kredit) kr, SUM(debet)-SUM(kredit) selisih
  FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%'
 GROUP BY voucher ORDER BY voucher;

-- ========== ROLLBACK bila perlu ==========
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101' AND period BETWEEN '2026-01-01' AND '2026-06-30';
-- INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr_20260713;
-- DELETE FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%';
-- INSERT INTO gl_journal SELECT * FROM fa_bkp_gl_20260713;
-- COMMIT;
