$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandTimeout=60
$c.CommandText="select voucher, count(*) baris, cast(sum(debet)-sum(kredit) as numeric(18,2)) net from gl_journal where voucher like 'RL101%' group by voucher order by voucher"
$rd=$c.ExecuteReader()
while($rd.Read()){ Write-Host ("  "+$rd["voucher"]+" | baris="+$rd["baris"]+" | net(laba/rugi)="+$rd["net"]) }
$rd.Close(); $cn.Close()
