$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== 102-001 GL Juni per MODUL ==="
Reader @"
select modul_id, cast(sum(debet) as numeric(18,2)) deb, cast(sum(kredit) as numeric(18,2)) kre,
       cast(sum(debet-kredit) as numeric(18,2)) net, count(*) n
from gl_journal where posting='P' and account_id='102-001' and tgl>='2026-06-01' and tgl<'2026-07-01'
group by modul_id order by modul_id
"@

Write-Host "`n=== TR: gerakan STOK Juni per tipe_trans (tstok) ==="
Reader @"
select t1.tipe_trans,
   count(distinct t1.bukti_id) n_bukti,
   cast(sum(t2.qty) as numeric(18,2)) qty,
   cast(sum(t2.netto) as numeric(18,2)) sum_netto,
   cast(sum(t2.netto_hpp) as numeric(18,2)) sum_netto_hpp
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
   join im_produk pr on pr.produk_id=t2.stok_id
where pr.group_product='TR' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' and t1.order_oke='Y'
group by t1.tipe_trans order by t1.tipe_trans
"@

Write-Host "`n=== TR: penjualan/COGS Juni per tipe_trans (tsales) ==="
Reader @"
select s1.tipe_trans,
   count(distinct s1.bukti_id) n_bukti,
   cast(sum(s2.qty) as numeric(18,2)) qty,
   cast(sum(s2.qty*isnull(s2.hpp,0)) as numeric(18,2)) cogs_qtyhpp,
   sum(case when isnull(s2.hpp,0)=0 and s2.qty<>0 then 1 else 0 end) n_hpp0
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
   join im_produk pr on pr.produk_id=s2.stok_id
where pr.group_product='TR' and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01' and s1.order_oke='Y'
group by s1.tipe_trans order by s1.tipe_trans
"@

$cn.Close()
