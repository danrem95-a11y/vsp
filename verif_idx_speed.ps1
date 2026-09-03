$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Time($lbl,$sql){ $c=$P.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql; $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try{$rd=$c.ExecuteReader(); $n=0; while($rd.Read()){$n++}; $rd.Close(); $sw.Stop(); Write-Host ("  {0,-46} {1,7} baris  {2,7:N2} dtk" -f $lbl,$n,$sw.Elapsed.TotalSeconds)}catch{$sw.Stop(); Write-Host("  $lbl ERR: "+$_.Exception.Message)} }
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "A. Urutan KUNCI sebenarnya idx_sinv_periode (via SYSIXCOL, sequence=1 dulu)" @"
select ixc.sequence seq, c.column_name col
from SYS.SYSIXCOL ixc, SYS.SYSINDEX i, SYS.SYSCOLUMN c, SYS.SYSTABLE t
where i.index_name='idx_sinv_periode' and t.table_name='sinv'
  and i.table_id=t.table_id and ixc.index_id=i.index_id and ixc.table_id=i.table_id
  and c.table_id=ixc.table_id and c.column_id=ixc.column_id
order by ixc.sequence
"@

Write-Host "== B. UJI KECEPATAN (pola query closing: WHERE periode= GROUP BY stok_id) =="
Time "B1. run-1 (cold)" "select stok_id, sum(qty) q, sum(nilai) n, avg(hpp_avg) h from sinv where periode='2026-07-01' group by stok_id"
Time "B2. run-2 (warm)" "select stok_id, sum(qty) q, sum(nilai) n, avg(hpp_avg) h from sinv where periode='2026-07-01' group by stok_id"
$P.Close()
