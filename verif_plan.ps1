$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. PLAN query closing (apakah pakai idx_sinv_periode?)" @"
select plan('select stok_id, sum(qty), sum(nilai), avg(hpp_avg) from sinv where periode=''2026-07-01'' group by stok_id') p from SYS.DUMMY
"@

Show "2. Aktivitas: koneksi & yg sibuk (refresh jalan?)" @"
select number, connection_property('Name',number) nm, connection_property('LastIdle',number) idle
from sa_conn_info() where number>1 order by connection_property('LastIdle',number)
"@

Show "3. Lock di SINV / tabel besar sekarang" @"
select replace(table_name,'DBA.','') tbl, lock_type, count(*) n from sa_locks() where table_name is not null and table_name<>'DBA.CABANG_SECURITY' group by table_name, lock_type order by table_name
"@
$P.Close()
