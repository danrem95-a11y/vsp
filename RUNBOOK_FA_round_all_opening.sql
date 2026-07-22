-- =====================================================================
-- RUNBOOK: BULATKAN SELURUH DATA FA + OPENING + SELARASKAN GL
-- Sign-off user 2026-07-17 (OVERRIDE aturan Pak Wira "opening jangan dibulatkan").
-- Efek: opening accum_dep + cost dibulatkan; gl_balance akun FA diselaraskan;
--       net selisih pembulatan (~Rp 3.75) ke 376-001 (Laba Ditahan) agar neraca balance.
-- Aman-data: dep bulanan & jurnal GL FA (gl_journal) TIDAK diubah (sudah bulat & balance).
-- Jalankan di dbisql, APLIKASI DITUTUP. site_id='101'.
-- =====================================================================

-- ---------- BACKUP ----------
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_asset_ro_20260717') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_asset_ro_20260717 FROM FA_ASSET WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr_ro_20260717 FROM FA_DEPRECIATION WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_glbal_ro_20260717 FROM gl_balance WHERE site_id=''101'' AND Period=''2026-01-01'' AND AccountCode IN (''154-001'',''158-001'',''158-101'',''158-201'',''158-301'',''376-001'')';
END IF;
COMMIT;

-- ---------- 1) FA_ASSET: bulatkan opening ----------
UPDATE FA_ASSET SET
   acquisition_cost      = ROUND(acquisition_cost,0),
   accum_dep_beginning   = ROUND(accum_dep_beginning,0),
   residual_value        = ROUND(residual_value,0),
   book_value_beginning  = ROUND(acquisition_cost,0) - ROUND(accum_dep_beginning,0)
WHERE site_id='101';
COMMIT;

-- ---------- 2) FA_DEPRECIATION: recompute akum & NBV dari opening bulat ----------
--   depreciation_amount SUDAH integer & TIDAK diubah (jurnal GL bulanan tetap valid).
UPDATE FA_DEPRECIATION d SET accum_depreciation =
   (SELECT a.accum_dep_beginning FROM FA_ASSET a WHERE a.site_id=d.site_id AND a.asset_code=d.asset_code)
 + (SELECT COALESCE(SUM(d2.depreciation_amount),0) FROM FA_DEPRECIATION d2
      WHERE d2.site_id=d.site_id AND d2.asset_code=d.asset_code AND d2.period<=d.period)
WHERE d.site_id='101';
UPDATE FA_DEPRECIATION d SET book_value =
   (SELECT a.acquisition_cost FROM FA_ASSET a WHERE a.site_id=d.site_id AND a.asset_code=d.asset_code)
 - d.accum_depreciation
WHERE d.site_id='101';
UPDATE FA_DEPRECIATION SET depreciation_amount=ROUND(depreciation_amount,0) WHERE site_id='101';
COMMIT;

-- ---------- 3) gl_balance: selaraskan akun FA ke FA yang sudah bulat ----------
--   akun accum (kredit) = Σ round(accum_dep_beginning) per akun
UPDATE gl_balance g SET AmountCredit =
   (SELECT SUM(ROUND(a.accum_dep_beginning,0)) FROM FA_ASSET a
      WHERE a.site_id='101' AND a.status<>'D' AND a.accum_dep_account=g.AccountCode)
WHERE g.site_id='101' AND g.Period='2026-01-01' AND g.AccountCode IN ('158-001','158-101','158-201','158-301');
--   akun cost (debet) = Σ round(acquisition_cost) per akun (hanya 154-001 yg berdesimal)
UPDATE gl_balance g SET AmountDebet =
   (SELECT SUM(ROUND(a.acquisition_cost,0)) FROM FA_ASSET a
      WHERE a.site_id='101' AND a.status<>'D' AND a.asset_account=g.AccountCode)
WHERE g.site_id='101' AND g.Period='2026-01-01' AND g.AccountCode='154-001';
COMMIT;

-- ---------- 3b) OFFSET selisih pembulatan -> 376-001 (jaga neraca balance) ----------
-- PRE-CHECK (WAJIB): neraca saldo-awal harus sudah balance SEBELUM langkah ini,
--   sehingga selisih yang tersisa = MURNI pembulatan FA (~ -3.67..-3.75). Jalankan:
--     SELECT ROUND(SUM(AmountDebet)-SUM(AmountCredit),2) selisih FROM gl_balance WHERE site_id='101' AND Period='2026-01-01';
--   Kalau |selisih| jauh > 5, STOP & investigasi (ada imbalance TB pra-eksisting), jangan lanjut.
-- Serap selisih ke 376-001 (Laba Ditahan) agar SUM(Debet)=SUM(Kredit):
UPDATE gl_balance SET AmountCredit = AmountCredit
   + (SELECT SUM(AmountDebet)-SUM(AmountCredit) FROM gl_balance WHERE site_id='101' AND Period='2026-01-01')
 WHERE site_id='101' AND Period='2026-01-01' AND AccountCode='376-001';
COMMIT;

-- ===================== VERIFIKASI =====================
-- V1: tak ada desimal tersisa di data FA
SELECT 'FA_ASSET' tbl, SUM(CASE WHEN acquisition_cost<>ROUND(acquisition_cost,0) OR accum_dep_beginning<>ROUND(accum_dep_beginning,0)
       OR book_value_beginning<>ROUND(book_value_beginning,0) OR residual_value<>ROUND(residual_value,0) THEN 1 ELSE 0 END) n_desimal
  FROM FA_ASSET WHERE site_id='101'
UNION ALL
SELECT 'FA_DEPRECIATION', SUM(CASE WHEN depreciation_amount<>ROUND(depreciation_amount,0) OR accum_depreciation<>ROUND(accum_depreciation,0)
       OR book_value<>ROUND(book_value,0) THEN 1 ELSE 0 END) FROM FA_DEPRECIATION WHERE site_id='101';
-- V2: FA = GL per akun (harus selisih 0), akun FA gl_balance harus integer
SELECT a.accum_dep_account akun, SUM(ROUND(a.accum_dep_beginning,0)) fa,
   (SELECT AmountCredit FROM gl_balance b WHERE b.site_id='101' AND b.Period='2026-01-01' AND b.AccountCode=a.accum_dep_account) gl
 FROM FA_ASSET a WHERE a.site_id='101' AND a.status<>'D' AND a.accum_dep_account IS NOT NULL
 GROUP BY a.accum_dep_account ORDER BY a.accum_dep_account;
-- V3: NERACA saldo awal tetap BALANCE (Σdebet = Σkredit)
SELECT ROUND(SUM(AmountDebet),2) tot_debet, ROUND(SUM(AmountCredit),2) tot_kredit,
       ROUND(SUM(AmountDebet)-SUM(AmountCredit),2) selisih
  FROM gl_balance WHERE site_id='101' AND Period='2026-01-01';
-- V4: identitas FA_DEPRECIATION (book = cost - akum) & FA_ASSET (book_beg = cost - accum_beg)
SELECT (SELECT COUNT(*) FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
        WHERE d.site_id='101' AND ABS(d.book_value-(a.acquisition_cost-d.accum_depreciation))>0.004) violasi_depr,
       (SELECT COUNT(*) FROM FA_ASSET WHERE site_id='101' AND ABS(book_value_beginning-(acquisition_cost-accum_dep_beginning))>0.004) violasi_asset;

-- ===================== ROLLBACK =====================
-- DELETE FROM FA_ASSET WHERE site_id='101'; INSERT INTO FA_ASSET SELECT * FROM fa_bkp_asset_ro_20260717;
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101'; INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr_ro_20260717;
-- UPDATE gl_balance g SET AmountDebet=(SELECT AmountDebet FROM fa_bkp_glbal_ro_20260717 z WHERE z.AccountCode=g.AccountCode),
--        AmountCredit=(SELECT AmountCredit FROM fa_bkp_glbal_ro_20260717 z WHERE z.AccountCode=g.AccountCode)
--   WHERE g.site_id='101' AND g.Period='2026-01-01' AND g.AccountCode IN ('154-001','158-001','158-101','158-201','158-301','376-001');
-- COMMIT;
