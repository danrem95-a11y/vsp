$ErrorActionPreference = 'Continue'
$outFile = 'C:\BTV\debug\fa_disco_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunQuery($label, $sql) {
    $output.Add("")
    $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 120
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

# 1. All base tables with column count
RunQuery "ALL BASE TABLES" @"
SELECT t.table_name, t.count AS nrows
FROM SYS.SYSTABLE t
WHERE t.table_type='BASE' AND t.creator IN (SELECT user_id FROM SYS.SYSUSERPERM WHERE user_name='DBA')
ORDER BY t.table_name
"@

# 2. Search for Fixed Asset related tables by name
RunQuery "FA-RELATED TABLE NAME SEARCH" @"
SELECT table_name FROM SYS.SYSTABLE
WHERE table_type='BASE' AND (
  lower(table_name) LIKE '%asset%' OR
  lower(table_name) LIKE '%aktiva%' OR
  lower(table_name) LIKE '%aset%' OR
  lower(table_name) LIKE '%susut%' OR
  lower(table_name) LIKE '%depre%' OR
  lower(table_name) LIKE '%penyu%' OR
  lower(table_name) LIKE 'fa[_]%' OR
  lower(table_name) LIKE '%fixed%' OR
  lower(table_name) LIKE '%inventaris%')
ORDER BY table_name
"@

# 3. Search for FA-related columns
RunQuery "FA-RELATED COLUMN NAME SEARCH" @"
SELECT tname, cname, coltype FROM SYS.SYSCOLUMNS
WHERE lower(cname) LIKE '%susut%' OR lower(cname) LIKE '%depre%'
   OR lower(cname) LIKE '%asset%' OR lower(cname) LIKE '%aktiva%'
ORDER BY tname, cname
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
