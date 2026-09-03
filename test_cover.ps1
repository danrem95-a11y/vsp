$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Time($lbl,$sql){ $c=$P.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql; $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try{$v=$c.ExecuteScalar(); $sw.Stop(); Write-Host ("  {0,-52} hasil={1,7}  {2,7:N2} dtk" -f $lbl,$v,$sw.Elapsed.TotalSeconds)}catch{$sw.Stop(); Write-Host("  $lbl ERR("+[int]$sw.Elapsed.TotalSeconds+"s): "+$_.Exception.Message)} }
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "0. Ada aktivitas/lock lain? (refresh jalan = kontensi)" "select replace(table_name,'DBA.','') tbl, lock_type from sa_locks() where table_name is not null and table_name<>'DBA.CABANG_SECURITY'"
Write-Host "== UJI =="
Time "COVERED (cuma periode+stok_id, tak fetch tabel)" "select count(distinct stok_id) from sinv where periode='2026-07-01'"
Time "NON-COVERED (fetch nilai dari tabel)" "select cast(sum(nilai) as numeric(18,2)) from sinv where periode='2026-07-01'"
$P.Close()
