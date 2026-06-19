$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$sFeb = $sql -replace ':arg_tgl1', "'2026-02-01'" -replace ':arg_tgl2', "'2026-02-28'"
# Replace outer WHERE clause with WHERE 1=1
$noFilter = [regex]::Replace($sFeb, '(?s)WHERE\s+ROUND\(\(MAIN\.SALDO_AWAL.*?ORDER BY', 'WHERE 1=1 ORDER BY')
# Verify replacement worked
if ($noFilter -eq $sFeb) { Write-Host "WARNING: replacement did NOT change SQL"; exit }
$noFilter = $noFilter.TrimEnd().TrimEnd(';')
$q = "SELECT ORDER_CLIENT, SALDO_AWAL_IDR, MUTASI_IDR, ADJ_IDR, NILAI_BAYAR_IDR, SISA_IDR FROM ($noFilter) X WHERE ORDER_CLIENT='101BTB251200032'"
$c = $conn.CreateCommand(); $c.CommandText = $q; $c.CommandTimeout = 600
$r = $c.ExecuteReader()
$found = $false
while ($r.Read()) {
  $found = $true
  Write-Host "OC=$($r['ORDER_CLIENT']) SA=$($r['SALDO_AWAL_IDR']) MU=$($r['MUTASI_IDR']) BYR=$($r['NILAI_BAYAR_IDR']) SISA=$($r['SISA_IDR'])"
}
if (-not $found) { Write-Host "Voucher NOT found in Feb output without WHERE filter" }
$r.Close(); $conn.Close()
