$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Write-Host ("### MONITOR "+(Get-Date -Format 'HH:mm:ss')+" ###")

Qry "1. Index EVAP terpasang?" @"
select tname, iname, colnames from SYS.SYSINDEXES where tname='tsales1' and iname='idx_tsales1_tt_bukti'
"@

Qry "2. Koneksi aktif + statement terakhir" @"
select number, connection_property('LastStatement', number) as last_stmt
from sa_conn_info()
"@

Qry "3. Marker progres (gl_setup)" @"
select closing_sales, closing_stok from gl_setup
"@

Qry "4. Lock aktif (tabel yg sedang ditulis refresh)" @"
select distinct table_name, lock_type from sa_locks() where table_name is not null
"@
$cn.Close()
