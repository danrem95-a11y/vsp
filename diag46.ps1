$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunScenario($label, $override) {
    $s = $sql `
      -replace ':arg_tgl1', "'2026-01-01'" `
      -replace ':arg_tgl2', "'2026-01-31'" `
      -replace ':arg_sa_override', $override
    $s = $s.TrimEnd().TrimEnd(';')
    $wrap = "SELECT COUNT(*) AS ROWS, SUM(SALDO_AWAL_IDR) AS SA, SUM(MUTASI_IDR) AS MU, SUM(ADJ_IDR) AS ADJ, SUM(NILAI_BAYAR_IDR) AS BYR, SUM(SISA_IDR) AS SISA FROM ($s) X"
    $cmd = $conn.CreateCommand(); $cmd.CommandText = $wrap; $cmd.CommandTimeout = 300
    $r = $cmd.ExecuteReader(); $r.Read() | Out-Null
    "$label|ROWS=$($r['ROWS'])|SA=$($r['SA'])|MU=$($r['MU'])|ADJ=$($r['ADJ'])|BYR=$($r['BYR'])|SISA=$($r['SISA'])"
    $r.Close()
}

$out = @()
$out += RunScenario 'A_DEFAULT_0' '0'
$out += RunScenario 'B_OVERRIDE_AUDIT' '14159923466.61'
$out | Out-File c:\BTV\debug\diag46_out.txt -Encoding ascii
$conn.Close()
Get-Content c:\BTV\debug\diag46_out.txt
