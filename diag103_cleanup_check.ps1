$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()

$out += "=== STEP 1: Wrong Bank+AR GL entries for Jan 2026 DP vouchers (modul_id=CI) ==="
$cmd.CommandText = @"
SELECT j.voucher, j.voucher_manual, j.account_id, j.debet, j.kredit,
       j.modul_id, j.tgl, j.ket
FROM gl_journal j
WHERE j.voucher_manual IN ('2601DPR001','2602DPR001','2602DPR002')
  AND j.modul_id = 'CI'
ORDER BY j.voucher_manual, j.urut
"@
$reader = $cmd.ExecuteReader()
$cnt = 0
while ($reader.Read()) {
    $out += "v=[$($reader[0])] vm=[$($reader[1])] acc=$($reader[2]) Dr=$($reader[3]) Cr=$($reader[4]) mod=$($reader[5]) tgl=$($reader[6]) ket=[$($reader[7])]"
    $cnt++
}
$reader.Close()
if ($cnt -eq 0) { $out += "(none found - local DB is clean)" }
$out += "Total wrong CI entries: $cnt"

$out += ""
$out += "=== STEP 2: tbyr1 kas_id for Jan 2026 DP records ==="
$cmd.CommandText = @"
SELECT t1.voucher, t1.voucher_manual, t1.kas_id, t1.flag_bayar, t1.tgl,
       m.NAMA as bank_name, m.ACCOUNT_ID as bank_acc
FROM tbyr1 t1
LEFT JOIN MKAS m ON m.KAS_ID = t1.kas_id
WHERE (t1.voucher LIKE '%DPR%' OR t1.keterangan LIKE '%Bayar dari DP%')
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
ORDER BY t1.tgl
"@
$reader2 = $cmd.ExecuteReader()
while ($reader2.Read()) {
    $out += "v=[$($reader2[0])] vm=[$($reader2[1])] kas_id=[$($reader2[2])] flag=$($reader2[3]) tgl=$($reader2[4]) bank=[$($reader2[5])/acc:$($reader2[6])]"
}
$reader2.Close()

$out += ""
$out += "=== STEP 3: Bank (101%) balance Jan 2026 ==="
$cmd.CommandText = @"
SELECT 
    SUM(j.debet) as total_debet,
    SUM(j.kredit) as total_kredit,
    SUM(j.debet) - SUM(j.kredit) as net
FROM gl_journal j
WHERE j.account_id LIKE '101%'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
"@
$reader3 = $cmd.ExecuteReader()
while ($reader3.Read()) {
    $out += "Bank Jan debet=$($reader3[0]) kredit=$($reader3[1]) net=$($reader3[2])"
}
$reader3.Close()

$out += ""
$out += "=== STEP 4: Saldo bank (opening + Jan) ==="
$cmd.CommandText = @"
SELECT 
    SUM(g.AmountDebet) as opening_debet,
    SUM(g.AmountCredit) as opening_kredit
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-01-01'
  AND a.DetailYN = '1'
  AND a.FinCatCode = 'BS2011'
"@
$reader4 = $cmd.ExecuteReader()
while ($reader4.Read()) {
    $out += "Opening bank debet=$($reader4[0]) kredit=$($reader4[1])"
    $opening_Dr = [decimal]$reader4[0]
    $opening_Cr = [decimal]$reader4[1]
}
$reader4.Close()

# Calculate total bank
$cmd.CommandText = @"
SELECT SUM(j.debet) as jan_debet, SUM(j.kredit) as jan_kredit
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2011'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
"@
$reader5 = $cmd.ExecuteReader()
while ($reader5.Read()) {
    $jan_Dr = if ($reader5[0] -ne [DBNull]::Value) { [decimal]$reader5[0] } else { 0 }
    $jan_Cr = if ($reader5[1] -ne [DBNull]::Value) { [decimal]$reader5[1] } else { 0 }
    $out += "Jan journal bank debet=$jan_Dr kredit=$jan_Cr"
}
$reader5.Close()

$total_bank = $opening_Dr - $opening_Cr + $jan_Dr - $jan_Cr
$out += "=== COMPUTED BANK SALDO (end Jan 2026): $total_bank ==="
$out += "Expected: 4376042816.79"
$out += "Production wrong: 4452652816.79"
$out += "Diff: $($total_bank - 4376042816.79)"

$conn.Close()
$out | Set-Content "c:\BTV\debug\diag103_cleanup_check_out.txt" -Encoding UTF8
Write-Host "Done. Results in diag103_cleanup_check_out.txt"
