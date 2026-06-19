$ErrorActionPreference = 'Continue'
$outFile = 'C:\BTV\debug\fa_disco3b_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function DumpSchema($tbl) {
    $output.Add(""); $output.Add("===== SCHEMA: $tbl =====")
    try {
        $dt = $conn.GetSchema("Columns", @($null,$null,$tbl,$null))
        $rows = $dt | Sort-Object ORDINAL_POSITION
        $output.Add("col`ttype`tsize`tnullable`tordinal")
        foreach ($r in $rows) {
            $output.Add(("{0}`t{1}`t{2}`t{3}`t{4}" -f $r.COLUMN_NAME,$r.TYPE_NAME,$r.COLUMN_SIZE,$r.IS_NULLABLE,$r.ORDINAL_POSITION))
        }
        $output.Add("($($rows.Count) cols)")
    } catch { $output.Add("ERROR: $_") }
}

foreach ($t in @('gl_journal','gl_journal2','gl_journal_detail_copy','gl_acc','gl_curr','gl_rate','gl_depart','gl_project','gl_cc','gl_cf','gl_cate','gl_cate_detail','gl_balance','gl_site','MKAS','MCSTSUPP')) {
    DumpSchema $t
}

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
