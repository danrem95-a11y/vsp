$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Write-Host ("### MONITOR "+(Get-Date -Format 'HH:mm:ss')+" ###")
Qry "Koneksi (LastReqTime & idle detik = sibuk kalau kecil)" @"
select number, connection_property('Name',number) nm, connection_property('LastReqTime',number) last_req, connection_property('LastIdle',number) idle_ticks
from sa_conn_info() where number>1
"@
Qry "Lock aktif per tabel" @"
select table_name, lock_type, count(*) n from sa_locks() where table_name is not null group by table_name, lock_type order by table_name
"@
Qry "Marker: gl_setup.closing_sales (=2026-07-01 saat closing Jun beres)" "select closing_sales from gl_setup"
Qry "Baris sinv periode 2026-07-01 (ditulis saat closing Jun selesai)" "select count(*) sinv_jul from sinv where periode='2026-07-01'"
$cn.Close()
