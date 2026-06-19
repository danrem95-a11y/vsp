$ErrorActionPreference = 'Stop'
$queryPath = 'c:\BTV\debug\qry_opname_piutang.sql'
$sqlOutPath = 'c:\BTV\debug\diag88_validate_jan_generated.sql'
$dbisql = 'C:\Program Files (x86)\SQL Anywhere 11\bin32\dbisql.com'

$sql = Get-Content $queryPath -Raw
$sql = $sql -replace ':arg_tgl1', "'2026-01-01'" -replace ':arg_tgl2', "'2026-01-31'"
$sql = $sql.TrimEnd().TrimEnd(';')

$wrapped = @"
OUTPUT TO 'C:\BTV\debug\diag88_piutang_jan_validate_out.txt' FORMAT ASCII DELIMITED BY '|' QUOTE '';
SELECT
    COUNT(*) AS ROWS,
    CAST(SUM(SALDO_AWAL_IDR) AS DECIMAL(18,2)) AS SA,
    CAST(SUM(MUTASI_IDR) AS DECIMAL(18,2)) AS MU,
    CAST(SUM(ADJ_IDR) AS DECIMAL(18,2)) AS ADJ,
    CAST(SUM(NILAI_BAYAR_IDR) AS DECIMAL(18,2)) AS BYR,
    CAST(SUM(SISA_IDR) AS DECIMAL(18,2)) AS SISA
FROM (
$sql
) X;

OUTPUT TO 'C:\BTV\debug\diag88_piutang_jan_fx_out.txt' FORMAT ASCII DELIMITED BY '|' QUOTE '';
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
ORDER BY ORDER_CLIENT;

OUTPUT TO STDOUT;
SELECT 'DIAG88_DONE' AS STATUS;
"@

Set-Content -Path $sqlOutPath -Value $wrapped -Encoding ascii
& $dbisql -nogui -onerror exit -c 'DSN=vsp;UID=dba;PWD=jakarta' $sqlOutPath
