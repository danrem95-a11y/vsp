$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()

$lines = @()

# GL 226-001 cumulative BEFORE Jan 2026 (opening balance)
$cmd.CommandText = "SELECT SUM(debet) AS D, SUM(kredit) AS K FROM gl_journal WHERE tgl < '2026-01-01' AND account_id='226-001'"
$r = $cmd.ExecuteReader()
$lines += "=== GL 226-001 CUMULATIVE OPENING ==="
if($r.Read()){ $d=[double]$r[0]; $k=[double]$r[1]; $lines += "D=$([string]::Format('{0:N2}',$d))  K=$([string]::Format('{0:N2}',$k))  SALDO(K-D)=$([string]::Format('{0:N2}',($k-$d)))" }
$r.Close()

# GL 226-006 cumulative BEFORE Jan 2026
$cmd.CommandText = "SELECT SUM(debet) AS D, SUM(kredit) AS K FROM gl_journal WHERE tgl < '2026-01-01' AND account_id='226-006'"
$r = $cmd.ExecuteReader()
$lines += "=== GL 226-006 CUMULATIVE OPENING ==="
if($r.Read()){ $d=[double]$r[0]; $k=[double]$r[1]; $lines += "D=$([string]::Format('{0:N2}',$d))  K=$([string]::Format('{0:N2}',$k))  SALDO(K-D)=$([string]::Format('{0:N2}',($k-$d)))" }
$r.Close()

# GL 226-006 Jan 2026 entries
$cmd.CommandText = "SELECT voucher, tgl, debet, kredit, cust_id, ket FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-01-31' AND account_id='226-006' ORDER BY tgl"
$r = $cmd.ExecuteReader()
$lines += "=== GL 226-006 JAN2026 ENTRIES ==="
$td=0.0; $tk=0.0
while($r.Read()){
    $d=[double]$r["debet"]; $k=[double]$r["kredit"]; $td+=$d; $tk+=$k
    $lines += "V=$($r['voucher'])  TGL=$($r['tgl'])  D=$([string]::Format('{0:N0}',$d))  K=$([string]::Format('{0:N0}',$k))  CUST=$($r['cust_id'])  KET=$($r['ket'])"
}
$lines += "TOTAL D=$([string]::Format('{0:N2}',$td))  K=$([string]::Format('{0:N2}',$tk))"
$r.Close()

# Which vendors appear in 226-006 GL entries
$cmd.CommandText = "SELECT DISTINCT cust_id FROM gl_journal WHERE account_id='226-006' AND tgl BETWEEN '2026-01-01' AND '2026-01-31'"
$r = $cmd.ExecuteReader()
$lines += "=== 226-006 CUST_IDS ==="
while($r.Read()){ $lines += "CUST=$($r[0])" }
$r.Close()

# Check MCSTSUPP for those vendors: what is their ACCOUNTAP
$cmd.CommandText = "SELECT G.cust_id, M.ACCOUNTAP, M.NAMA FROM (SELECT DISTINCT cust_id FROM gl_journal WHERE account_id='226-006' AND tgl BETWEEN '2026-01-01' AND '2026-01-31') G LEFT JOIN MCSTSUPP M ON M.VENDOR_ID=G.cust_id"
$r = $cmd.ExecuteReader()
$lines += "=== 226-006 VENDORS IN MCSTSUPP ==="
while($r.Read()){ $lines += "CUST=$($r[0])  AP=$($r[1])  NAMA=$($r[2])" }
$r.Close()

# SALDO_AWAL_FAKTUR: for vendors in 226-006 how much is their saldo
$cmd.CommandText = "SELECT S.VENDOR_ID, SUM(S.NEW_SALDO) AS SA FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS=2 AND MONTH(S.PERIODE)=1 AND YEAR(S.PERIODE)=2026 AND S.VENDOR_ID IN (SELECT DISTINCT cust_id FROM gl_journal WHERE account_id='226-006' AND tgl BETWEEN '2026-01-01' AND '2026-01-31') GROUP BY S.VENDOR_ID"
$r = $cmd.ExecuteReader()
$lines += "=== SAF TIPE=2 FOR 226-006 VENDORS ==="
$ts = 0.0
while($r.Read()){ $s=[double]$r[1]; $ts+=$s; $lines += "VID=$($r[0])  SA=$([string]::Format('{0:N2}',$s))" }
$lines += "TOTAL=$([string]::Format('{0:N2}',$ts))"
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag3_out.txt" -Encoding UTF8
Write-Host "Done. Results in C:\BTV\debug\diag3_out.txt"
