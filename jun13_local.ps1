# Konek ke DB LOKAL (DSN=vsp) tempat refresh sedang jalan
$cn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
try{ $cn.Open() }catch{ Write-Host ("GAGAL konek DSN=vsp lokal: "+$_.Exception.Message); exit }
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Identitas engine + cache ==="
Reader "select db_name() dbname, property('Name') eng, property('CommandLine') cmd"
Reader "select PropName, Value from sa_eng_properties() where PropName in ('CacheSize','CacheSizingStatistics','MaxCacheSize','MinCacheSize','CurrentCacheSize','PageSize')"

Write-Host "`n=== APA YANG SEDANG DIKERJAKAN tiap koneksi (LastStatement) ==="
Reader "select Number, UserID, LastReqTime, LastStatement from sa_conn_info()"

Write-Host "`n=== Aktivitas (sa_conn_activity) ==="
Reader "select * from sa_conn_activity()"

Write-Host "`n=== Index gl_journal di LOKAL (konfirmasi index user) ==="
Reader @"
select ix.index_name,
  (select list(sc.column_name order by ic.sequence)
     from SYS.SYSIXCOL ic join SYS.SYSCOLUMN sc on sc.table_id=ic.table_id and sc.column_id=ic.column_id
     where ic.table_id=ix.table_id and ic.index_id=ix.index_id) cols
from SYS.SYSINDEX ix join SYS.SYSTABLE t on t.table_id=ix.table_id
where t.table_name='gl_journal' order by ix.index_name
"@

$cn.Close()
