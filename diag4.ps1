$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Check if 226-006 vouchers exist in TBYR1
$cmd.CommandText = "SELECT COUNT(*) FROM TBYR1 WHERE VOUCHER IN ('200410126010088','200410126010069','200410126010086','200410126010212')"
$r = $cmd.ExecuteReader(); if($r.Read()){ $lines += "226-006 vouchers in TBYR1: $($r[0])" }; $r.Close()

# Which vendor IDs in SALDO_AWAL_FAKTUR TIPE=2 Jan2026 have ACCOUNTAP empty or non-226-001?
$cmd.CommandText = @"
SELECT S.VENDOR_ID, M.ACCOUNTAP, M.NAMA, SUM(S.NEW_SALDO) AS SA
FROM SALDO_AWAL_FAKTUR S
LEFT JOIN MCSTSUPP M ON M.VENDOR_ID = S.VENDOR_ID
WHERE S.TIPE_TRANS=2 AND MONTH(S.PERIODE)=1 AND YEAR(S.PERIODE)=2026
GROUP BY S.VENDOR_ID, M.ACCOUNTAP, M.NAMA
ORDER BY SA DESC
"@
$r = $cmd.ExecuteReader()
$lines += "=== ALL SAF TIPE=2 VENDORS WITH ACCOUNTAP ==="
$t = 0.0
while($r.Read()){
    $s=[double]$r["SA"]; $t+=$s
    $lines += "VID=$($r['VENDOR_ID'])  AP=$($r['ACCOUNTAP'])  SA=$([string]::Format('{0:N0}',$s))  NAMA=$($r['NAMA'])"
}
$lines += "TOTAL=$([string]::Format('{0:N2}',$t))"
$r.Close()

# GL 226-001 Jan2026 cust_id breakdown (which vendors appear)
$cmd.CommandText = "SELECT cust_id, SUM(debet) AS D, SUM(kredit) AS K FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-01-31' AND account_id='226-001' GROUP BY cust_id ORDER BY K DESC"
$r = $cmd.ExecuteReader(); $lines += "=== GL 226-001 BY CUST_ID ==="
while($r.Read()){ $lines += "CUST=$($r[0])  D=$([string]::Format('{0:N0}',[double]$r[1]))  K=$([string]::Format('{0:N0}',[double]$r[2]))" }
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag4_out.txt" -Encoding UTF8
Write-Host "Done"
