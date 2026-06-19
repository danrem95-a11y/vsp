$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Check if TBYR1 payment vouchers appear in gl_journal for account 226-001
$cmd.CommandText = @"
SELECT T1.VOUCHER, T1.VENDOR_ID, T1.TGL, SUM(T2.NILAI_BAYAR_IDR) AS BAYAR,
       MAX(G.account_id) AS GL_ACC
FROM TBYR1 T1
JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
LEFT JOIN gl_journal G ON G.voucher = T1.VOUCHER AND G.tgl = T1.TGL
WHERE T1.FLAG_BAYAR = 2
  AND T1.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND T1.VENDOR_ID LIKE '4SL.%'
GROUP BY T1.VOUCHER, T1.VENDOR_ID, T1.TGL
ORDER BY T1.TGL, T1.VOUCHER
"@
$r = $cmd.ExecuteReader(); $lines += "=== TBYR1 JAN2026 vs GL ACCOUNT ==="
$t=0.0; $count=0
while($r.Read()){
    $b=[double]$r["BAYAR"]; $t+=$b; $count++
    $lines += "V=$($r['VOUCHER'])  VID=$($r['VENDOR_ID'])  GL=$($r['GL_ACC'])  BAYAR=$([string]::Format('{0:N0}',$b))"
}
$lines += "TOTAL=$([string]::Format('{0:N2}',$t))  COUNT=$count"
$r.Close()

# Check if TBYR1 payment vouchers match gl_journal.voucher at all
$cmd.CommandText = @"
SELECT COUNT(*) AS matched
FROM TBYR1 T1
JOIN gl_journal G ON G.voucher = T1.VOUCHER AND G.tgl = T1.TGL
WHERE T1.FLAG_BAYAR = 2 AND T1.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND T1.VENDOR_ID LIKE '4SL.%'
"@
$r = $cmd.ExecuteReader(); if($r.Read()){ $lines += "GL voucher matches (4SL. Jan2026): $($r[0])" }; $r.Close()

# Also try joining via voucher_manual
$cmd.CommandText = @"
SELECT COUNT(*) AS matched
FROM TBYR1 T1
JOIN gl_journal G ON G.voucher_manual = T1.VOUCHER
WHERE T1.FLAG_BAYAR = 2 AND T1.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND T1.VENDOR_ID LIKE '4SL.%'
"@
$r = $cmd.ExecuteReader(); if($r.Read()){ $lines += "GL voucher_manual matches (4SL. Jan2026): $($r[0])" }; $r.Close()

# Check TBYR1 for freight vendors specifically in Jan 2026
$cmd.CommandText = @"
SELECT T1.VENDOR_ID, T1.VOUCHER, T1.TGL, SUM(T2.NILAI_BAYAR_IDR) AS BAYAR
FROM TBYR1 T1
JOIN TBYR2 T2 ON T2.VOUCHER = T1.VOUCHER
WHERE T1.FLAG_BAYAR IN (1,2)
  AND T1.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND T1.VENDOR_ID IN ('4SL.M016','4SL.H018','4SL.L010','4SL.H016','4SL.M020','000.T003')
GROUP BY T1.VENDOR_ID, T1.VOUCHER, T1.TGL
ORDER BY T1.VENDOR_ID, T1.TGL
"@
$r = $cmd.ExecuteReader(); $lines += "=== FREIGHT VENDOR PAYMENTS IN TBYR1 ==="
$t=0.0
while($r.Read()){
    $b=[double]$r["BAYAR"]; $t+=$b
    $lines += "VID=$($r['VENDOR_ID'])  V=$($r['VOUCHER'])  TGL=$($r['TGL'])  BAYAR=$([string]::Format('{0:N0}',$b))"
}
$lines += "TOTAL=$([string]::Format('{0:N2}',$t))"
$r.Close()

# Check SAF TIPE=2 for freight vendors: new jan2026 invoices in AP_TRANS
$cmd.CommandText = @"
SELECT A.VENDOR_ID, A.VOUCHER, A.TGL, A.TTL_NETTO
FROM AP_TRANS A
WHERE A.TGL BETWEEN '2026-01-01' AND '2026-01-31'
  AND A.VENDOR_ID IN ('4SL.M016','4SL.H018','4SL.L010','4SL.H016','4SL.M020','000.T003')
  AND A.ORDER_OKE = 'Y'
  AND A.TIPE_TRANS IN ('02','05','06','12','16')
"@
$r = $cmd.ExecuteReader(); $lines += "=== FREIGHT VENDOR NEW INV JAN2026 ==="
$t=0.0
while($r.Read()){
    $v=[double]$r["TTL_NETTO"]; $t+=$v
    $lines += "VID=$($r['VENDOR_ID'])  V=$($r['VOUCHER'])  TGL=$($r['TGL'])  NETTO=$([string]::Format('{0:N0}',$v))"
}
$lines += "TOTAL=$([string]::Format('{0:N2}',$t))"
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag5_out.txt" -Encoding UTF8
Write-Host "Done"
