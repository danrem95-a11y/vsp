$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
function Run($t1, $t2, $label) {
    $s = $sql -replace ':arg_tgl1', "'$t1'" -replace ':arg_tgl2', "'$t2'"
    $s = $s.TrimEnd().TrimEnd(';')
    $w = "SELECT COUNT(*) AS R, SUM(SALDO_AWAL_IDR) SA, SUM(MUTASI_IDR) MU, SUM(ADJ_IDR) AD, SUM(NILAI_BAYAR_IDR) BY1, SUM(SISA_IDR) SI FROM ($s) X"
    $c = $conn.CreateCommand(); $c.CommandText = $w; $c.CommandTimeout = 600
    $t0 = Get-Date
    $r = $c.ExecuteReader(); $r.Read() | Out-Null
    $sec = (New-TimeSpan $t0 (Get-Date)).TotalSeconds
    "$label|R=$($r['R'])|SA=$($r['SA'])|MU=$($r['MU'])|ADJ=$($r['AD'])|BYR=$($r['BY1'])|SISA=$($r['SI'])|sec=$sec"
    $r.Close()
}
$out = @()
$out += Run '2026-01-01' '2026-01-31' 'JAN26'
$out += Run '2026-02-01' '2026-02-28' 'FEB26'
$out += Run '2026-03-01' '2026-03-31' 'MAR26'
$conn.Close()
$out | Out-File c:\BTV\debug\diag48_out.txt -Encoding ascii
$out
