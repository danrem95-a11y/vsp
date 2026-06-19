$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Check TBYR1.GL_REFF for Jan2026 payments - does it match gl_journal.voucher?
$cmd.CommandText = @"
SELECT T1.VOUCHER, T1.GL_REFF, T1.VENDOR_ID, SUM(T2.NILAI_BAYAR_IDR) AS BAYAR,
       MAX(G.account_id) AS GL_ACC
FROM TBYR1 T1
JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
LEFT JOIN gl_journal G ON G.voucher = T1.GL_REFF AND G.debet > 0
WHERE T1.FLAG_BAYAR = 2
  AND T1.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND T1.VENDOR_ID LIKE '4SL.%'
GROUP BY T1.VOUCHER, T1.GL_REFF, T1.VENDOR_ID
ORDER BY T1.GL_REFF
"@
$r = $cmd.ExecuteReader(); $lines += "=== TBYR1 GL_REFF vs GL_JOURNAL ==="
$t226001=0.0; $tother=0.0; $tnomatch=0.0
while($r.Read()){
    $b=[double]$r["BAYAR"]; $acc=$r["GL_ACC"]
    $lines += "V=$($r['VOUCHER'])  GLREF=$($r['GL_REFF'])  VID=$($r['VENDOR_ID'])  GL=$acc  BAYAR=$([string]::Format('{0:N0}',$b))"
    if($acc -eq '226-001'){ $t226001+=$b }
    elseif($acc -ne [DBNull]::Value -and $acc -ne ''){ $tother+=$b }
    else { $tnomatch+=$b }
}
$lines += "TOTAL 226-001=$([string]::Format('{0:N2}',$t226001))  OTHER=$([string]::Format('{0:N2}',$tother))  NO_MATCH=$([string]::Format('{0:N2}',$tnomatch))"
$r.Close()

# AP_TRANS ACCOUNT_ID distribution for Jan2026 new invoices
$cmd.CommandText = @"
SELECT A.ACCOUNT_ID, A.TIPE_TRANS, COUNT(*) AS JML, SUM(A.TTL_NETTO) AS TOTAL
FROM AP_TRANS A
WHERE A.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02','05','06','12','16')
GROUP BY A.ACCOUNT_ID, A.TIPE_TRANS
ORDER BY TOTAL DESC
"@
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS JAN2026 BY ACCOUNT_ID ==="
while($r.Read()){ $lines += "ACC=$($r['ACCOUNT_ID'])  TIPE=$($r['TIPE_TRANS'])  JML=$($r[2])  TOTAL=$([string]::Format('{0:N2}',[double]$r[3]))" }
$r.Close()

# SAF ACCOUNT_ID for TIPE_TRANS=2 (if it has one)
$cmd.CommandText = "SELECT TOP 1 * FROM SALDO_AWAL_FAKTUR WHERE TIPE_TRANS=2"
$r = $cmd.ExecuteReader(); $lines += "=== SAF COLUMNS ==="
for($i=0;$i -lt $r.FieldCount;$i++){ $lines += ("$i" + ':' + $r.GetName($i)) }
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag8_out.txt" -Encoding UTF8
Write-Host "Done"
