-- ============================================================
-- diag103_cleanup_dp_bank_wrong.sql
-- Fix wrong Bank Dr / AR Cr GL entries created by f_transfer_ar
-- for DP application (penerimaan dimuka) vouchers
--
-- ROOT CAUSE: f_re_dp() copied kas_id from original receipt into
-- tbyr1 DP application records. When cb_3 (AR/AP ONLY) ran and
-- called f_transfer_ar for DP vouchers, it created spurious:
--   Bank (101-011) Dr XX / AR (103-001) Cr XX  [modul_id='CI']
-- This causes bank kelebihan and piutang kekurangan.
--
-- SCOPE: Jan 2026 DP vouchers causing 76,610,000 excess:
--   2601DPR001: 20,000,000  (ANUGERAH MITRA, 2026-01-06)
--   2602DPR001: 16,983,000  (EAT MORE, 2026-01-22)
--   2602DPR002: 39,627,000  (EAT MORE, 2026-01-22)
-- ============================================================

-- STEP 1: PREVIEW - Check for wrong Bank+AR GL entries for DP vouchers
-- (modul_id='CI', created by f_transfer_ar)
SELECT j.voucher, j.voucher_manual, j.account_id, j.debet, j.kredit,
       j.modul_id, j.tgl, j.ket
FROM gl_journal j
WHERE j.voucher_manual IN ('2601DPR001','2602DPR001','2602DPR002')
  AND j.modul_id = 'CI'
ORDER BY j.voucher_manual, j.urut;

-- STEP 2: PREVIEW - Check tbyr1 kas_id for DP records (should be 0 after fix)
SELECT t1.voucher, t1.voucher_manual, t1.kas_id, t1.flag_bayar, t1.tgl,
       m.NAMA as bank_name, m.ACCOUNT_ID as bank_acc
FROM tbyr1 t1
LEFT JOIN MKAS m ON m.KAS_ID = t1.kas_id
WHERE (t1.voucher LIKE '%DPR%' OR t1.keterangan LIKE '%Bayar dari DP%')
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY t1.tgl;

-- ==============================================================
-- CLEANUP ACTIONS (run after reviewing STEP 1 and STEP 2 output)
-- Only run if STEP 1 returns wrong Bank/AR entries
-- ==============================================================

-- ACTION A: Delete wrong GL entries for Jan 2026 DP vouchers (modul_id='CI')
-- These were created by f_transfer_ar processing DP tbyr1 with wrong kas_id
DELETE FROM gl_journal
WHERE voucher_manual IN ('2601DPR001','2602DPR001','2602DPR002')
  AND modul_id = 'CI';
COMMIT;

-- ACTION B: Fix tbyr1 kas_id=0 for ALL DP application records
-- (prevents future wrong bank entries if f_transfer_ar runs again)
UPDATE tbyr1
SET kas_id = 0
WHERE (voucher LIKE '%DPR%' OR keterangan LIKE '%Bayar dari DP%')
  AND flag_bayar = 1
  AND kas_id IS NOT NULL
  AND kas_id <> 0;
COMMIT;

-- STEP 3: VERIFY - Bank balance after cleanup should be 4,376,042,816.79
SELECT 
    SUM(CASE WHEN a.FinCatCode = 'BS2011' THEN g.AmountDebet ELSE 0 END) as bank_debet_opening,
    SUM(CASE WHEN a.FinCatCode = 'BS2011' THEN g.AmountCredit ELSE 0 END) as bank_kredit_opening
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-01-01'
  AND a.DetailYN = '1';
