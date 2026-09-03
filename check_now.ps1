$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
Write-Host ("### "+(Get-Date -Format 'HH:mm:ss')+" ###")
Show "1. Koneksi aktif (berapa user? idle kecil=sibuk)" @"
select number, connection_property('Name',number) nm, connection_property('LastIdle',number) idle, connection_property('NodeAddr',number) node
from sa_conn_info() where number>1 order by connection_property('LastIdle',number)
"@
Show "2. Lock aktif (tabel yg dipegang - lihat kontensi)" @"
select replace(table_name,'DBA.','') tbl, lock_type, count(*) n from sa_locks() where table_name is not null and table_name<>'DBA.CABANG_SECURITY' group by table_name, lock_type order by table_name
"@
Show "3. Cache prod (hit ratio & ukuran)" @"
select cast(property('CacheHits')/(property('CacheHits')+property('CacheRead')+1.0)*100 as numeric(5,2)) hit_pct,
       property('CurrentCacheSize') cache_kb, property('MaxCacheSize') maxcache_kb
from SYS.DUMMY
"@
$P.Close()
