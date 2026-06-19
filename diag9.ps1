$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# ALL AP_TRANS Jan 2026 4SL.% - no TIPE filter, with ORDER_OKE
$cmd.CommandText = @"
SELECT TIPE_TRANS, ORDER_OKE, COUNT(*) AS JML, SUM(TTL_NETTO) AS TOTAL
FROM AP_TRANS
WHERE TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND VENDOR_ID LIKE '4SL.%'
GROUP BY TIPE_TRANS, ORDER_OKE
ORDER BY TOTAL DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS JAN2026 4SL.% BREAKDOWN ==="
while($r.Read()){ $lines += "TIPE=$($r[0])  OKE=$($r[1])  JML=$($r[2])  TOTAL=$([string]::Format('{0:N0}',[double]$r[3]))" }
$r.Close()

# Top AP_TRANS in Jan 2026 4SL.% ORDER_OKE='Y' by amount
$cmd.CommandText = @"
SELECT TOP 20 VENDOR_ID, TIPE_TRANS, BUKTI_REFF, TTL_NETTO, TGL
FROM AP_TRANS
WHERE TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND VENDOR_ID LIKE '4SL.%'
  AND ORDER_OKE = 'Y'
ORDER BY TTL_NETTO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== TOP AP_TRANS JAN2026 4SL.% ==="
$t=0.0; $cnt=0
while($r.Read()){
    $v=[double]$r["TTL_NETTO"]; $t+=$v; $cnt++
    $lines += "VID=$($r['VENDOR_ID'])  TIPE=$($r['TIPE_TRANS'])  REFF=$($r['BUKTI_REFF'])  NETTO=$([string]::Format('{0:N0}',$v))"
}
$lines += "TOP20_TOTAL=$([string]::Format('{0:N2}',$t))"
$r.Close()

# Check SALDO_AWAL_FAKTUR for Bingshan and TK to see their opening balance
$cmd.CommandText = @"
SELECT S.BUKTI_ID, S.NO_FAKTUR, S.VENDOR_ID, S.TIPE_TRANS, 
       S.NEW_SALDO, S.PERIODE, S.TGL_FAKTUR
FROM SALDO_AWAL_FAKTUR S
WHERE S.VENDOR_ID IN ('4SL.0301', '4SL.0309', '4SL.D014')
  AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026
ORDER BY S.VENDOR_ID, S.NEW_SALDO DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== SAF FOR TK+BINGSHAN ==="
while($r.Read()){ 
    $lines += "BUKTI=$($r['BUKTI_ID'])  FAKTUR=$($r['NO_FAKTUR'])  VID=$($r['VENDOR_ID'])  SA=$([string]::Format('{0:N0}',[double]$r['NEW_SALDO']))  PERIODE=$($r['PERIODE'])"
}
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag9_out.txt" -Encoding UTF8
Write-Host "Done"
