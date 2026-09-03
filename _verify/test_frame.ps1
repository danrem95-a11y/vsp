function TryCS($lbl,$cs){
  Write-Host ""; Write-Host "== $lbl =="
  $cn=New-Object System.Data.Odbc.OdbcConnection $cs
  try{ $cn.Open(); $c=$cn.CreateCommand(); $c.CommandText="select db_name()"; Write-Host ("   OK -> db="+[string]$c.ExecuteScalar()); $cn.Close() }
  catch{ Write-Host ("   GAGAL: "+($_.Exception.Message -replace "`r`n"," | ")) }
}
TryCS "FRAME.dsn apa adanya (tanpa penutup })" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=SharedMemory,TCPIP{host=103.233.89.43:2638;EngineName=vspnew"
TryCS "FRAME.dsn diperbaiki (dengan penutup })" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=SharedMemory,TCPIP{host=103.233.89.43:2638};EngineName=vspnew"
