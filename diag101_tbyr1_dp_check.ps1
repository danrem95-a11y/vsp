$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()

$out += "=== tbyr1: DP-related records (2026) ==="
$cmd.CommandText = @"
SELECT t1.voucher, t1.voucher_manual, t1.kas_id, t1.flag_bayar, t1.tgl, 
       t1.keterangan
FROM tbyr1 t1
WHERE (t1.voucher LIKE '%DPR%' OR t1.voucher_manual LIKE '%DPR%' 
       OR t1.keterangan LIKE '%Bayar dari DP%')
AND tgl >= '2026-01-01'
ORDER BY t1.tgl
"@
$reader = $cmd.ExecuteReader()
while ($reader.Read()) {
    $out += "voucher=[$($reader[0])] vm=[$($reader[1])] kas_id=[$($reader[2])] flag=[$($reader[3])] tgl=$($reader[4]) ket=[$($reader[5])]"
}
$reader.Close()

$out += ""
$out += "=== gl_journal: bank entries (101%) Jan 2026 with debet near 20M or 56.61M ==="
$cmd.CommandText = @"
SELECT j.voucher, j.voucher_manual, j.account_id, j.debet, j.kredit, j.modul_id, j.ket
FROM gl_journal j
WHERE j.account_id LIKE '101%'
AND j.tgl >= '2026-01-01' AND j.tgl < '2026-02-01'
AND (ABS(j.debet - 20000000) < 1000 
  OR ABS(j.debet - 16983000) < 1000
  OR ABS(j.debet - 39627000) < 1000
  OR ABS(j.debet - 56610000) < 1000
  OR ABS(j.debet - 76610000) < 1000)
ORDER BY j.tgl, j.debet
"@
$reader2 = $cmd.ExecuteReader()
while ($reader2.Read()) {
    $out += "v=[$($reader2[0])] vm=[$($reader2[1])] acc=$($reader2[2]) Dr=$($reader2[3]) Cr=$($reader2[4]) mod=$($reader2[5]) ket=[$($reader2[6])]"
}
$reader2.Close()

$out += ""
$out += "=== gl_journal: all DP voucher entries ==="
$cmd.CommandText = @"
SELECT j.voucher, j.voucher_manual, j.account_id, j.debet, j.kredit, j.modul_id, j.urut, j.kas_id
FROM gl_journal j
WHERE (j.voucher_manual LIKE '%2601DPR%' OR j.voucher_manual LIKE '%2602DPR%'
    OR j.voucher LIKE '%2601DPR%' OR j.voucher LIKE '%2602DPR%')
ORDER BY j.voucher_manual, j.urut
"@
$reader3 = $cmd.ExecuteReader()
while ($reader3.Read()) {
    $out += "v=[$($reader3[0])] vm=[$($reader3[1])] acc=$($reader3[2]) Dr=$($reader3[3]) Cr=$($reader3[4]) mod=$($reader3[5]) urut=$($reader3[6]) kas_id=[$($reader3[7])]"
}
$reader3.Close()

$out += ""
$out += "=== tbyr2: DP-related records ==="
$cmd.CommandText = @"
SELECT t2.voucher, t2.bukti_id, t2.acc_bayar, t2.nilai_bayar, t2.nilai_bayar_idr, t2.flag_order
FROM tbyr2 t2
WHERE (t2.voucher LIKE '%DPR%' OR t2.bukti_id LIKE '%DPR%')
AND t2.voucher IN (SELECT voucher FROM tbyr1 WHERE tgl >= '2026-01-01')
ORDER BY t2.voucher
"@
$reader4 = $cmd.ExecuteReader()
while ($reader4.Read()) {
    $out += "v=[$($reader4[0])] bukti=[$($reader4[1])] acc_bayar=$($reader4[2]) nilai=$($reader4[3]) idr=$($reader4[4]) flag=$($reader4[5])"
}
$reader4.Close()

$conn.Close()
$out | Set-Content "c:\BTV\debug\diag101_tbyr1_dp_check_out.txt" -Encoding UTF8
Write-Host "Done. Results in diag101_tbyr1_dp_check_out.txt"
