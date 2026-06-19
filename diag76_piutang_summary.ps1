$ErrorActionPreference = 'Stop'
$sql = Get-Content 'c:\BTV\debug\qry_opname_piutang.sql' -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

try {
    $s = $sql -replace ':arg_tgl1', "'2026-01-01'" -replace ':arg_tgl2', "'2026-01-31'"
    $s = $s.TrimEnd().TrimEnd(';')
    $wrap = "SELECT COUNT(*) AS ROWS, SUM(SALDO_AWAL_IDR) AS SA, SUM(MUTASI_IDR) AS MU, SUM(ADJ_IDR) AS ADJ, SUM(NILAI_BAYAR_IDR) AS BYR, SUM(SISA_IDR) AS SISA FROM ($s) X"
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $wrap
    $cmd.CommandTimeout = 1800

    $t0 = Get-Date
    $r = $cmd.ExecuteReader()
    $r.Read() | Out-Null
    $sec = (New-TimeSpan $t0 (Get-Date)).TotalSeconds

    $out = @(
        "ROWS=$($r['ROWS'])"
        "SA=$($r['SA'])"
        "MU=$($r['MU'])"
        "ADJ=$($r['ADJ'])"
        "BYR=$($r['BYR'])"
        "SISA=$($r['SISA'])"
        "SEC=$([math]::Round($sec, 3))"
    )

    $r.Close()
    $out | Out-File 'c:\BTV\debug\diag76_piutang_summary_out.txt' -Encoding ascii
    $out
}
finally {
    $conn.Close()
}
