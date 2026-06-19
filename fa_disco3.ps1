$ErrorActionPreference = 'Continue'
$outFile = 'C:\BTV\debug\fa_disco3_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunQuery($label, $sql) {
    $output.Add(""); $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 180
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for ($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t"))
        $cnt=0
        while ($rdr.Read()) {
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t")); $cnt++
        }
        $rdr.Close(); $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

function DumpSchema($tbl) {
    RunQuery "SCHEMA: $tbl" @"
SELECT colno, cname, coltype, length, nulls, in_primary_key, "default"
FROM SYS.SYSCOLUMNS WHERE tname='$tbl' ORDER BY colno
"@
}

foreach ($t in @('gl_journal','gl_journal2','gl_journal_detail_copy','gl_acc','gl_curr','gl_rate','gl_depart','gl_project','gl_cc','gl_cf','gl_cate','gl_cate_detail','gl_balance','gl_site','MKAS','MCSTSUPP')) {
    DumpSchema $t
}

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
