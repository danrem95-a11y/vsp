$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$myNo = ($cn.CreateCommand() | % { $_.CommandText="select connection_property('Number')"; $_.ExecuteScalar() })
Write-Host ("MyConn = $myNo`n")
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  $any=$false; while($rd.Read()){$any=$true;$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$v=[string]$rd[$i];if($v.Length -gt 90){$v=$v.Substring(0,90)}; $l+=($rd.GetName($i)+"="+$v)};Write-Host ("  "+($l -join " | "))}
  if(-not $any){Write-Host "  (kosong)"}; $rd.Close() }
try{ $c=$cn.CreateCommand(); $c.CommandText="set option public.remember_last_statement='On'"; $c.ExecuteNonQuery()|Out-Null }catch{}
Write-Host "=== SEMUA lock (tanpa filter) ==="
Reader "select connection, user_id, table_name, lock_type from sa_locks() order by connection, table_name"
Write-Host "`n=== SEMUA koneksi (Name/NodeAddr/LastReqTime/UncmtOps) ==="
Reader "select Number, Name, Userid, NodeAddr, ReqType, UncmtOps, LastReqTime from sa_conn_info() order by Number"
Write-Host "`n=== statement terakhir tiap koneksi ==="
Reader "select Number, Value from sa_conn_properties() where PropName='LastStatement' and Value<>''"
$cn.Close()
