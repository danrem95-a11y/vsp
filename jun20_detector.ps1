$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== DETEKTOR: EVAP terjual HPP=0 padahal ada WIP-out ber-HPP utk serial yg sama (Juni 2026) ==="
Reader @"
select s1.tgl jual_tgl, s2.stok_id, s2.evap serial, s1.tipe_trans, s1.bukti_id jual_bukti,
   cast(s2.qty as numeric(18,2)) qty, cast(isnull(s2.hpp,0) as numeric(18,2)) hpp_now,
   cast((select max(x2.hpp) from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id
     where x1.tipe_trans='88' and x2.stok_id=s2.stok_id and x2.evap=s2.evap
       and isnull(x2.hpp,0)>0 and x1.tgl < s1.tgl) as numeric(18,2)) hpp_seharusnya
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','88') and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01' and s1.order_oke='Y'
  and isnull(s2.hpp,0)=0 and s2.qty>0 and isnull(s2.evap,'')<>''
  and exists (select 1 from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id
     where x1.tipe_trans='88' and x2.stok_id=s2.stok_id and x2.evap=s2.evap and isnull(x2.hpp,0)>0 and x1.tgl < s1.tgl)
order by s1.tgl
"@

Write-Host "`n=== Uji ke belakang: seluruh 2026 (berapa sering sebenarnya) ==="
Reader @"
select month(s1.tgl) bln, count(*) n_kasus
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','88') and s1.tgl>='2026-01-01' and s1.tgl<'2027-01-01' and s1.order_oke='Y'
  and isnull(s2.hpp,0)=0 and s2.qty>0 and isnull(s2.evap,'')<>''
  and exists (select 1 from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id
     where x1.tipe_trans='88' and x2.stok_id=s2.stok_id and x2.evap=s2.evap and isnull(x2.hpp,0)>0 and x1.tgl < s1.tgl)
group by month(s1.tgl) order by bln
"@

$cn.Close()
