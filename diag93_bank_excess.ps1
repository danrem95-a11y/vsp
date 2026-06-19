$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag93_bank_excess_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
try { $conn.Open() } catch { "CONN ERROR: $_" | Set-Content $outFile; exit }

function RunQuery($label, $sql) {
    $output.Add(""); $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t")); $output.Add(("-"*80))
        $cnt=0
        while($rdr.Read()){
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t")); $cnt++
        }
        $rdr.Close(); $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# 1. GL_BALANCE for ALL bank accounts - check opening total
RunQuery "GL_BALANCE for BS2011 accounts (ALL periods)" @"
SELECT gb.AccountCode, a.AccountDes, gb.Period,
       gb.AmountDebet, gb.AmountCredit,
       gb.AmountDebet - gb.AmountCredit as net
FROM gl_balance gb
JOIN gl_acc a ON a.AccountCode = gb.AccountCode
WHERE a.FinCatCode = 'BS2011'
ORDER BY gb.AccountCode, gb.Period
"@

# 2. TOTAL opening balance for bank - should be 10,561,210,732.80
RunQuery "TOTAL GL_BALANCE BS2011 at 2026-01-01" @"
SELECT SUM(AmountDebet) as total_debet, SUM(AmountCredit) as total_credit,
       SUM(AmountDebet - AmountCredit) as net
FROM gl_balance gb
JOIN gl_acc a ON a.AccountCode = gb.AccountCode
WHERE a.FinCatCode = 'BS2011'
  AND gb.Period = '2026-01-01'
"@

# 3. CHECK: gl_journal for bank with DIFFERENT show_hide values
RunQuery "GL_JOURNAL bank (101-xxx) by show_hide value Jan 2026" @"
SELECT isnull(show_hide,'(null)') as show_hide,
       COUNT(*) as cnt,
       SUM(debet) as total_debet, SUM(kredit) as total_kredit,
       SUM(debet) - SUM(kredit) as net
FROM gl_journal
WHERE account_id LIKE '101%'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
GROUP BY isnull(show_hide,'(null)')
ORDER BY show_hide
"@

# 4. SAME but ALL dates (not just Jan) - check if show_hide entries exist at all
RunQuery "GL_JOURNAL bank (101-xxx) show_hide breakdown ALL dates" @"
SELECT isnull(show_hide,'(null)') as show_hide,
       COUNT(*) as cnt,
       SUM(debet) as total_debet, SUM(kredit) as total_kredit
FROM gl_journal
WHERE account_id LIKE '101%'
GROUP BY isnull(show_hide,'(null)')
ORDER BY show_hide
"@

# 5. Bank saldo WITH show_hide=0 included (arg_show=1 scenario)
RunQuery "Bank saldo Jan31 2026 WITH show_hide=0 included" @"
SELECT SUM(
    (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
    + ISNULL((SELECT SUM(debet)-SUM(kredit) FROM gl_journal g
              WHERE g.account_id=a.AccountCode
                AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'),0)
) as saldo_incl_showhide
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode=a.AccountCode AND gb.Period='2026-01-01'
WHERE a.FinCatCode='BS2011' AND a.DetailYN='1'
"@

# 6. CHECK SKAS table for bank accounts
RunQuery "SKAS table for bank kas_id (Jan 2026)" @"
SELECT s.KAS_ID, m.NAMA, m.ACCOUNT_ID, m.FLAG_KAS,
       s.PERIODE, s.SALDO, s.SITE_ID
FROM SKAS s
JOIN MKAS m ON m.KAS_ID = s.KAS_ID
WHERE m.FLAG_KAS = 'B'
  AND s.PERIODE >= '2025-01-01' AND s.PERIODE <= '2026-12-31'
ORDER BY s.KAS_ID, s.PERIODE
"@

# 7. LOOK FOR the extra 76,610,000:
# Check if any gl_journal entry for bank has debet = exactly 76,610,000
RunQuery "GL_JOURNAL bank entries with debet approx 76.6M" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id, show_hide
FROM gl_journal
WHERE account_id LIKE '101%'
  AND (debet BETWEEN 76000000 AND 77500000 OR kredit BETWEEN 76000000 AND 77500000)
ORDER BY tgl, voucher
"@

# 8. Check if there are DUPLICATE gl_journal entries for bank (same voucher_manual same account)
RunQuery "DUPLICATE bank GL entries Jan 2026" @"
SELECT account_id, voucher_manual, COUNT(*) as cnt,
       SUM(debet) as total_debet, SUM(kredit) as total_kredit
FROM gl_journal
WHERE account_id LIKE '101%'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
GROUP BY account_id, voucher_manual
HAVING COUNT(*) > 1
ORDER BY total_debet DESC
"@

# 9. What is the EXACT breakdown that would give 4,452,652,816.79?
# Test: what if gl_balance period is 2025-01-01 instead of 2026-01-01?
RunQuery "GL_BALANCE BS2011 at 2025-01-01" @"
SELECT SUM(AmountDebet) as total_debet, SUM(AmountCredit) as total_credit,
       SUM(AmountDebet - AmountCredit) as net
FROM gl_balance gb
JOIN gl_acc a ON a.AccountCode = gb.AccountCode
WHERE a.FinCatCode = 'BS2011'
  AND gb.Period = '2025-01-01'
"@

# 10. What is the EXACT sum using SKAS as opening balance (instead of gl_balance)?
RunQuery "If SKAS used as opening for bank (SKAS saldo 2025-12)" @"
SELECT s.KAS_ID, m.ACCOUNT_ID, m.NAMA,
       s.SALDO as skas_saldo,
       (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) as gl_balance_saldo,
       s.SALDO - (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) as diff
FROM SKAS s
JOIN MKAS m ON m.KAS_ID = s.KAS_ID
LEFT JOIN gl_balance gb ON gb.AccountCode = m.ACCOUNT_ID AND gb.Period = '2026-01-01'
WHERE m.FLAG_KAS = 'B'
  AND s.PERIODE = '2025-12-01'
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
