$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=60;$c.CommandText=$s;try{$rd=$c.ExecuteReader()}catch{Write-Host("  ERR:"+$_.Exception.Message);return};while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Qry "select proc_name from sys.sysprocedure where proc_name like '%ar%' or proc_name like '%ap%' or proc_name like '%piutang%' or proc_name like '%hutang%' or proc_name like '%trace%'"
$cn.Close()
