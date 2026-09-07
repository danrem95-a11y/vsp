$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = 'Driver={Adaptive Server Anywhere 9.0};uid=dba;pwd=jakarta;dbf=c:\BTV\vspnew.db;'
$conn.Open()

$cmd = $conn.CreateCommand()
$cmd.CommandText = "select index_name from SYS.SYSINDEXES where table_id = (select table_id from SYS.SYSTABLE where table_name='gl_journal')"
try {
  $rdr = $cmd.ExecuteReader()
  while ($rdr.Read()) { Write-Output ("existing index: " + $rdr.GetValue(0).ToString()) }
  $rdr.Close()
} catch { Write-Output ("ERR list idx: " + $_.Exception.Message) }

$cmdCreate = $conn.CreateCommand()
$cmdCreate.CommandText = "CREATE INDEX idx_gljournal_acct_tgl_test ON gl_journal (account_id, tgl)"
try {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $cmdCreate.ExecuteNonQuery() | Out-Null
  Write-Output ("index created OK in " + $sw.ElapsedMilliseconds + " ms")
} catch { Write-Output ("ERR create idx: " + $_.Exception.Message) }

$conn.Close()
