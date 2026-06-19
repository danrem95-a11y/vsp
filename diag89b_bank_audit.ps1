$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89b_bank_audit_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunQuery($label, $sql) {
    $output.Add("")
    $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 300
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for ($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t"))
        $output.Add(("-" * 60))
        $cnt=0
        while ($rdr.Read()) {
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t"))
            $cnt++
        }
        $rdr.Close()
        $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# STEP 1: Distinct bank accounts in gl_journal Jan 2026
RunQuery "STEP1: BANK ACCOUNTS IN GL_JOURNAL (kas_id>0, Jan2026)" @"
SELECT DISTINCT account_id, kas_id, modul_id,
       COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND kas_id > 0
GROUP BY account_id, kas_id, modul_id
ORDER BY account_id, modul_id
"@

# STEP 2: Total saldo bank keseluruhan Jan 2026
RunQuery "STEP2: TOTAL SALDO BANK (kas_id>0, Jan2026)" @"
SELECT
  COALESCE(SUM(debet),0) as total_debet,
  COALESCE(SUM(kredit),0) as total_kredit,
  COALESCE(SUM(debet),0) - COALESCE(SUM(kredit),0) as netto_movement
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND kas_id > 0
"@

# STEP 3: Duplikat voucher_manual dalam gl_journal bank
RunQuery "STEP3: DUPLIKAT VOUCHER_MANUAL BANK (COUNT>2) Jan2026" @"
SELECT voucher_manual, modul_id, account_id, kas_id,
       COUNT(*) as cnt,
       COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND kas_id > 0
  AND voucher_manual IS NOT NULL
  AND voucher_manual <> ''
GROUP BY voucher_manual, modul_id, account_id, kas_id
HAVING COUNT(*) > 2
ORDER BY cnt DESC
"@

# STEP 4: Total tbyr1 AP Jan 2026 vs GL CO bank kredit
RunQuery "STEP4: TBYR1 AP TOTAL (tbyr2) vs GL BANK KREDIT CO (Jan2026)" @"
SELECT 'TBYR2_AP_JML_BAYAR' as sumber,
       CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) as nilai,
       COUNT(DISTINCT t1.VOUCHER) as cnt_voucher
FROM tbyr1 t1
JOIN tbyr2 t2 ON t2.VOUCHER = t1.VOUCHER
WHERE t1.FLAG_BAYAR = '2'
  AND t1.TGL >= '2026-01-01' AND t1.TGL <= '2026-01-31'
UNION ALL
SELECT 'GL_BANK_KREDIT_CO' as sumber,
       CAST(SUM(kredit) AS DECIMAL(18,2)) as nilai,
       COUNT(DISTINCT voucher_manual) as cnt_voucher
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND modul_id = 'CO'
  AND kas_id > 0
"@

# STEP 5: Tbyr1 AP tanpa GL bank kredit (via VOUCHER_MANUAL link)
RunQuery "STEP5: TBYR1 AP TANPA GL BANK KREDIT (Jan2026)" @"
SELECT t1.VOUCHER, t1.TGL, t1.VENDOR_ID, t1.VOUCHER_MANUAL,
       t1.KETERANGAN,
       CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) as jml_bayar
FROM tbyr1 t1
LEFT JOIN tbyr2 t2 ON t2.VOUCHER = t1.VOUCHER
WHERE t1.FLAG_BAYAR = '2'
  AND t1.TGL >= '2026-01-01' AND t1.TGL <= '2026-01-31'
  AND NOT EXISTS (
    SELECT 1 FROM gl_journal g
    WHERE g.voucher_manual = t1.VOUCHER_MANUAL
      AND g.kas_id > 0
  )
GROUP BY t1.VOUCHER, t1.TGL, t1.VENDOR_ID, t1.VOUCHER_MANUAL, t1.KETERANGAN
ORDER BY t1.TGL, t1.VOUCHER
"@

# STEP 6: Orphan GL CO bank entries (no matching tbyr1.VOUCHER_MANUAL)
RunQuery "STEP6: ORPHAN GL CO BANK (TANPA MATCHING TBYR1) Jan2026" @"
SELECT g.voucher_manual, g.tgl, g.account_id, g.kas_id,
       g.debet, g.kredit, g.ket
FROM gl_journal g
WHERE g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'
  AND g.modul_id = 'CO'
  AND g.kas_id > 0
  AND (g.voucher_manual IS NULL
    OR g.voucher_manual = ''
    OR NOT EXISTS (
      SELECT 1 FROM tbyr1 t
      WHERE t.VOUCHER_MANUAL = g.voucher_manual
        AND t.FLAG_BAYAR = '2'
    ))
ORDER BY g.tgl, g.voucher_manual
"@

# STEP 7: Orphan GL CI bank entries (no matching AR receipt tbyr1)
RunQuery "STEP7: ORPHAN GL CI BANK (TANPA MATCHING TBYR1 AR) Jan2026" @"
SELECT g.voucher_manual, g.tgl, g.account_id, g.kas_id,
       g.debet, g.kredit, g.ket
FROM gl_journal g
WHERE g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'
  AND g.modul_id = 'CI'
  AND g.kas_id > 0
  AND (g.voucher_manual IS NULL
    OR g.voucher_manual = ''
    OR NOT EXISTS (
      SELECT 1 FROM tbyr1 t
      WHERE t.VOUCHER_MANUAL = g.voucher_manual
        AND t.FLAG_BAYAR = '1'
    ))
ORDER BY g.tgl, g.voucher_manual
"@

# STEP 8: Transaksi mendekati selisih 76,609,999
RunQuery "STEP8: TRANSAKSI MENDEKATI 76,609,999 (+-1000) Jan2026" @"
SELECT tgl, account_id, modul_id, kas_id, voucher, voucher_manual,
       debet, kredit, ket
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND (
    (debet IS NOT NULL AND ABS(debet - 76609999.79) <= 1000)
    OR (kredit IS NOT NULL AND ABS(kredit - 76609999.79) <= 1000)
    OR (debet IS NOT NULL AND ABS(debet - 76610000) <= 1000)
    OR (kredit IS NOT NULL AND ABS(kredit - 76610000) <= 1000)
  )
ORDER BY tgl
"@

# STEP 9: Transaksi mendekati 76,609,999 - any period (not just Jan)
RunQuery "STEP9: TRANSAKSI MENDEKATI 76,609,999 (+-1000) ALL DATES" @"
SELECT tgl, account_id, modul_id, kas_id, voucher, voucher_manual,
       debet, kredit, ket
FROM gl_journal
WHERE
  (debet IS NOT NULL AND ABS(debet - 76609999.79) <= 1000)
  OR (kredit IS NOT NULL AND ABS(kredit - 76609999.79) <= 1000)
  OR (debet IS NOT NULL AND ABS(debet - 76610000) <= 1000)
  OR (kredit IS NOT NULL AND ABS(kredit - 76610000) <= 1000)
ORDER BY tgl DESC
"@

# STEP 10: FX transaksi bank Jan 2026 (kredit_kurs <> kredit, nilai > 0)
RunQuery "STEP10: FX TRANSAKSI BANK (kredit_kurs<>kredit) Jan2026" @"
SELECT tgl, account_id, modul_id, kas_id, voucher_manual,
       kredit, kredit_kurs,
       kredit - kredit_kurs as selisih_kurs, ket
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND kas_id > 0
  AND kredit IS NOT NULL AND kredit <> 0
  AND kredit_kurs IS NOT NULL AND kredit_kurs <> kredit
ORDER BY ABS(kredit - kredit_kurs) DESC
"@

# STEP 11: Daily bank movement Jan 2026
RunQuery "STEP11: DAILY BANK MOVEMENT JAN2026 (kas_id>0)" @"
SELECT tgl,
       COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit,
       COALESCE(SUM(debet),0) - COALESCE(SUM(kredit),0) as netto,
       COUNT(*) as jml_trx
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND kas_id > 0
GROUP BY tgl
ORDER BY tgl
"@

# STEP 12: Top 20 kredit bank terbesar Jan 2026
RunQuery "STEP12: TOP 20 KREDIT BANK TERBESAR Jan2026" @"
SELECT TOP 20 tgl, account_id, modul_id, kas_id,
       voucher_manual, kredit, ket
FROM gl_journal
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND kas_id > 0
  AND kredit IS NOT NULL AND kredit > 0
ORDER BY kredit DESC
"@

# STEP 13: Summary tbyr1 AP Jan 2026 per vendor (top 20 by amount)
RunQuery "STEP13: TOP 20 AP VENDOR Jan2026 (tbyr2)" @"
SELECT TOP 20 t1.VENDOR_ID, t1.KETERANGAN,
       COUNT(*) as cnt_voucher,
       CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) as total_bayar
FROM tbyr1 t1
JOIN tbyr2 t2 ON t2.VOUCHER = t1.VOUCHER
WHERE t1.FLAG_BAYAR = '2'
  AND t1.TGL >= '2026-01-01' AND t1.TGL <= '2026-01-31'
GROUP BY t1.VENDOR_ID, t1.KETERANGAN
ORDER BY total_bayar DESC
"@

$conn.Close()

$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE. Output: $outFile"
