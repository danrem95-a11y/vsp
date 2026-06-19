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
"FEB-flag-test:"
Q "SELECT (SELECT TOP 1 1 FROM AP_TRANS APJ WHERE APJ.TIPE_TRANS='02' AND DATEPART(month, '2026-02-01')=1) AS FLAG_FEB"
"JAN-flag-test:"
Q "SELECT (SELECT TOP 1 1 FROM AP_TRANS APJ WHERE APJ.TIPE_TRANS='02' AND DATEPART(month, '2026-01-01')=1) AS FLAG_JAN"
$conn.Close()
