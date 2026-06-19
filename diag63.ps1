$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
function Q($sql) {
    $c = $conn.CreateCommand(); $c.CommandText = $sql; $c.CommandTimeout = 120
    $r = $c.ExecuteReader()
    while ($r.Read()) {
        $row = @()
        for ($i=0; $i -lt $r.FieldCount; $i++) { $row += "$($r.GetName($i))=$($r[$i])" }
        $row -join '|'
    }
    $r.Close()
}
"=== Primary keys ==="
Q "SELECT t.table_name, c.column_name FROM sys.systable t JOIN sys.syscolumn c ON c.table_id=t.table_id WHERE c.pkey='Y' AND upper(t.table_name) IN ('GL_JOURNAL','AP_TRANS','SALDO_AWAL_FAKTUR','TBYR1','TBYR2','TBYR2_PUTIH') ORDER BY t.table_name, c.column_id"
"=== Row counts ==="
foreach ($t in 'gl_journal','ap_trans','saldo_awal_faktur','tbyr1','tbyr2','tbyr2_putih') {
    Q "SELECT '$t' AS tbl, COUNT(*) AS n FROM $t"
}
"=== gl_journal columns ==="
Q "SELECT c.column_name FROM sys.systable t JOIN sys.syscolumn c ON c.table_id=t.table_id WHERE upper(t.table_name)='GL_JOURNAL' ORDER BY c.column_id"
$conn.Close()
