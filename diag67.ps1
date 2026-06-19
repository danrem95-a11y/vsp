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
foreach ($t in 'MCSTSUPP','MCUST') {
    "=== $t indexes ==="
    Q "SELECT i.index_name, c.column_name, ic.sequence FROM sys.sysindex i JOIN sys.systable t ON t.table_id=i.table_id JOIN sys.sysixcol ic ON ic.index_id=i.index_id AND ic.table_id=i.table_id JOIN sys.syscolumn c ON c.table_id=ic.table_id AND c.column_id=ic.column_id WHERE upper(t.table_name)='$t' ORDER BY i.index_name, ic.sequence"
    "=== $t PK ==="
    Q "SELECT c.column_name FROM sys.systable t JOIN sys.syscolumn c ON c.table_id=t.table_id WHERE c.pkey='Y' AND upper(t.table_name)='$t' ORDER BY c.column_id"
    Q "SELECT COUNT(*) AS n FROM $t"
}
"=== Distinct voucher 226-001 ==="
Q "SELECT COUNT(DISTINCT voucher) AS distinct_vch, COUNT(*) AS rows FROM gl_journal WHERE account_id='226-001' AND kredit>0"
"=== TBYR2_PUTIH indexes ==="
Q "SELECT i.index_name, c.column_name, ic.sequence FROM sys.sysindex i JOIN sys.systable t ON t.table_id=i.table_id JOIN sys.sysixcol ic ON ic.index_id=i.index_id AND ic.table_id=i.table_id JOIN sys.syscolumn c ON c.table_id=ic.table_id AND c.column_id=ic.column_id WHERE upper(t.table_name)='TBYR2_PUTIH' ORDER BY i.index_name, ic.sequence"
$conn.Close()
