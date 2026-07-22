-- =====================================================================
-- KOREKSI SALDO AWAL GL 2026 (gl_balance) akun Akum Penyusutan 158-xxx:
--   dari rupiah BULAT -> DESIMAL, disamakan ke FA Aktiva/WP akuntan.
-- Tujuan: opening akhir-2025/awal-2026 => FA Aktiva = Ledger, SELISIH 0 (dua-duanya desimal).
-- Penyeimbang (agar neraca tetap balance) = Laba Ditahan 376-001 sebesar net perubahan (+4,67).
--
-- SIFAT: penyesuaian pembulatan periode lalu (immaterial ~4,67 rupiah). HARUS disetujui akuntan (Pak Wira).
-- Jalankan di dbisql saat aplikasi ditutup. Hanya menyentuh gl_balance Period 2026-01-01.
--
-- Nilai target (= FA opening): 158-001 1.469.198.389,90 ; 158-301 2.638.959.753,34 ;
--                              158-201 130.925.056,70 ; 158-101 845.637.757,39.
-- =====================================================================

-- Backup baris yg diubah
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='gl_bal_bkp_20260717') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO gl_bal_bkp_20260717 FROM gl_balance WHERE site_id=''101'' AND Period=''2026-01-01'' AND AccountCode IN (''158-001'',''158-101'',''158-201'',''158-301'',''376-001'')';
END IF;
COMMIT;

-- 1) Penyeimbang DULU: Laba Ditahan 376-001 += (gl_balance 158 SEKARANG - FA 158) = +4,67
--    (dihitung sebelum 158-xxx diubah, memakai nilai bulat saat ini)
UPDATE gl_balance SET AmountCredit = AmountCredit
   + ( (SELECT SUM(g.AmountCredit - g.AmountDebet) FROM gl_balance g
          WHERE g.site_id='101' AND g.Period='2026-01-01' AND g.AccountCode IN ('158-001','158-101','158-201','158-301'))
       - (SELECT SUM(a.accum_dep_beginning) FROM FA_ASSET a
          WHERE a.site_id='101' AND a.status<>'D' AND a.category_code IN ('BGN','KDR','PBK','PKT')) )
 WHERE site_id='101' AND Period='2026-01-01' AND AccountCode='376-001';

-- 2) Set 158-xxx = FA opening (desimal, eksak)
UPDATE gl_balance SET AmountCredit=(SELECT SUM(accum_dep_beginning) FROM FA_ASSET WHERE site_id='101' AND status<>'D' AND category_code='BGN')
 WHERE site_id='101' AND Period='2026-01-01' AND AccountCode='158-001';
UPDATE gl_balance SET AmountCredit=(SELECT SUM(accum_dep_beginning) FROM FA_ASSET WHERE site_id='101' AND status<>'D' AND category_code='KDR')
 WHERE site_id='101' AND Period='2026-01-01' AND AccountCode='158-301';
UPDATE gl_balance SET AmountCredit=(SELECT SUM(accum_dep_beginning) FROM FA_ASSET WHERE site_id='101' AND status<>'D' AND category_code='PBK')
 WHERE site_id='101' AND Period='2026-01-01' AND AccountCode='158-201';
UPDATE gl_balance SET AmountCredit=(SELECT SUM(accum_dep_beginning) FROM FA_ASSET WHERE site_id='101' AND status<>'D' AND category_code='PKT')
 WHERE site_id='101' AND Period='2026-01-01' AND AccountCode='158-101';
COMMIT;

-- =========================== VERIFIKASI =============================
-- 1) 158-xxx (Ledger) SEKARANG = FA Aktiva (selisih 0):
SELECT g.AccountCode,
  CAST(g.AmountCredit-g.AmountDebet AS varchar) ledger,
  CAST((SELECT SUM(a.accum_dep_beginning) FROM FA_ASSET a WHERE a.site_id='101' AND a.status<>'D'
        AND a.category_code=CASE g.AccountCode WHEN '158-001' THEN 'BGN' WHEN '158-301' THEN 'KDR' WHEN '158-201' THEN 'PBK' WHEN '158-101' THEN 'PKT' END) AS varchar) fa,
  CAST((g.AmountCredit-g.AmountDebet) - (SELECT SUM(a.accum_dep_beginning) FROM FA_ASSET a WHERE a.site_id='101' AND a.status<>'D'
        AND a.category_code=CASE g.AccountCode WHEN '158-001' THEN 'BGN' WHEN '158-301' THEN 'KDR' WHEN '158-201' THEN 'PBK' WHEN '158-101' THEN 'PKT' END) AS varchar) selisih
 FROM gl_balance g WHERE g.site_id='101' AND g.Period='2026-01-01' AND g.AccountCode IN ('158-001','158-301','158-201','158-101') ORDER BY g.AccountCode;
-- Harapan: selisih = 0 semua.
-- 2) gl_balance 2026 tetap SEIMBANG (Dr=Cr):
SELECT CAST(SUM(AmountDebet) AS varchar) dr, CAST(SUM(AmountCredit) AS varchar) cr, CAST(SUM(AmountCredit)-SUM(AmountDebet) AS varchar) selisih
 FROM gl_balance WHERE site_id='101' AND Period='2026-01-01';
-- Harapan: selisih = 0.

-- =========================== ROLLBACK ==============================
-- UPDATE gl_balance g SET AmountDebet=b.AmountDebet, AmountCredit=b.AmountCredit
--   FROM gl_bal_bkp_20260717 b WHERE g.site_id=b.site_id AND g.Period=b.Period AND g.AccountCode=b.AccountCode; COMMIT;
-- (SA9: pakai subquery bila UPDATE..FROM tak didukung)
