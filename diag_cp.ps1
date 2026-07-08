$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandText="select * from sa_conn_properties() where rowid(sa_conn_properties())=1"
try{ $rd=$c.ExecuteReader(); Write-Host "sa_conn_properties cols:"; for($i=0;$i -lt $rd.FieldCount;$i++){Write-Host ("  "+$rd.GetName($i))}; $rd.Close() }
catch{ $c.CommandText="select * from sa_conn_properties()"; $rd=$c.ExecuteReader(); Write-Host "cols:"; for($i=0;$i -lt $rd.FieldCount;$i++){Write-Host ("  "+$rd.GetName($i))}; $rd.Close() }
$cn.Close()
