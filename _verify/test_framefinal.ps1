# Uji persis parameter FRAME.dsn setelah diperbaiki (braces + PWD)
$cs="DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=SharedMemory,TCPIP{host=103.233.89.43:2638};EngineName=vspnew"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs
try{ $cn.Open(); $c=$cn.CreateCommand(); $c.CommandText="select db_name(), current timestamp"; $rd=$c.ExecuteReader(); $rd.Read()
     Write-Host ("FRAME.dsn final -> OK  db="+[string]$rd[0]+"  server-time="+[string]$rd[1]); $rd.Close(); $cn.Close() }
catch{ Write-Host ("FRAME.dsn final -> GAGAL: "+($_.Exception.Message -replace "`r`n"," ")) }
