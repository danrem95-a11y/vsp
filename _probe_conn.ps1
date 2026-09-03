$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
try{
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  $c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
  $m=$c.CreateCommand(); $m.CommandText="select count(*) from gl_journal where account_id='102-020'"; $m.CommandTimeout=30
  $v=$m.ExecuteScalar()
  Write-Output ("OK count="+$v+" elapsed="+$sw.ElapsedMilliseconds+"ms")
  $c.Close()
}catch{
  Write-Output ("FAIL: "+$_.Exception.Message)
}
