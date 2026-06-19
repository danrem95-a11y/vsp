$ErrorActionPreference = 'Stop'
$queryPath = 'c:\BTV\debug\qry_opname_piutang.sql'
$sql = Get-Content $queryPath -Raw
$sql = $sql -replace ':arg_tgl1', "'2026-01-01'" -replace ':arg_tgl2', "'2026-01-31'"
$sql = $sql.TrimEnd().TrimEnd(';')

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

try {
    $summarySql = @"
SELECT
    COUNT(*) AS ROWS,
    CAST(SUM(SALDO_AWAL_IDR) AS DECIMAL(18,2)) AS SA,
    CAST(SUM(MUTASI_IDR) AS DECIMAL(18,2)) AS MU,
    CAST(SUM(ADJ_IDR) AS DECIMAL(18,2)) AS ADJ,
    CAST(SUM(NILAI_BAYAR_IDR) AS DECIMAL(18,2)) AS BYR,
    CAST(SUM(SISA_IDR) AS DECIMAL(18,2)) AS SISA
FROM (
$sql
) X
"@

    $summaryCmd = $conn.CreateCommand()
    $summaryCmd.CommandText = $summarySql
    $summaryCmd.CommandTimeout = 1800
    $summaryReader = $summaryCmd.ExecuteReader()
    $summaryReader.Read() | Out-Null
    @(
        "ROWS=$($summaryReader['ROWS'])"
        "SA=$($summaryReader['SA'])"
        "MU=$($summaryReader['MU'])"
        "ADJ=$($summaryReader['ADJ'])"
        "BYR=$($summaryReader['BYR'])"
        "SISA=$($summaryReader['SISA'])"
    ) | Set-Content 'c:\BTV\debug\diag88_piutang_jan_validate_out.txt'
    $summaryReader.Close()

    $fxSql = @"
SELECT
    ORDER_CLIENT,
    CURR_ID,
    CAST(KURS AS DECIMAL(18,2)) AS KURS,
    CAST(ISNULL(NEW_RATE, 0) AS DECIMAL(18,2)) AS NEW_RATE,
    CAST(SALDO_AWAL AS DECIMAL(18,4)) AS SALDO_AWAL,
    CAST(SALDO_AWAL_IDR AS DECIMAL(18,2)) AS SALDO_AWAL_IDR,
    CAST(SISA_IDR AS DECIMAL(18,2)) AS SISA_IDR
FROM (
$sql
) X
WHERE ORDER_CLIENT IN (
    '101BTB250300036',
    '101BTB250300037',
    '101BTB251100051',
    '101BTB251200030',
    '101BTB251200031',
    '101BTB251200032',
    '101BTB251200035'
)
ORDER BY ORDER_CLIENT
"@

    $fxCmd = $conn.CreateCommand()
    $fxCmd.CommandText = $fxSql
    $fxCmd.CommandTimeout = 1800
    $fxReader = $fxCmd.ExecuteReader()
    $fxLines = @('ORDER_CLIENT|CURR_ID|KURS|NEW_RATE|SALDO_AWAL|SALDO_AWAL_IDR|SISA_IDR')
    while ($fxReader.Read()) {
        $fxLines += "$($fxReader['ORDER_CLIENT'])|$($fxReader['CURR_ID'])|$($fxReader['KURS'])|$($fxReader['NEW_RATE'])|$($fxReader['SALDO_AWAL'])|$($fxReader['SALDO_AWAL_IDR'])|$($fxReader['SISA_IDR'])"
    }
    $fxReader.Close()
    $fxLines | Set-Content 'c:\BTV\debug\diag88_piutang_jan_fx_out.txt'
}
finally {
    $conn.Close()
}
