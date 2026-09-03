$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Write-Host ("### STATUS "+(Get-Date -Format 'HH:mm:ss')+" ###")
Qry "Lock aktif (kalau kosong = tak ada proses nulis)" "select replace(table_name,'DBA.','') tbl, lock_type, count(*) n from sa_locks() where table_name is not null group by table_name, lock_type order by table_name"
Qry "Koneksi & idle (idle besar = nganggur)" "select number, connection_property('LastIdle',number) idle_ticks, connection_property('LastReqTime',number) last_req from sa_conn_info() where number>1"
Qry "Index sinv terkini" "select iname, colnames from SYS.SYSINDEXES where tname='sinv' order by iname"
$cn.Close()
