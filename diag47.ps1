$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$s = $sql -replace ':arg_tgl1', "'2026-01-01'" -replace ':arg_tgl2', "'2026-01-31'"
$s = $s.TrimEnd().TrimEnd(';')
$wrap = "SELECT COUNT(*) AS ROWS, SUM(SALDO_AWAL_IDR) AS SA, SUM(MUTASI_IDR) AS MU, SUM(NILAI_BAYAR_IDR) AS BYR, SUM(SISA_IDR) AS SISA FROM ($s) X"
$cmd = $conn.CreateCommand(); $cmd.CommandText = $wrap; $cmd.CommandTimeout = 300
$r = $cmd.ExecuteReader(); $r.Read() | Out-Null
$out = "ROWS=$($r['ROWS']) SA=$($r['SA']) MU=$($r['MU']) BYR=$($r['BYR']) SISA=$($r['SISA'])"
$r.Close()
$conn.Close()
$out | Out-File c:\BTV\debug\diag47_out.txt -Encoding ascii
$out
