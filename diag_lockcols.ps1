$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandText="select * from sa_locks()"
$rd=$c.ExecuteReader()
Write-Host "sa_locks() columns:"
for($i=0;$i -lt $rd.FieldCount;$i++){ Write-Host ("  ["+$i+"] "+$rd.GetName($i)) }
$rd.Close()
# conn_info columns juga
$c2=$cn.CreateCommand(); $c2.CommandText="select * from sa_conn_info()"; $rd2=$c2.ExecuteReader()
Write-Host "`nsa_conn_info() columns:"
for($i=0;$i -lt $rd2.FieldCount;$i++){ Write-Host ("  ["+$i+"] "+$rd2.GetName($i)) }
$rd2.Close()
$cn.Close()
