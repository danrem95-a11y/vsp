$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = 'Driver={Adaptive Server Anywhere 9.0};uid=dba;pwd=jakarta;dbf=c:\BTV\vspnew.db;'
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "select index_name from sysindexes where table_name(table_id)='gl_journal'"
try {
  $rdr = $cmd.ExecuteReader()
  while ($rdr.Read()) { Write-Output ("index: " + $rdr.GetValue(0).ToString()) }
  $rdr.Close()
} catch { Write-Output ("ERR1: " + $_.Exception.Message) }

$cmd2 = $conn.CreateCommand()
$cmd2.CommandText = "select count(*) from gl_journal"
try { Write-Output ("gl_journal rows: " + $cmd2.ExecuteScalar()) } catch { Write-Output ("ERR2: " + $_.Exception.Message) }

$cmd3 = $conn.CreateCommand()
$cmd3.CommandText = "select count(*) from gl_acc"
try { Write-Output ("gl_acc rows: " + $cmd3.ExecuteScalar()) } catch { Write-Output ("ERR3: " + $_.Exception.Message) }

$conn.Close()
