$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Produk: jual Juni HPP=0, TAPI punya consout(WIP-out) ber-HPP di Mei ==="
Reader @"
select top 20 s2.stok_id,
  count(*) n_jual0, cast(sum(s2.qty) as numeric(18,2)) qty0,
  (select cast(max(x2.hpp) as numeric(18,2)) from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id
     where x2.stok_id=s2.stok_id and x1.tipe_trans='88' and x1.tgl>='2026-05-01' and x1.tgl<'2026-06-01' and isnull(x2.hpp,0)>0) mei_consout_hpp,
  (select cast(sum(sv.nilai) as numeric(18,2)) from sinv sv where sv.stok_id=s2.stok_id and sv.periode='2026-06-01') saldo_awal_jun_rp,
  (select cast(sum(sv.qty) as numeric(18,2)) from sinv sv where sv.stok_id=s2.stok_id and sv.periode='2026-06-01') saldo_awal_jun_qty
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','88') and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01' and s1.order_oke='Y'
  and isnull(s2.hpp,0)=0 and s2.qty>0
group by s2.stok_id
having (select count(*) from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id
     where x2.stok_id=s2.stok_id and x1.tipe_trans='88' and x1.tgl>='2026-05-01' and x1.tgl<'2026-06-01' and isnull(x2.hpp,0)>0) > 0
order by n_jual0 desc
"@

$cn.Close()
