$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$t1='2026-03-01'; $t2='2026-03-31'
$s = $sql -replace ':arg_tgl1', "'$t1'" -replace ':arg_tgl2', "'$t2'"
$s = $s.TrimEnd().TrimEnd(';')
$plan = "SELECT GRAPHICAL_PLAN('$( $s -replace ""'"", ""''"" )', 0, 'STATISTICS')"
try {
    $c = $conn.CreateCommand(); $c.CommandText = $plan; $c.CommandTimeout = 300
    $r = $c.ExecuteReader(); $r.Read() | Out-Null
    $r[0] | Out-File c:\BTV\debug\plan_mar.xml -Encoding utf8
    $r.Close()
    "plan saved $(((Get-Item c:\BTV\debug\plan_mar.xml).Length)) bytes"
} catch {
    "err: $($_.Exception.Message)"
}
$conn.Close()
