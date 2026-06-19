$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
function Q($sql) {
    $c = $conn.CreateCommand(); $c.CommandText = $sql; $c.CommandTimeout = 60
    $r = $c.ExecuteReader()
    while ($r.Read()) {
        $row = @()
        for ($i=0; $i -lt $r.FieldCount; $i++) { $row += "$($r.GetName($i))=$($r[$i])" }
        $row -join '|'
    }
    $r.Close()
}
$tables = @('GL_JOURNAL','AP_TRANS','SALDO_AWAL_FAKTUR','TBYR1','TBYR2','TBYR2_PUTIH')
foreach ($t in $tables) {
    "=== $t ==="
    Q "SELECT i.index_name, c.column_name, ic.sequence FROM sys.sysindex i JOIN sys.systable t ON t.table_id=i.table_id JOIN sys.sysixcol ic ON ic.index_id=i.index_id AND ic.table_id=i.table_id JOIN sys.syscolumn c ON c.table_id=ic.table_id AND c.column_id=ic.column_id WHERE upper(t.table_name)='$t' ORDER BY i.index_name, ic.sequence"
}
$conn.Close()
