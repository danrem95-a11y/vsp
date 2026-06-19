$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$cset = $conn.CreateCommand(); $cset.CommandText = "SET TEMPORARY OPTION blocking = 'On'"; $cset.ExecuteNonQuery() | Out-Null
$ddls = @(
  "CREATE INDEX IDX_TBYR2_PUTIH_BUKTI ON TBYR2_PUTIH (BUKTI_ID)"
)
foreach ($d in $ddls) {
    try { $c = $conn.CreateCommand(); $c.CommandText = $d; $c.CommandTimeout = 600; $c.ExecuteNonQuery() | Out-Null; "OK | $d" }
    catch { "ERR | $($_.Exception.Message) | $d" }
}
$conn.Close()
