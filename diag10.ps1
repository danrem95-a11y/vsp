$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Check if SAF BUKTI_IDs appear in gl_journal for account 226-001
$cmd.CommandText = @"
SELECT S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO, 
       MAX(G.account_id) AS GL_ACC, MAX(G.tgl) AS GL_TGL
FROM SALDO_AWAL_FAKTUR S
LEFT JOIN gl_journal G ON G.voucher = S.BUKTI_ID AND G.kredit > 0
WHERE S.TIPE_TRANS = 2
  AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026
GROUP BY S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO
ORDER BY S.NEW_SALDO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== SAF BUKTI_ID in GL_JOURNAL ==="
$t226=0.0; $tother=0.0; $tnull=0.0
while($r.Read()){
    $sa=[double]$r["NEW_SALDO"]; $acc=$r["GL_ACC"]; $gldate=$r["GL_TGL"]
    $lines += "BID=$($r['BUKTI_ID'])  VID=$($r['VENDOR_ID'])  SA=$([string]::Format('{0:N0}',$sa))  GL_ACC=$acc  GL_TGL=$gldate"
    if($acc -eq '226-001'){ $t226+=$sa }
    elseif($acc -ne [DBNull]::Value -and $acc -ne ''){ $tother+=$sa }
    else{ $tnull+=$sa }
}
$lines += "SA for 226-001=$([string]::Format('{0:N2}',$t226))  OTHER=$([string]::Format('{0:N2}',$tother))  NO_GL=$([string]::Format('{0:N2}',$tnull))"
$r.Close()

# Check SAF for freight vendors: what GL account do their BTBs post to?
$cmd.CommandText = @"
SELECT S.BUKTI_ID, S.VENDOR_ID, S.NEW_SALDO, G.account_id, G.kredit, G.tgl
FROM SALDO_AWAL_FAKTUR S
JOIN gl_journal G ON G.voucher = S.BUKTI_ID AND G.kredit > 0
WHERE S.TIPE_TRANS = 2
  AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026
  AND S.VENDOR_ID IN ('4SL.M016','4SL.H018','4SL.L010','4SL.H016')
"@
$r = $cmd.ExecuteReader(); $lines += "=== FREIGHT SAF in GL_JOURNAL ==="
while($r.Read()){
    $lines += "BID=$($r['BUKTI_ID'])  VID=$($r['VENDOR_ID'])  SA=$([string]::Format('{0:N0}',[double]$r['NEW_SALDO']))  GL_ACC=$($r['account_id'])  K=$($r['kredit'])"
}
$r.Close()

# Check AP_TRANS for Jan 2026 4SL.% -> gl_journal join via ORDER_CLIENT
$cmd.CommandText = @"
SELECT A.ORDER_CLIENT, A.VENDOR_ID, A.TIPE_TRANS, A.TTL_NETTO, 
       MAX(G.account_id) AS GL_ACC, MAX(G.kredit) AS GL_K
FROM AP_TRANS A
LEFT JOIN gl_journal G ON G.voucher = A.ORDER_CLIENT AND G.kredit > 0
WHERE A.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND A.VENDOR_ID LIKE '4SL.%'
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02','05','06','12','16')
GROUP BY A.ORDER_CLIENT, A.VENDOR_ID, A.TIPE_TRANS, A.TTL_NETTO
ORDER BY A.TTL_NETTO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS JAN2026 -> GL_JOURNAL VIA ORDER_CLIENT ==="
$t226=0.0; $tother=0.0; $tnull=0.0
while($r.Read()){
    $v=[double]$r["TTL_NETTO"]; $acc=$r["GL_ACC"]
    $lines += "OC=$($r['ORDER_CLIENT'])  VID=$($r['VENDOR_ID'])  TIPE=$($r['TIPE_TRANS'])  GL=$acc  NETTO=$([string]::Format('{0:N0}',$v))"
    if($acc -eq '226-001'){ $t226+=$v }
    elseif($acc -ne [DBNull]::Value -and $acc -ne ''){ $tother+=$v }
    else{ $tnull+=$v }
}
$lines += "TOTAL 226-001=$([string]::Format('{0:N2}',$t226))  OTHER=$([string]::Format('{0:N2}',$tother))  NO_GL=$([string]::Format('{0:N2}',$tnull))"
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag10_out.txt" -Encoding UTF8
Write-Host "Done"
