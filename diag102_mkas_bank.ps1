$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()

$out += "=== MKAS: kas_id=2004 ==="
$cmd.CommandText = "SELECT KAS_ID, NAMA, FLAG_KAS, ACCOUNT_ID, CURR_ID FROM MKAS WHERE KAS_ID = 2004"
$reader = $cmd.ExecuteReader()
while ($reader.Read()) {
    $out += "KAS_ID=$($reader[0]) NAMA=[$($reader[1])] FLAG=$($reader[2]) ACCOUNT_ID=$($reader[3]) CURR=$($reader[4])"
}
$reader.Close()

$out += ""
$out += "=== d_gl_bayar probe: what does it query? Check dw_update dataobject ==="
$out += "(d_gl_bayar is the AR refresh source - trying to infer from existing data)"

$out += ""
$out += "=== tbyr1: DP 2601DPR001 full detail ==="
$cmd.CommandText = @"
SELECT t1.*, m.NAMA, m.ACCOUNT_ID as bank_acc
FROM tbyr1 t1
LEFT JOIN MKAS m ON m.KAS_ID = t1.kas_id
WHERE t1.voucher = '2601DPR001'
"@
$reader2 = $cmd.ExecuteReader()
$fc = $reader2.FieldCount
# Print header
$hdr = @()
for ($c=0; $c -lt $fc; $c++) { $hdr += $reader2.GetName($c) }
$out += ($hdr -join " | ")
while ($reader2.Read()) {
    $row = @()
    for ($c=0; $c -lt $fc; $c++) { $row += "$($reader2[$c])" }
    $out += ($row -join " | ")
}
$reader2.Close()

$out += ""
$out += "=== gl_journal: Jan 2026 bank (101%) entries for CI module with amounts ==="
$cmd.CommandText = @"
SELECT j.voucher, j.voucher_manual, j.account_id, j.debet, j.kredit, j.modul_id, j.kas_id, j.ket
FROM gl_journal j
WHERE j.account_id LIKE '101%'
AND j.tgl >= '2026-01-01' AND j.tgl <= '2026-01-31'
AND j.modul_id = 'CI'
ORDER BY j.debet DESC
"@
$reader3 = $cmd.ExecuteReader()
$out += "voucher | vm | acc | debet | kredit | mod | kas_id | ket"
while ($reader3.Read()) {
    $out += "$($reader3[0]) | $($reader3[1]) | $($reader3[2]) | $($reader3[3]) | $($reader3[4]) | $($reader3[5]) | $($reader3[6]) | $($reader3[7])"
}
$reader3.Close()

$out += ""
$out += "=== gl_journal: Jan 2026 bank (101%) ALL entries count by debet amount ==="
$cmd.CommandText = @"
SELECT j.account_id, j.modul_id, SUM(j.debet) as total_debet, SUM(j.kredit) as total_kredit, COUNT(*) as cnt
FROM gl_journal j
WHERE j.account_id LIKE '101%'
AND j.tgl >= '2026-01-01' AND j.tgl <= '2026-01-31'
GROUP BY j.account_id, j.modul_id
ORDER BY j.modul_id, j.account_id
"@
$reader4 = $cmd.ExecuteReader()
$out += "account_id | modul_id | total_debet | total_kredit | cnt"
while ($reader4.Read()) {
    $out += "$($reader4[0]) | $($reader4[1]) | $($reader4[2]) | $($reader4[3]) | $($reader4[4])"
}
$reader4.Close()

$conn.Close()
$out | Set-Content "c:\BTV\debug\diag102_mkas_bank_out.txt" -Encoding UTF8
Write-Host "Done. Results in diag102_mkas_bank_out.txt"
