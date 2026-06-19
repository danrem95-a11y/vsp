$ErrorActionPreference = 'Continue'
$outFile = 'C:\BTV\debug\fa_disco2_out.txt'
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
SELECT tc.column_id AS pos, tc.column_name AS col, d.domain_name AS type,
       tc.width, tc.scale, tc.nulls, tc.pkey, tc."default" AS dflt
FROM SYS.SYSTAB t
  JOIN SYS.SYSTABCOL tc ON tc.table_id=t.table_id
  JOIN SYS.SYSDOMAIN d ON d.domain_id=tc.domain_id
WHERE t.table_name='$tbl'
ORDER BY tc.column_id
"@
}

# Core GL + master schemas
foreach ($t in @('gl_journal','gl_journal2','gl_journal_detail_copy','gl_acc','gl_setup','gl_curr','gl_rate','gl_depart','gl_project','gl_cc','gl_cf','gl_cate','gl_cate_detail','gl_balance','gl_site','MKAS','MCSTSUPP','MCUST')) {
    DumpSchema $t
}

# modul_id distribution in gl_journal (journal sources)
RunQuery "gl_journal MODUL_ID distribution" @"
SELECT modul_id, COUNT(*) AS n, MIN(tgl) AS tgl_min, MAX(tgl) AS tgl_max
FROM gl_journal GROUP BY modul_id ORDER BY n DESC
"@

# voucher prefix patterns (first 4-6 chars)
RunQuery "gl_journal VOUCHER prefix sample by modul" @"
SELECT modul_id, MIN(voucher) AS voucher_min, MAX(voucher) AS voucher_max, COUNT(DISTINCT voucher) AS nvouchers
FROM gl_journal GROUP BY modul_id ORDER BY modul_id
"@

# gl_setup full content
RunQuery "gl_setup CONTENT" "SELECT * FROM gl_setup"

# gl_site content
RunQuery "gl_site CONTENT" "SELECT * FROM gl_site"

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
