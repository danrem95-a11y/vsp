$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== A1. DETERMINISME MAX: (stok_id,evap) dgn >1 nilai HPP consout BEDA (MAX bisa salah) ==="
Reader @"
select count(*) n_serial_ambigu, cast(sum(spread) as numeric(18,2)) total_spread_rp, cast(max(spread) as numeric(18,2)) max_spread_rp
from (
  select c2.stok_id, c2.evap, count(distinct cast(c2.hpp as numeric(18,2))) n_hpp,
         max(c2.hpp)-min(c2.hpp) spread
  from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
  where c1.tipe_trans='88' and isnull(c2.evap,'')<>'' and isnull(c2.hpp,0)>0
  group by c2.stok_id, c2.evap
  having count(distinct cast(c2.hpp as numeric(18,2))) > 1
) x
"@

Write-Host "`n=== A1b. Contoh serial ambigu (MIN vs MAX HPP consout, beda >1jt) ==="
Reader @"
select top 12 c2.stok_id, c2.evap, count(*) n_row,
   cast(min(c2.hpp) as numeric(18,2)) hpp_min, cast(max(c2.hpp) as numeric(18,2)) hpp_max,
   cast(max(c2.hpp)-min(c2.hpp) as numeric(18,2)) spread
from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
where c1.tipe_trans='88' and isnull(c2.evap,'')<>'' and isnull(c2.hpp,0)>0
group by c2.stok_id, c2.evap
having max(c2.hpp)-min(c2.hpp) > 1000000
order by max(c2.hpp)-min(c2.hpp) desc
"@

Write-Host "`n=== A2. ANACHRONISM: consout ada SETELAH tgl jual (fallback pakai cost masa depan) ==="
Reader @"
select count(*) n_kasus_future_cost
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0
  and s1.tgl>='2026-01-01' and s1.tgl<'2027-01-01'
  and not exists (select 1 from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
        where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0 and c1.tgl<=s1.tgl)
  and exists (select 1 from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
        where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0 and c1.tgl>s1.tgl)
"@

Write-Host "`n=== A3. ORPHAN: jual EVAP hpp=0 TANPA consout sama sekali (fallback tak menolong -> tetap 0) ==="
Reader @"
select count(*) n_orphan, cast(sum(s2.qty) as numeric(18,2)) qty
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','88') and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
  and s1.tgl>='2026-01-01' and s1.tgl<'2027-01-01'
  and not exists (select 1 from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
        where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
"@

Write-Host "`n=== A4. Apakah evap (serial) unik per stok? evap dipakai >1 stok_id berbeda ==="
Reader @"
select count(*) n_evap_lintas_stok from (
  select c2.evap from tsales2 c2 where isnull(c2.evap,'')<>''
  group by c2.evap having count(distinct c2.stok_id) > 1
) y
"@

$cn.Close()
