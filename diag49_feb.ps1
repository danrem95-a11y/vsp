$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$s = $sql -replace ':arg_tgl1', "'2026-02-01'" -replace ':arg_tgl2', "'2026-02-28'"
$s = $s.TrimEnd().TrimEnd(';')
$w = "SELECT COUNT(*) AS R, SUM(SALDO_AWAL_IDR) SA, SUM(MUTASI_IDR) MU, SUM(ADJ_IDR) AD, SUM(NILAI_BAYAR_IDR) BY1, SUM(SISA_IDR) SI FROM ($s) X"
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$c = $conn.CreateCommand(); $c.CommandText = $w; $c.CommandTimeout = 600
$t0 = Get-Date
$r = $c.ExecuteReader(); $r.Read() | Out-Null
$msg = "FEB26|R=$($r['R'])|SA=$($r['SA'])|MU=$($r['MU'])|ADJ=$($r['AD'])|BYR=$($r['BY1'])|SISA=$($r['SI'])|sec=$((New-TimeSpan $t0 (Get-Date)).TotalSeconds)"
$r.Close(); $conn.Close()
$msg | Out-File c:\BTV\debug\diag49_out.txt -Encoding ascii
$msg
