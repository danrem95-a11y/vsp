$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Time($lbl,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql; $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try{$rd=$c.ExecuteReader(); $rows=0; while($rd.Read()){$rows++}; $rd.Close(); $sw.Stop(); Write-Host ("  {0,-52} {1,8} baris  {2,8:N2} dtk" -f $lbl,$rows,($sw.Elapsed.TotalSeconds))}catch{$sw.Stop(); Write-Host("  $lbl ERR("+([int]$sw.Elapsed.TotalSeconds)+"s): "+$_.Exception.Message)} }
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Volume total tabel kunci" @"
select 'tsales1' t, count(*) n from tsales1 union all select 'tsales2', count(*) from tsales2
union all select 'tstok1', count(*) from tstok1 union all select 'tstok2', count(*) from tstok2
union all select 'sinv', count(*) from sinv
"@

Qry "2. Baris tipe_trans='88' (konsinyasi) per BULAN 2026 di tsales1" @"
select month(tgl) bln, count(*) n from tsales1 where tipe_trans='88' and tgl>='2026-01-01' and tgl<'2026-07-01' group by month(tgl) order by month(tgl)
"@
Qry "2b. Total '88' tsales1 sepanjang waktu (yg dipindai subquery unbounded)" @"
select count(*) n88_total, count(distinct bukti_id) bukti from tsales1 where tipe_trans='88'
"@

Write-Host "== 3. TIMING subquery EVAP unbounded (4b/4d) vs kalau di-scope bulan =="
Time "3a. EVAP subquery UNBOUNDED (spt kode skrg)" "select b.stok_id, isnull(b.evap,'') ev, avg(isnull(b.hpp,0)) hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' group by b.stok_id, isnull(b.evap,'')"
Time "3b. EVAP subquery kalau DI-SCOPE Jun (a.tgl bulan)" "select b.stok_id, isnull(b.evap,'') ev, avg(isnull(b.hpp,0)) hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' and a.tgl>='2026-06-01' and a.tgl<'2026-07-01' group by b.stok_id, isnull(b.evap,'')"

Write-Host "== 4. TIMING UPDATE-equiv SELECT (join penuh) utk step 4b & 4d Juni =="
Time "4b. HPP Penjualan EVAP (tsales2 join, Jun)" @"
select count(*) from tsales2 t2, tsales1 t1,
 (select b.stok_id, isnull(b.evap,'') evap, avg(isnull(b.hpp,0)) hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' group by b.stok_id, isnull(b.evap,'')) HPP
where t2.stok_id=HPP.stok_id and isnull(t2.evap,'')=HPP.evap and isnull(hpp.hpp,0)>=1 and t2.bukti_id=t1.bukti_id and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01'
"@
Time "4d. Konsinyasi IN EVAP (tstok2 join, Jun)" @"
select count(*) from tstok2 t2, tstok1 t1,
 (select b.stok_id, isnull(b.evap,'') evap, avg(isnull(b.hpp,0)) hrg from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' group by b.stok_id, isnull(b.evap,'')) HPP
where t2.stok_id=HPP.stok_id and isnull(t2.coa_id,'')=HPP.evap and isnull(hpp.hrg,0)>=1 and t2.bukti_id=t1.bukti_id and t1.tipe_trans='88' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01'
"@

Qry "5. INDEX pada tsales1/tsales2/tstok1/tstok2 (kolom kunci)" @"
select i.table_name, i.index_name, i.index_category, ic.column_name, ic.sequence
from sysindexes i join sysixcol ic on ic.index_id=i.index_id and ic.table_id=i.table_id
where i.table_name in ('tsales1','tsales2','tstok1','tstok2') order by i.table_name, i.index_name, ic.sequence
"@
$cn.Close()
