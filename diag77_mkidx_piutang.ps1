$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

$cset = $conn.CreateCommand()
$cset.CommandText = "SET TEMPORARY OPTION blocking = 'On'"
$cset.ExecuteNonQuery() | Out-Null

$ddls = @(
  "CREATE INDEX IDX_AR_TRANS_TGL_TIPE ON AR_TRANS (TGL, TIPE_TRANS)",
  "CREATE INDEX IDX_AR_TRANS_ORDER ON AR_TRANS (ORDER_CLIENT, TIPE_TRANS)"
)

foreach ($ddl in $ddls) {
    $t0 = Get-Date
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $ddl
        $cmd.CommandTimeout = 600
        $cmd.ExecuteNonQuery() | Out-Null
        $sec = (New-TimeSpan $t0 (Get-Date)).TotalSeconds
        "OK  | $sec sec | $ddl"
    }
    catch {
        "ERR | $($_.Exception.Message) | $ddl"
    }
}

$conn.Close()
