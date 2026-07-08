$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "?"} }
$myNo=[int](Scalar "select connection_property('Number')")
for($s=1; $s -le 4; $s++){
  $ts=Get-Date -Format "HH:mm:ss"
  $c=$cn.CreateCommand(); $c.CommandText="select Number, ReqType, BlockedOn, LastReqTime from sa_conn_info() where Number<>$myNo order by Number"
  $rd=$c.ExecuteReader(); $rows=@()
  while($rd.Read()){ $rows += ("c{0} req={1} blk={2} lastreq={3}" -f $rd[0],$rd[1],$rd[2],([string]$rd[3]).Substring(11)) }
  $rd.Close()
  $lk = Scalar "select count(*) from sa_locks() where connection<>$myNo"
  Write-Host ("[$ts #$s] locks=$lk | " + ($rows -join "  ||  "))
  Start-Sleep -Seconds 3
}
$cn.Close()
