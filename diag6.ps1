$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Verify stripped-P join: TBYR1 Jan2026 4SL.% → gl_journal.account_id
$cmd.CommandText = @"
SELECT T1.VOUCHER, T1.VENDOR_ID, SUM(T2.NILAI_BAYAR_IDR) AS BAYAR,
       SUBSTRING(T1.VOUCHER, 1, LENGTH(T1.VOUCHER)-1) AS VCR_GL,
       MAX(G.account_id) AS GL_ACC
FROM TBYR1 T1
JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
LEFT JOIN gl_journal G ON G.voucher = SUBSTRING(T1.VOUCHER, 1, LENGTH(T1.VOUCHER)-1)
                       AND G.debet > 0
WHERE T1.FLAG_BAYAR = 2
  AND T1.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND T1.VENDOR_ID LIKE '4SL.%'
GROUP BY T1.VOUCHER, T1.VENDOR_ID
ORDER BY T1.VENDOR_ID
"@
$r = $cmd.ExecuteReader(); $lines += "=== TBYR1 GL_ACC VIA STRIPPED VOUCHER ==="
$t226001=0.0; $tother=0.0; $tnomatch=0.0
while($r.Read()){
    $b=[double]$r["BAYAR"]; $acc=$r["GL_ACC"]
    $lines += "V=$($r['VOUCHER'])  VID=$($r['VENDOR_ID'])  GL=$acc  BAYAR=$([string]::Format('{0:N0}',$b))"
    if($acc -eq '226-001'){ $t226001+=$b }
    elseif($acc -ne [DBNull]::Value -and $acc -ne ''){ $tother+=$b }
    else { $tnomatch+=$b }
}
$lines += "TOTAL 226-001=$([string]::Format('{0:N2}',$t226001))  OTHER=$([string]::Format('{0:N2}',$tother))  NO_MATCH=$([string]::Format('{0:N2}',$tnomatch))"
$r.Close()

# Check AP_TRANS voucher format for Jan2026 4SL.% new invoices
$cmd.CommandText = @"
SELECT TOP 5 A.VOUCHER, A.VENDOR_ID, A.TGL, A.TTL_NETTO, A.TIPE_TRANS
FROM AP_TRANS A
WHERE A.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND A.VENDOR_ID LIKE '4SL.%'
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02','05','06','12','16')
"@
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS SAMPLE VOUCHERS ==="
while($r.Read()){ $lines += "V=$($r['VOUCHER'])  VID=$($r['VENDOR_ID'])  TIPE=$($r['TIPE_TRANS'])  NETTO=$([string]::Format('{0:N0}',[double]$r['TTL_NETTO']))" }
$r.Close()

# AP_TRANS for 4SL.% Jan2026 via gl_journal: which GL account?
$cmd.CommandText = @"
SELECT A.VENDOR_ID, A.VOUCHER, A.TTL_NETTO,
       MAX(G.account_id) AS GL_ACC
FROM AP_TRANS A
LEFT JOIN gl_journal G ON G.voucher = A.VOUCHER AND G.kredit > 0
WHERE A.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND A.VENDOR_ID LIKE '4SL.%'
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02','05','06','12','16')
GROUP BY A.VENDOR_ID, A.VOUCHER, A.TTL_NETTO
ORDER BY GL_ACC, A.VENDOR_ID
"@
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS JAN2026 GL ACCOUNT ==="
$t226001=0.0; $tother=0.0; $tnomatch=0.0
while($r.Read()){
    $v=[double]$r["TTL_NETTO"]; $acc=$r["GL_ACC"]
    $lines += "VID=$($r['VENDOR_ID'])  V=$($r['VOUCHER'])  GL=$acc  NETTO=$([string]::Format('{0:N0}',$v))"
    if($acc -eq '226-001'){ $t226001+=$v }
    elseif($acc -ne [DBNull]::Value -and $acc -ne ''){ $tother+=$v }
    else{ $tnomatch+=$v }
}
$lines += "TOTAL 226-001=$([string]::Format('{0:N2}',$t226001))  OTHER=$([string]::Format('{0:N2}',$tother))  NO_MATCH=$([string]::Format('{0:N2}',$tnomatch))"
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag6_out.txt" -Encoding UTF8
Write-Host "Done"
