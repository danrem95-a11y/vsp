$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){
  $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  $any=$false
  while($rd.Read()){ $any=$true; $l=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$v=[string]$rd[$i]; if($v.Length -gt 160){$v=$v.Substring(0,160)+'...'}; $l+=($rd.GetName($i)+"="+$v)}; Write-Host ("  "+($l -join " | ")) }
  if(-not $any){Write-Host "  (kosong)"}; $rd.Close()
}
Write-Host ("SNAPSHOT "+(Get-Date -Format "HH:mm:ss"))
Write-Host "=== koneksi: BlockedOn<>0 => KE-BLOCK (lock) ; BlockedOn=0 & ProcessTime naik => query LAMBAT (bukan lock) ==="
Reader "select Number, Userid, ReqType, BlockedOn, UncmtOps, ProcessTime from sa_conn_info() order by Number"
Write-Host "`n=== statement terakhir tiap koneksi (cari UPDATE TSALES2) ==="
Reader "select Number, Value from sa_conn_properties() where PropName='LastStatement' and Value<>''"
Write-Host "`n=== lock di tabel closing ==="
Reader "select connection, user_id, table_name, lock_type from sa_locks() where lower(table_name) in ('tsales1','tsales2','sinv','sinv_gudang','sinv_minus') order by table_name"
$cn.Close()
