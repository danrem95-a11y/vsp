$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "?"} }
$myNo=[int](Scalar "select connection_property('Number')")
try{ $c=$cn.CreateCommand(); $c.CommandText="set option public.remember_last_statement='On'"; $c.ExecuteNonQuery()|Out-Null }catch{}
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql
  $rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$v=[string]$rd[$i];if($v.Length -gt 160){$v=$v.Substring(0,160)}; $l+=($rd.GetName($i)+"="+$v)};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host ("SNAPSHOT "+(Get-Date -Format "HH:mm:ss")+"  (MyConn=$myNo)")
Write-Host "=== koneksi app (blk<>0=ke-lock ; ptime naik=query jalan) ==="
Reader "select Number, NodeAddr, ReqType, BlockedOn, ProcessTime, UncmtOps, LastReqTime from sa_conn_info() where Number<>$myNo order by Number"
Write-Host "`n=== statement terakhir (yg sedang/terakhir jalan) ==="
Reader "select Number, Value from sa_conn_properties() where PropName='LastStatement' and Value<>'' and Number<>$myNo"
Write-Host "`n=== lock per tabel (kunci) ==="
Reader "select table_name, count(*) jml from sa_locks() where Number<>$myNo group by table_name order by jml desc"
$cn.Close()
