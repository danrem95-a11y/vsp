$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()
$lines = @()

# Actual gl_journal.voucher values for 226-001 Jan2026
$cmd.CommandText = "SELECT voucher, doc_reff, tgl, debet, kredit, ket FROM gl_journal WHERE account_id='226-001' AND tgl BETWEEN '2026-01-01' AND '2026-01-31' AND debet > 0 ORDER BY tgl"
$r = $cmd.ExecuteReader(); $lines += "=== GL 226-001 DEBET VOUCHERS ==="
while($r.Read()){ $lines += "V=$($r['voucher'])  DOC=$($r['doc_reff'])  TGL=$($r['tgl'])  D=$([string]::Format('{0:N0}',[double]$r['debet']))  KET=$($r['ket'])" }
$r.Close()

# GL 226-001 KREDIT (new invoices)
$cmd.CommandText = "SELECT voucher, doc_reff, tgl, kredit, ket FROM gl_journal WHERE account_id='226-001' AND tgl BETWEEN '2026-01-01' AND '2026-01-31' AND kredit > 0 ORDER BY tgl"
$r = $cmd.ExecuteReader(); $lines += "=== GL 226-001 KREDIT VOUCHERS ==="
while($r.Read()){ $lines += "V=$($r['voucher'])  DOC=$($r['doc_reff'])  TGL=$($r['tgl'])  K=$([string]::Format('{0:N0}',[double]$r['kredit']))  KET=$($r['ket'])" }
$r.Close()

# AP_TRANS columns
$cmd.CommandText = "SELECT TOP 1 * FROM AP_TRANS"
$r = $cmd.ExecuteReader(); $lines += "=== AP_TRANS COLUMNS ==="
for($i=0;$i -lt $r.FieldCount;$i++){ $lines += "{0}:{1}" -f $i,$r.GetName($i) }
$r.Close()

# TBYR1 columns
$cmd.CommandText = "SELECT TOP 1 * FROM TBYR1"
$r = $cmd.ExecuteReader(); $lines += "=== TBYR1 COLUMNS ==="
for($i=0;$i -lt $r.FieldCount;$i++){ $lines += "{0}:{1}" -f $i,$r.GetName($i) }
$r.Close()

$conn.Close()
$lines | Out-File "C:\BTV\debug\diag7_out.txt" -Encoding UTF8
Write-Host "Done"
