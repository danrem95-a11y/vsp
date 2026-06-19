$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== CLEANUP DP Bank Wrong Entries - $(Get-Date) ==="

# STEP 1: Find wrong CI GL entries for ALL DP vouchers
$out += ""
$out += "=== STEP 1: Wrong modul_id=CI GL entries for DP vouchers (ALL periods) ==="
$cmd.CommandText = @"
SELECT j.voucher, j.voucher_manual, j.account_id, j.debet, j.kredit,
       j.modul_id, j.tgl, j.ket
FROM gl_journal j
WHERE j.voucher_manual LIKE '%DPR%'
  AND j.modul_id = 'CI'
ORDER BY j.tgl, j.voucher_manual
"@
$reader = $cmd.ExecuteReader()
$wrong_ci = @()
while ($reader.Read()) {
    $row = "v=[$($reader[0])] vm=[$($reader[1])] acc=$($reader[2]) Dr=$($reader[3]) Cr=$($reader[4]) tgl=$($reader[6]) ket=[$($reader[7])]"
    $out += $row
    $wrong_ci += $row
}
$reader.Close()
$out += "Total wrong CI entries: $($wrong_ci.Count)"

# STEP 2: Delete wrong CI GL entries for DP vouchers  
$out += ""
if ($wrong_ci.Count -gt 0) {
    $out += "=== STEP 2: Deleting wrong modul_id=CI GL entries for DP vouchers ==="
    $cmd.CommandText = @"
DELETE FROM gl_journal
WHERE voucher_manual LIKE '%DPR%'
  AND modul_id = 'CI'
"@
    $cmd.ExecuteNonQuery() | Out-Null
    $cmd.CommandText = "COMMIT"
    $cmd.ExecuteNonQuery() | Out-Null
    $out += "Deleted $($wrong_ci.Count) wrong CI GL entries for DP vouchers."
} else {
    $out += "=== STEP 2: No wrong CI GL entries found - nothing to delete ==="
}

# STEP 3: Fix tbyr1.kas_id for ALL DP application records  
$out += ""
$out += "=== STEP 3: Fix tbyr1.kas_id = 0 for all DP application records ==="
$cmd.CommandText = @"
SELECT COUNT(*) FROM tbyr1
WHERE (voucher LIKE '%DPR%' OR keterangan LIKE '%Bayar dari DP%')
  AND flag_bayar = 1
  AND kas_id IS NOT NULL AND kas_id <> 0
"@
$reader2 = $cmd.ExecuteReader()
$reader2.Read() | Out-Null
$dpCount = [int]$reader2[0]
$reader2.Close()
$out += "tbyr1 DP records with wrong kas_id: $dpCount"

if ($dpCount -gt 0) {
    $cmd.CommandText = @"
UPDATE tbyr1 SET kas_id = 0
WHERE (voucher LIKE '%DPR%' OR keterangan LIKE '%Bayar dari DP%')
  AND flag_bayar = 1
  AND kas_id IS NOT NULL AND kas_id <> 0
"@
    $cmd.ExecuteNonQuery() | Out-Null
    $cmd.CommandText = "COMMIT"
    $cmd.ExecuteNonQuery() | Out-Null
    $out += "Updated $dpCount tbyr1 DP records: kas_id set to 0."
} else {
    $out += "No tbyr1 DP records with wrong kas_id found."
}

# STEP 4: Verify bank saldo
$out += ""
$out += "=== STEP 4: Verify bank saldo end Jan 2026 ==="
$cmd.CommandText = @"
SELECT SUM(g.AmountDebet) as opening_debet, SUM(g.AmountCredit) as opening_kredit
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-01-01'
  AND a.DetailYN = '1'
  AND a.FinCatCode = 'BS2011'
"@
$reader3 = $cmd.ExecuteReader()
$reader3.Read() | Out-Null
$opening_Dr = if ($reader3[0] -ne [DBNull]::Value) { [decimal]$reader3[0] } else { 0 }
$opening_Cr = if ($reader3[1] -ne [DBNull]::Value) { [decimal]$reader3[1] } else { 0 }
$reader3.Close()

$cmd.CommandText = @"
SELECT SUM(j.debet) as jan_debet, SUM(j.kredit) as jan_kredit
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2011'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
"@
$reader4 = $cmd.ExecuteReader()
$reader4.Read() | Out-Null
$jan_Dr = if ($reader4[0] -ne [DBNull]::Value) { [decimal]$reader4[0] } else { 0 }
$jan_Cr = if ($reader4[1] -ne [DBNull]::Value) { [decimal]$reader4[1] } else { 0 }
$reader4.Close()

$total_bank = $opening_Dr - $opening_Cr + $jan_Dr - $jan_Cr
$out += "Opening bank: Dr=$opening_Dr Cr=$opening_Cr"
$out += "Jan journal:  Dr=$jan_Dr Cr=$jan_Cr"
$out += "Computed bank saldo end Jan 2026: $total_bank"
if ([Math]::Abs($total_bank - 4376042816.79) -lt 1) {
    $out += "CORRECT: matches expected 4,376,042,816.79"
} elseif ([Math]::Abs($total_bank - 4452652816.79) -lt 1) {
    $out += "STILL WRONG: matches production wrong value 4,452,652,816.79"
    $out += "Check if there are more wrong entries not caught by this script."
} else {
    $out += "UNEXPECTED VALUE. Expected 4376042816.79, Got $total_bank"
}

$conn.Close()
$out | Set-Content "c:\BTV\debug\diag104_cleanup_dp_out.txt" -Encoding UTF8
Write-Host "Done. Results in diag104_cleanup_dp_out.txt"
