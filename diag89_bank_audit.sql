-- ============================================================
-- DIAG89: BANK AUDIT - Neraca Bank Discrepancy Investigation
-- Periode: 01-01-2026 s/d 31-01-2026
-- Selisih: 76.609.999,79 (terlalu tinggi)
-- ============================================================

-- ==== BAGIAN A: Temukan akun BANK ====

-- A1. Daftar akun bank dari setup
SELECT 'BANK_ACCOUNTS' AS query_id
SELECT acc_bank1, acc_bank2, acc_bank3, acc_bank4, acc_bank5,
       acc_kas1, acc_kas2, acc_kas3
FROM gl_setup;

-- A2. Semua account_id yang memiliki kas_id di gl_journal (modul CO dan CI)
--     periode Jan 2026 - ini adalah akun-akun BANK/KAS
SELECT 'BANK_FROM_GL' AS query_id
SELECT DISTINCT g.account_id, a.acc_name, g.modul_id
FROM gl_journal g
LEFT JOIN coa a ON a.account_id = g.account_id
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
ORDER BY g.account_id;

-- ==== BAGIAN B: Saldo Bank dari gl_journal ====

-- B1. Saldo per account_id untuk akun kas/bank (modul CO = bayar hutang, CI = terima piutang)
SELECT 'BANK_BALANCE_BY_ACCOUNT' AS query_id
SELECT
    g.account_id,
    a.acc_name,
    SUM(g.debet)  AS total_debet,
    SUM(g.kredit) AS total_kredit,
    SUM(g.debet - g.kredit) AS net_balance
FROM gl_journal g
LEFT JOIN coa a ON a.account_id = g.account_id
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.account_id, a.acc_name
ORDER BY g.account_id;

-- B2. Saldo Bank per modul_id (CO vs CI vs lainnya)
SELECT 'BANK_BY_MODUL' AS query_id
SELECT
    g.account_id,
    g.modul_id,
    COUNT(*) AS jumlah_baris,
    SUM(g.debet)  AS total_debet,
    SUM(g.kredit) AS total_kredit,
    SUM(g.debet - g.kredit) AS net
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.account_id, g.modul_id
ORDER BY g.account_id, g.modul_id;

-- ==== BAGIAN C: Cari Duplikasi ====

-- C1. voucher_manual yang muncul LEBIH DARI SEKALI di akun bank
SELECT 'DUPLICATE_VOUCHER_MANUAL' AS query_id
SELECT
    g.voucher_manual,
    g.account_id,
    g.modul_id,
    COUNT(*) AS cnt,
    SUM(g.debet) AS total_debet,
    SUM(g.kredit) AS total_kredit
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.voucher_manual, g.account_id, g.modul_id
HAVING COUNT(*) > 2
ORDER BY cnt DESC, g.voucher_manual;

-- C2. Duplikasi voucher (bukan voucher_manual) - cek apakah ada voucher yang masuk dua kali
SELECT 'DUPLICATE_VOUCHER' AS query_id
SELECT
    g.voucher,
    g.account_id,
    g.modul_id,
    COUNT(*) AS cnt,
    SUM(g.debet - g.kredit) AS net
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.voucher, g.account_id, g.modul_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- ==== BAGIAN D: Bandingkan GL vs tbyr1 ====

-- D1. Total bayar AP dari tbyr1 (sumber kebenaran pembayaran hutang)
SELECT 'TBYR1_AP_TOTAL' AS query_id
SELECT
    t1.kas_id,
    COUNT(DISTINCT t1.voucher) AS jumlah_payment,
    SUM(t2.nilai_bayar_idr) AS total_bayar_idr
FROM tbyr1 t1
JOIN tbyr2 t2 ON t2.voucher = t1.voucher
WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.flag_bayar = 2  -- AP payment
GROUP BY t1.kas_id
ORDER BY t1.kas_id;

-- D2. Total CO di gl_journal untuk bank (yang seharusnya = bayar hutang dari bank)
SELECT 'GL_CO_BANK_TOTAL' AS query_id
SELECT
    g.account_id,
    g.kas_id,
    COUNT(DISTINCT g.voucher_manual) AS jumlah_voucher,
    SUM(g.kredit) AS total_kredit_bank
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.modul_id = 'CO'
  AND g.kas_id > 0
  AND g.kredit > 0
GROUP BY g.account_id, g.kas_id
ORDER BY g.account_id;

-- D3. Pembayaran AP di tbyr1 yang TIDAK punya gl_journal CO entry
SELECT 'AP_PAYMENT_WITHOUT_GL' AS query_id
SELECT
    t1.voucher,
    t1.voucher_manual,
    t1.tgl,
    t1.vendor_id,
    SUM(t2.nilai_bayar_idr) AS total_bayar
FROM tbyr1 t1
JOIN tbyr2 t2 ON t2.voucher = t1.voucher
WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.flag_bayar = 2  -- AP payment
  AND NOT EXISTS (
      SELECT 1 FROM gl_journal g
      WHERE g.voucher_manual = t1.voucher_manual
        AND g.modul_id = 'CO'
  )
GROUP BY t1.voucher, t1.voucher_manual, t1.tgl, t1.vendor_id
ORDER BY t1.tgl;

-- D4. GL CO entries yang TIDAK punya tbyr1 (orphan GL entries)
SELECT 'ORPHAN_GL_CO' AS query_id
SELECT
    g.voucher,
    g.voucher_manual,
    g.tgl,
    g.account_id,
    g.kredit AS kredit_bank,
    g.debet AS debet_bank
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.modul_id = 'CO'
  AND g.kas_id > 0
  AND NOT EXISTS (
      SELECT 1 FROM tbyr1 t1
      WHERE t1.voucher_manual = g.voucher_manual
  )
ORDER BY g.tgl, g.voucher_manual;

-- ==== BAGIAN E: Selisih 76.609.999,79 ====

-- E1. Cari transaksi bank yang nilainya mendekati selisih
SELECT 'SUSPECT_TRANSACTIONS' AS query_id
SELECT
    g.voucher,
    g.voucher_manual,
    g.tgl,
    g.modul_id,
    g.account_id,
    g.debet,
    g.kredit,
    g.ket
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
  AND (
      ABS(g.debet - 76609999.79) < 1000
      OR ABS(g.kredit - 76609999.79) < 1000
      OR ABS(g.debet - 76610000) < 1000
  )
ORDER BY g.tgl;

-- E2. Cari kombinasi transaksi yang jumlahnya = selisih
SELECT 'GROUPED_SUSPECT' AS query_id
SELECT
    g.voucher_manual,
    g.account_id,
    g.modul_id,
    SUM(g.debet) AS total_debet,
    SUM(g.kredit) AS total_kredit,
    SUM(g.debet - g.kredit) AS net
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.voucher_manual, g.account_id, g.modul_id
HAVING ABS(SUM(g.debet - g.kredit) - 76609999.79) < 1000
    OR ABS(SUM(g.debet) - 76609999.79) < 1000
    OR ABS(SUM(g.kredit) - 76609999.79) < 1000
ORDER BY g.voucher_manual;

-- ==== BAGIAN F: Verifikasi GL saldo bank vs expected ====

-- F1. Saldo Awal + Mutasi Jan = Saldo Akhir per akun bank
SELECT 'BANK_RECONCILIATION' AS query_id
SELECT
    g.account_id,
    a.acc_name,
    -- saldo sebelum periode (semua s/d 31-12-2025)
    (SELECT COALESCE(SUM(g2.debet - g2.kredit), 0)
     FROM gl_journal g2
     WHERE g2.account_id = g.account_id
       AND g2.tgl < '2026-01-01') AS saldo_awal,
    SUM(g.debet)  AS mutasi_debet_jan,
    SUM(g.kredit) AS mutasi_kredit_jan,
    (SELECT COALESCE(SUM(g2.debet - g2.kredit), 0)
     FROM gl_journal g2
     WHERE g2.account_id = g.account_id
       AND g2.tgl < '2026-01-01')
    + SUM(g.debet - g.kredit) AS saldo_akhir_jan
FROM gl_journal g
LEFT JOIN coa a ON a.account_id = g.account_id
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.account_id, a.acc_name
ORDER BY g.account_id;

-- F2. Total semua akun bank Neraca (seharusnya = 4.376.042.817)
SELECT 'TOTAL_BANK_NERACA' AS query_id
SELECT
    SUM(CASE WHEN g.tgl < '2026-01-01'
             THEN g.debet - g.kredit ELSE 0 END) AS saldo_awal_total,
    SUM(CASE WHEN g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
             THEN g.debet ELSE 0 END) AS mutasi_debet_jan,
    SUM(CASE WHEN g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
             THEN g.kredit ELSE 0 END) AS mutasi_kredit_jan,
    SUM(CASE WHEN g.tgl <= '2026-01-31'
             THEN g.debet - g.kredit ELSE 0 END) AS saldo_akhir_total
FROM gl_journal g
WHERE g.kas_id > 0;
