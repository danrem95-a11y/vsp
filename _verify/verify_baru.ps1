# 1) Uji koneksi persis params FRAMENEW.dsn (BARU) setelah diperbaiki
$cs="DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=SharedMemory,TCPIP{host=103.233.89.43:2638};EngineName=vspnew"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs
try{ $cn.Open(); $c=$cn.CreateCommand(); $c.CommandText="select db_name()"; Write-Host ("BARU/FRAMENEW.dsn -> OK  db="+[string]$c.ExecuteScalar()); $cn.Close() }
catch{ Write-Host ("BARU/FRAMENEW.dsn -> GAGAL: "+($_.Exception.Message -replace "`r`n"," ")) }
