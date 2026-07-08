$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "?"} }
$myNo=[int](Scalar "select connection_property('Number')")
try{ $c=$cn.CreateCommand(); $c.CommandText="set option public.remember_last_statement='On'"; $c.ExecuteNonQuery()|Out-Null }catch{}
for($s=1; $s -le 5; $s++){
  $ts=Get-Date -Format "HH:mm:ss"
  $c=$cn.CreateCommand(); $c.CommandText="select Number, ReqType, BlockedOn, LastReqTime from sa_conn_info() where Number<>$myNo order by Number"
  $rd=$c.ExecuteReader(); $rows=@()
  while($rd.Read()){ $rows += ("c{0} req={1} blk={2} lastreq={3}" -f $rd[0],$rd[1],$rd[2],([string]$rd[3]).Substring(11)) }
  $rd.Close()
  $lk = Scalar "select count(*) from sa_locks() where connection<>$myNo"
  Write-Host ("[$ts #$s] locks=$lk | " + ($rows -join "  ||  "))
  $c=$cn.CreateCommand(); $c.CommandText="select Number, Value from sa_conn_properties() where PropName='LastStatement' and Value<>'' and Number<>$myNo"
  $rd=$c.ExecuteReader(); while($rd.Read()){ $v=[string]$rd[1]; if($v.Length -gt 130){$v=$v.Substring(0,130)}; Write-Host ("      c"+$rd[0]+" stmt: "+$v) }; $rd.Close()
  Start-Sleep -Seconds 2
}
$cn.Close()
