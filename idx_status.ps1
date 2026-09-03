$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
$c=$P.CreateCommand(); $c.CommandTimeout=60
$c.CommandText="select tname, iname, colnames from SYS.SYSINDEXES where tname in ('sinv','tsales1') order by tname, iname"
$rd=$c.ExecuteReader()
while($rd.Read()){ Write-Host ("  "+$rd["tname"]+"  |  "+$rd["iname"]+"  |  "+$rd["colnames"]) }
$rd.Close(); $P.Close()
