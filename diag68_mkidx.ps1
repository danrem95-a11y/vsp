$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$cset = $conn.CreateCommand(); $cset.CommandText = "SET TEMPORARY OPTION blocking = 'On'"; $cset.ExecuteNonQuery() | Out-Null
$ddls = @(
  "CREATE INDEX IDX_MCSTSUPP_VENDOR ON MCSTSUPP (VENDOR_ID)",
  "CREATE INDEX IDX_MCUST_CUST ON MCUST (cust_id)"
)
foreach ($d in $ddls) {
    $t0 = Get-Date
    try {
        $c = $conn.CreateCommand(); $c.CommandText = $d; $c.CommandTimeout = 600
        $c.ExecuteNonQuery() | Out-Null
        $sec = (New-TimeSpan $t0 (Get-Date)).TotalSeconds
        "OK  | $sec sec | $d"
    } catch {
        "ERR | $($_.Exception.Message) | $d"
    }
}
$conn.Close()
