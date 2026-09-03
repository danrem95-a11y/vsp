$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=90; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Write-Host ("### STATUS LIVE "+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+" ###")
Qry "A. Ada proses jalan? (lock data selain CABANG_SECURITY)" "select replace(table_name,'DBA.','') tbl, lock_type from sa_locks() where table_name is not null and table_name<>'DBA.CABANG_SECURITY'"
Qry "B. Koneksi aktif (idle kecil = sedang kerja)" "select number, connection_property('Name',number) nm, connection_property('LastIdle',number) idle, connection_property('LastReqTime',number) last_req from sa_conn_info() where number>1"
Qry "C. Marker closing" "select closing_sales from gl_setup"
Qry "D. Kelengkapan data Juni (jurnal & stok)" @"
select
 (select count(*) from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01') gl_jun,
 (select count(*) from sinv where periode='2026-06-01') sinv_jun,
 (select count(*) from sinv where periode='2026-07-01') sinv_jul
"@
$cn.Close()
