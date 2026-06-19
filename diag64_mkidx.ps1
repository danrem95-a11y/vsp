$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$cset = $conn.CreateCommand(); $cset.CommandText = "SET TEMPORARY OPTION blocking = 'On'"; $cset.ExecuteNonQuery() | Out-Null
$cset2 = $conn.CreateCommand(); $cset2.CommandText = "SET TEMPORARY OPTION blocking_timeout = 300000"; $cset2.ExecuteNonQuery() | Out-Null
$ddls = @(
  "CREATE INDEX IDX_GL_JOURNAL_ACC_VCH ON gl_journal (account_id, voucher, kredit)",
  "CREATE INDEX IDX_TBYR1_TGL_FLAG ON TBYR1 (TGL, FLAG_BAYAR)",
  "CREATE INDEX IDX_TBYR2_BUKTI ON TBYR2 (BUKTI_ID)",
  "CREATE INDEX IDX_AP_TRANS_TGL_TIPE ON AP_TRANS (TGL, TIPE_TRANS)",
  "CREATE INDEX IDX_AP_TRANS_ORDER ON AP_TRANS (ORDER_CLIENT, TIPE_TRANS)"
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
