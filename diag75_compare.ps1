$ErrorActionPreference = 'Stop'
$outFile = 'c:\BTV\debug\diag75_compare_out.txt'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function Get-Summary {
    param(
        [string]$Path
    )

    $sql = Get-Content $Path -Raw
    $sql = $sql -replace ':arg_tgl1', "'2026-01-01'" -replace ':arg_tgl2', "'2026-01-31'"
    $sql = $sql.TrimEnd().TrimEnd(';')

    $wrapped = @"
SELECT
    COUNT(*) AS ROWS,
    CAST(ISNULL(SUM(SALDO_AWAL_IDR), 0) AS DECIMAL(18,2)) AS SALDO_AWAL_IDR,
    CAST(ISNULL(SUM(MUTASI_IDR), 0) AS DECIMAL(18,2)) AS MUTASI_IDR,
    CAST(ISNULL(SUM(ADJ_IDR), 0) AS DECIMAL(18,2)) AS ADJ_IDR,
    CAST(ISNULL(SUM(NILAI_BAYAR_IDR), 0) AS DECIMAL(18,2)) AS NILAI_BAYAR_IDR,
    CAST(ISNULL(SUM(SISA_IDR), 0) AS DECIMAL(18,2)) AS SISA_IDR
FROM (
$sql
) X
"@

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $wrapped
    $cmd.CommandTimeout = 1800

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $reader = $cmd.ExecuteReader()
    $dt = New-Object System.Data.DataTable
    $dt.Load($reader)
    $reader.Close()
    $sw.Stop()

    [pscustomobject]@{
        FILE = [System.IO.Path]::GetFileName($Path)
        SEC = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        ROWS = $dt.Rows[0].ROWS
        SALDO_AWAL_IDR = $dt.Rows[0].SALDO_AWAL_IDR
        MUTASI_IDR = $dt.Rows[0].MUTASI_IDR
        ADJ_IDR = $dt.Rows[0].ADJ_IDR
        NILAI_BAYAR_IDR = $dt.Rows[0].NILAI_BAYAR_IDR
        SISA_IDR = $dt.Rows[0].SISA_IDR
    }
}

try {
    $results = @(
        Get-Summary 'c:\BTV\debug\qry_opname_piutang_before_tuning.sql'
        Get-Summary 'c:\BTV\debug\qry_opname_piutang.sql'
    )

    $results | ConvertTo-Csv -NoTypeInformation | Set-Content $outFile
    Get-Content $outFile
}
finally {
    if ($conn.State -eq [System.Data.ConnectionState]::Open) {
        $conn.Close()
    }
}
