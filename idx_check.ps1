$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandTimeout=60
$c.CommandText="select tname, iname, indextype, colnames from SYS.SYSINDEXES where tname in ('tsales1','tsales2','tstok1','tstok2') order by tname, iname"
$rd=$c.ExecuteReader()
while($rd.Read()){ Write-Host ("  "+$rd["tname"]+"  |  "+$rd["iname"]+"  |  "+$rd["indextype"]+"  |  cols="+$rd["colnames"]) }
$rd.Close(); $cn.Close()
