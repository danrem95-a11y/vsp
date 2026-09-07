$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "Driver={Adaptive Server Anywhere 9.0};uid=dba;pwd=jakarta;dbf=c:\BTV\vspnew.db;"
$conn.Open()
$sql = Get-Content -Path "c:\BTV\debug\_flat_sql_test12_noisfind.sql" -Raw
$cmd = $conn.CreateCommand()
$cmd.CommandText = $sql
$cmd.CommandTimeout = 30
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
  $rdr = $cmd.ExecuteReader()
  $n=0
  while ($rdr.Read()) { $n++ }
  Write-Output ("rows: " + $n + "  elapsed ms: " + $sw.ElapsedMilliseconds)
} catch { Write-Output ("ERR: " + $_.Exception.Message) }
$conn.Close()
