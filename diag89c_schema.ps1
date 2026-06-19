$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89c_schema_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunQuery($label, $sql) {
    $output.Add("")
    $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 60
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for ($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t"))
        $cnt=0
        while ($rdr.Read()) {
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t"))
            $cnt++
        }
        $rdr.Close()
        $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# tbyr1 sample and tbyr2 schema
RunQuery "tbyr1 SAMPLE TOP 3 (AP, Jan2026)" @"
SELECT TOP 3 * FROM tbyr1
WHERE FLAG_BAYAR='2' AND TGL >= '2026-01-01' AND TGL <= '2026-01-31'
"@

RunQuery "tbyr2 SAMPLE TOP 3" @"
SELECT TOP 3 * FROM tbyr2
"@

RunQuery "tbyr2 COLUMNS (SYSCOLUMNS)" @"
SELECT cname, coltype FROM SYS.SYSCOLUMNS WHERE tname='tbyr2' ORDER BY colno
"@

# Check d_trace_ap datawindow SQL to understand the amount field
RunQuery "gl_setup bank accounts" @"
SELECT acc_ar, acc_ap FROM gl_setup
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
