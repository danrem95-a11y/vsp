$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$sql = Get-Content C:/BTV/debug/_dwrs_B.sql -Raw
$c=$cn.CreateCommand();$c.CommandTimeout=600;$c.CommandText="select count(*) from ( $sql ) q"
$sw=[Diagnostics.Stopwatch]::StartNew()
try{$v=$c.ExecuteScalar()}catch{$v="ERR:"+$_.Exception.Message}
$sw.Stop()
Write-Host ("QUERY PENUH (10 outer-join + 2 NOT IN, semua produk): {0} ms  rows={1}" -f $sw.ElapsedMilliseconds,$v)
$cn.Close()
