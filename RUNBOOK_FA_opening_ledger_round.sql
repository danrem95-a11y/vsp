-- =====================================================================
-- (1) Opening Akum Peny AWAL 2026 = GL LEDGER vsp (rupiah BULAT) - per golongan tepat.
-- (2) Penyusutan Jan 2026 dst DIBULATKAN (FA_DEPRECIATION jadi rupiah bulat).
-- Karena opening dibulatkan = Ledger (bulat) & harga bulat -> NBV bulat & penyusutan bulat, NBV->0 tepat.
-- Ledger (gl_balance 01/01/2026): BGN 158-001=1.469.198.392 ; KDR 158-301=2.638.959.761 ;
--                                 PKT 158-101=845.637.756 ; PBK 158-201=130.925.053.
-- Jalankan di dbisql, aplikasi ditutup.
-- =====================================================================

-- Backup
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_open_20260715') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_open_20260715 FROM FA_ASSET WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr_open_20260715 FROM FA_DEPRECIATION WHERE site_id=''101''';
END IF;
COMMIT;

-- ===== A. Opening akum -> rupiah bulat, lalu disetimbangkan tepat = Ledger per golongan =====
-- A1. bulatkan semua opening akum
UPDATE FA_ASSET SET accum_dep_beginning = ROUND(accum_dep_beginning,0)
 WHERE site_id='101' AND status<>'D' AND category_code<>'TNH';

-- A2. selisih pembulatan vs Ledger ditambahkan ke aset ber-NBV terbesar tiap golongan
--     (BGN)
UPDATE FA_ASSET SET accum_dep_beginning = accum_dep_beginning +
  ( (SELECT b.AmountCredit-b.AmountDebet FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01' AND b.AccountCode='158-001')
    - (SELECT SUM(x.accum_dep_beginning) FROM FA_ASSET x WHERE x.site_id='101' AND x.category_code='BGN' AND x.status<>'D') )
 WHERE site_id='101' AND asset_code=(SELECT FIRST asset_code FROM FA_ASSET WHERE site_id='101' AND category_code='BGN' AND status<>'D' ORDER BY book_value_beginning DESC);
--     (KDR)
UPDATE FA_ASSET SET accum_dep_beginning = accum_dep_beginning +
  ( (SELECT b.AmountCredit-b.AmountDebet FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01' AND b.AccountCode='158-301')
    - (SELECT SUM(x.accum_dep_beginning) FROM FA_ASSET x WHERE x.site_id='101' AND x.category_code='KDR' AND x.status<>'D') )
 WHERE site_id='101' AND asset_code=(SELECT FIRST asset_code FROM FA_ASSET WHERE site_id='101' AND category_code='KDR' AND status<>'D' ORDER BY book_value_beginning DESC);
--     (PKT)
UPDATE FA_ASSET SET accum_dep_beginning = accum_dep_beginning +
  ( (SELECT b.AmountCredit-b.AmountDebet FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01' AND b.AccountCode='158-101')
    - (SELECT SUM(x.accum_dep_beginning) FROM FA_ASSET x WHERE x.site_id='101' AND x.category_code='PKT' AND x.status<>'D') )
 WHERE site_id='101' AND asset_code=(SELECT FIRST asset_code FROM FA_ASSET WHERE site_id='101' AND category_code='PKT' AND status<>'D' ORDER BY book_value_beginning DESC);
--     (PBK)
UPDATE FA_ASSET SET accum_dep_beginning = accum_dep_beginning +
  ( (SELECT b.AmountCredit-b.AmountDebet FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01' AND b.AccountCode='158-201')
    - (SELECT SUM(x.accum_dep_beginning) FROM FA_ASSET x WHERE x.site_id='101' AND x.category_code='PBK' AND x.status<>'D') )
 WHERE site_id='101' AND asset_code=(SELECT FIRST asset_code FROM FA_ASSET WHERE site_id='101' AND category_code='PBK' AND status<>'D' ORDER BY book_value_beginning DESC);

-- A3. NBV awal = harga - akum (jadi bulat)
UPDATE FA_ASSET SET book_value_beginning = acquisition_cost - accum_dep_beginning
 WHERE site_id='101' AND status<>'D';
COMMIT;

-- ===== B. Engine: penyusutan bulanan DIBULATKAN (metode WP: sisa buku/sisa umur) =====
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

-- ===== C. Regenerate + repost Jan-Jul 2026 =====
CALL sp_fa_regenerate_period('2026-01-31','101');  CALL sp_fa_build_gl_link('2026-01-31','101');
CALL sp_fa_regenerate_period('2026-02-28','101');  CALL sp_fa_build_gl_link('2026-02-28','101');
CALL sp_fa_regenerate_period('2026-03-31','101');  CALL sp_fa_build_gl_link('2026-03-31','101');
CALL sp_fa_regenerate_period('2026-04-30','101');  CALL sp_fa_build_gl_link('2026-04-30','101');
CALL sp_fa_regenerate_period('2026-05-31','101');  CALL sp_fa_build_gl_link('2026-05-31','101');
CALL sp_fa_regenerate_period('2026-06-30','101');  CALL sp_fa_build_gl_link('2026-06-30','101');
CALL sp_fa_regenerate_period('2026-07-31','101');  CALL sp_fa_build_gl_link('2026-07-31','101');
COMMIT;

-- ===== VERIFIKASI =====
-- 1) Opening = Ledger TEPAT (selisih 0):
SELECT a.category_code, ROUND(SUM(a.accum_dep_beginning),2) opening_db,
  (SELECT b.AmountCredit-b.AmountDebet FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01'
   AND b.AccountCode = CASE a.category_code WHEN 'BGN' THEN '158-001' WHEN 'PKT' THEN '158-101' WHEN 'PBK' THEN '158-201' WHEN 'KDR' THEN '158-301' END) ledger
 FROM FA_ASSET a WHERE a.site_id='101' AND a.status<>'D' AND a.category_code<>'TNH'
 GROUP BY a.category_code ORDER BY a.category_code;
-- 2) FA_DEPRECIATION sudah bulat (harus 0 baris berdesimal):
SELECT COUNT(*) n_desimal FROM FA_DEPRECIATION WHERE site_id='101' AND depreciation_amount<>ROUND(depreciation_amount,0);
-- 3) Penyusutan Jan per golongan (bulat):
SELECT a.category_code, ROUND(SUM(d.depreciation_amount),0) jan
 FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
 WHERE d.site_id='101' AND d.period='2026-01-31' GROUP BY a.category_code ORDER BY a.category_code;
-- 4) Tidak ada residu NBV (0<book<1):
SELECT period, COUNT(*) n FROM FA_DEPRECIATION WHERE site_id='101' AND book_value>0 AND book_value<1 GROUP BY period;

-- ===== ROLLBACK =====
-- DELETE FROM FA_ASSET WHERE site_id='101'; INSERT INTO FA_ASSET SELECT * FROM fa_bkp_open_20260715;
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101'; INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr_open_20260715; COMMIT;
