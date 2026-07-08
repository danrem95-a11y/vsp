$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs
try { $cn.Open() } catch { Write-Host ("CONNECT ERROR: "+$_.Exception.Message); exit }
Write-Host "CONNECTED`n"
function Reader($sql){
  $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try { $rd=$c.ExecuteReader() } catch { Write-Host ("  ERR: "+$_.Exception.Message); return }
  $cols=$rd.FieldCount; $any=$false
  while($rd.Read()){
    $any=$true; $line=@()
    for($i=0;$i -lt $cols;$i++){ $line += ($rd.GetName($i)+"="+[string]$rd[$i]) }
    Write-Host ("  "+($line -join " | "))
  }
  if(-not $any){ Write-Host "  (kosong)" }
  $rd.Close()
}
Write-Host "=== 1) KONEKSI aktif + BlockedOn (blocked<>0 = nunggu lock) ==="
Reader "select Number, Userid, BlockedOn, ReqType, LastReqTime from sa_conn_info()"
Write-Host "`n=== 2) LOCKS aktif ==="
Reader "select connection, user_id, table_name, lock_type, lock_duration, lock_class from sa_locks() order by table_name"
Write-Host "`n=== 3) lock di tabel closing ==="
Reader "select table_name, count(*) jml from sa_locks() where lower(table_name) in ('tsales1','tsales2','sinv','sinv_gudang','sinv_minus') group by table_name"
$cn.Close(); Write-Host "`nDONE"
