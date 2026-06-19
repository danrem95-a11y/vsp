$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$s = $sql -replace ':arg_tgl1', "'2026-02-01'" -replace ':arg_tgl2', "'2026-02-28'"
$s = $s.TrimEnd().TrimEnd(';')
$q = "SELECT ORDER_CLIENT, SALDO_AWAL_IDR, MUTASI_IDR, ADJ_IDR, NILAI_BAYAR_IDR, SISA_IDR FROM ($s) X WHERE ORDER_CLIENT LIKE '101BTB251200032%' OR ORDER_CLIENT='101BTB251200032'"
$c = $conn.CreateCommand(); $c.CommandText = $q; $c.CommandTimeout = 600
$r = $c.ExecuteReader()
$found = $false
while ($r.Read()) {
  $found = $true
  Write-Host "FOUND: OC=[$($r['ORDER_CLIENT'])] len=$($r['ORDER_CLIENT'].ToString().Length) SA=$($r['SALDO_AWAL_IDR']) MU=$($r['MUTASI_IDR']) BYR=$($r['NILAI_BAYAR_IDR']) SISA=$($r['SISA_IDR'])"
}
if (-not $found) { Write-Host "NOT FOUND in Feb output for voucher 101BTB251200032" }
$r.Close(); $conn.Close()
