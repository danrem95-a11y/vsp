$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Per BULAN: sinyal refresh (ada hpp>0?) + target fallback (EVAP-22 hpp=0 punya WIP-out) + dampak COGS ==="
Reader @"
select month(s1.tgl) bln,
  count(*) n_evap22,
  sum(case when isnull(s2.hpp,0)>0 then 1 else 0 end) n_hpp_terisi,
  sum(case when isnull(s2.hpp,0)=0 then 1 else 0 end) n_hpp_nol,
  sum(case when isnull(s2.hpp,0)=0 and exists(select 1 from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
        where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0) then 1 else 0 end) n_fallback,
  cast(sum(case when isnull(s2.hpp,0)=0 then
        s2.qty * isnull((select max(c2.hpp) from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
           where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0),0)
      else 0 end) as numeric(18,2)) dampak_cogs_rp
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and s1.order_oke='Y'
  and s1.tgl>='2026-01-01' and s1.tgl<'2027-01-01'
group by month(s1.tgl) order by bln
"@

Write-Host "`n=== Struktur pengaman: baris NON-EVAP tak pernah kena fallback (evap kosong -> fallback null) ==="
Reader @"
select count(*) n_nonevap_hpp0_wouldchange
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','32','26','36','88') and isnull(s2.evap,'')='' and isnull(s2.hpp,0)=0
  and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01'
"@

$cn.Close()
