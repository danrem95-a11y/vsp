$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return "?"} }
$myNo = [int](Scalar "select connection_property('Number')")
try{ $c=$cn.CreateCommand(); $c.CommandText="set option public.remember_last_statement='On'"; $c.ExecuteNonQuery()|Out-Null }catch{}
Write-Host ("MONITOR mulai (MyConn=$myNo). Tekan biarkan jalan...`n")
for($s=1; $s -le 30; $s++){
  $ts = Get-Date -Format "HH:mm:ss"
  # koneksi app (bukan saya)
  $c=$cn.CreateCommand(); $c.CommandText="select Number, NodeAddr, ReqType, BlockedOn, ProcessTime, UncmtOps from sa_conn_info() where Number<>$myNo order by Number"
  $rd=$c.ExecuteReader(); $conns=@()
  while($rd.Read()){ $conns += ("c{0}[{1}] req={2} blk={3} ptime={4} uncmt={5}" -f $rd[0],$rd[1],$rd[2],$rd[3],$rd[4],$rd[5]) }
  $rd.Close()
  # lock count tabel kunci
  $lk = Scalar "select count(*) from sa_locks() where lower(table_name) like '%tsales%' or lower(table_name) like '%tstok%' or lower(table_name) like '%sinv%' or lower(table_name) like '%gl_journal%'"
  # statement terakhir koneksi app teraktif
  $stmt=""
  $c=$cn.CreateCommand(); $c.CommandText="select first Value from sa_conn_properties() where PropName='LastStatement' and Value<>'' and Number<>$myNo order by Number desc"
  try{ $v=$c.ExecuteScalar(); if($v){ $stmt=([string]$v); if($stmt.Length -gt 110){$stmt=$stmt.Substring(0,110)} } }catch{}
  if($conns.Count -eq 0){ $conns=@("(tak ada koneksi app)") }
  Write-Host ("[$ts #$s] lock_kunci=$lk | " + ($conns -join "  ||  "))
  if($stmt -ne ""){ Write-Host ("        stmt: $stmt") }
  Start-Sleep -Seconds 3
}
$cn.Close(); Write-Host "`nMONITOR selesai."
