$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  $any=$false; while($rd.Read()){$any=$true;$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$v=[string]$rd[$i];if($v.Length -gt 120){$v=$v.Substring(0,120)}; $l+=($rd.GetName($i)+"="+$v)};Write-Host ("  "+($l -join " | "))}
  if(-not $any){Write-Host "  (kosong)"}; $rd.Close() }
Write-Host "=== lock di TSALES1 (siapa pemegangnya) ==="
Reader "select connection, user_id, table_name, lock_type from sa_locks() where lower(table_name)='tsales1'"
Write-Host "`n=== koneksi + UncmtOps (transaksi terbuka) + ReqType ==="
Reader "select Number, Userid, ReqType, BlockedOn, UncmtOps, LastReqTime from sa_conn_info() order by Number"
Write-Host "`n=== coba ulang CREATE INDEX ==="
$c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText="create index idx_tsales1_tgl on tsales1(tgl, tipe_trans)"
$sw=[Diagnostics.Stopwatch]::StartNew()
try{ $c.ExecuteNonQuery()|Out-Null; $sw.Stop(); Write-Host ("  OK dibuat idx_tsales1_tgl  {0} ms" -f $sw.ElapsedMilliseconds) }
catch{ $sw.Stop(); Write-Host ("  MASIH GAGAL ("+$sw.ElapsedMilliseconds+" ms): "+$_.Exception.Message) }
$cn.Close()
