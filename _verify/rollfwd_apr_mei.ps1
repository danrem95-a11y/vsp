$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

# t1..t2 = April; join grup NDS 102-103; ORDER_OKE='Y'
$tk = "join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-103' and t1.order_oke='Y' and t1.tgl between '2026-04-01' and '2026-04-30'"
$ts = "join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-103' and s1.order_oke='Y' and s1.tgl between '2026-04-01' and '2026-04-30'"

Qry "ROLLFORWARD NDS: Saldo Akhir April (dihitung) vs Saldo Awal Mei (sinv 05-01)" @"
select
 cast(awal + beli_rp + retjual + consin + mutin - cjual - retbeli - consout - mutout as numeric(20,2)) saldo_akhir_april_hitung,
 cast(awal_mei as numeric(20,2)) saldo_awal_mei_sinv,
 cast((awal + beli_rp + retjual + consin + mutin - cjual - retbeli - consout - mutout) - awal_mei as numeric(20,2)) selisih
from (
 select
  (select isnull(sum(sv.nilai),0) from sinv sv join im_produk p on p.produk_id=sv.stok_id join im_product_group gg on gg.kode_group=p.group_product where gg.persediaan='102-103' and sv.periode='2026-04-01') awal,
  (select isnull(sum(sv.nilai),0) from sinv sv join im_produk p on p.produk_id=sv.stok_id join im_product_group gg on gg.kode_group=p.group_product where gg.persediaan='102-103' and sv.periode='2026-05-01') awal_mei,
  (select isnull(sum(t2.netto*isnull(t1.kurs,1)),0)+isnull((select sum(abs(t2.biaya_ekspedisi)*abs(t2.qty)) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $tk and t1.tipe_trans='05' and isnull(t2.qty,0)<>0),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $tk and t1.tipe_trans='02' and isnull(t2.qty,0)<>0) beli_rp,
  (select isnull(sum(abs(t2.netto_hpp)),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $tk and t1.tipe_trans='12' and isnull(t2.qty,0)<>0) retbeli,
  (select isnull(sum(t2.netto),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $tk and t1.tipe_trans='09' and isnull(t2.qty,0)<>0) mutin,
  (select isnull(sum(abs(t2.netto_hpp)),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $tk and t1.tipe_trans='19' and isnull(t2.qty,0)<>0) mutout,
  (select isnull(sum(t2.qty*isnull(t2.netto,0)),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $tk and t1.tipe_trans='88' and isnull(t2.qty,0)<>0) consin,
  (select isnull(sum(s2.qty*isnull(s2.hpp,0)),0) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id $ts and s1.tipe_trans='22' and isnull(s2.qty,0)<>0) cjual,
  (select isnull(sum(case when s1.tipe_trans='88' then s2.hpp*s2.qty else 0 end),0) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id $ts and s1.tipe_trans='88' and isnull(s2.qty,0)<>0) consout,
  (select isnull(sum(case when s1.tipe_trans in('32','26','36') then abs(s2.netto*isnull(s1.kurs,1)) else 0 end),0) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id $ts and s1.tipe_trans in('32','26','36') and isnull(s2.qty,0)<>0 and isnull(s2.hrg,0)<>0) retjual
 from dummy
) x
"@

Qry "Per item: Saldo Akhir April (sinv 05-01) = Saldo Awal Mei (sinv 05-01)? (harus identik)" @"
select count(*) n_item_beda
from sinv a join sinv b on b.stok_id=a.stok_id and b.periode='2026-05-01'
     join im_produk pr on pr.produk_id=a.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where a.periode='2026-05-01' and gr.persediaan='102-103' and abs(a.nilai-b.nilai)>0.001
"@
$cn.Close()
