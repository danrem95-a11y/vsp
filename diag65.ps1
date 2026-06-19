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
"=== sa_conn_info (my conn first) ==="
Q "SELECT Number, Userid, LastReqTime, BlockedOn FROM sa_conn_info() ORDER BY Number"
"=== Locks summary ==="
try { Q "SELECT * FROM sa_locks() WHERE table_name IN ('gl_journal','TBYR1','TBYR2','AP_TRANS')" } catch { "sa_locks not avail: $($_.Exception.Message)" }
$conn.Close()
