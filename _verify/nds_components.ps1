$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$g = "join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-103' and t1.order_oke='Y' and t1.tgl between '2026-05-01' and '2026-05-31'"

Qry "Komponen MUTASI report NDS Mei (per tipe_trans) - nilai" @"
select
 cast((select sum(nilai) from sinv sv join im_produk p on p.produk_id=sv.stok_id join im_product_group gg on gg.kode_group=p.group_product where gg.persediaan='102-103' and sv.periode='2026-05-01') as numeric(20,2)) awal_rp,
 cast((select isnull(sum(t2.netto*isnull(t1.kurs,1)),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $g and t1.tipe_trans='02' and isnull(t2.qty,0)<>0) as numeric(20,2)) beli_netto,
 cast((select isnull(sum(abs(t2.biaya_ekspedisi)*abs(isnull(t2.qty,0))),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $g and t1.tipe_trans='05' and isnull(t2.qty,0)<>0) as numeric(20,2)) ekspedisi,
 cast((select isnull(sum(abs(t2.netto_hpp)),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $g and t1.tipe_trans='12' and isnull(t2.qty,0)<>0) as numeric(20,2)) ret_beli,
 cast((select isnull(sum(t2.netto),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $g and t1.tipe_trans='09' and isnull(t2.qty,0)<>0) as numeric(20,2)) mutasi_in,
 cast((select isnull(sum(abs(t2.netto_hpp)),0) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id $g and t1.tipe_trans='19' and isnull(t2.qty,0)<>0) as numeric(20,2)) mutasi_out
"@

Qry "Ekspedisi tipe-05 NDS Mei detail (kalau ada)" @"
select t2.stok_id, cast(t2.qty as numeric(18,2)) qty, cast(t2.biaya_ekspedisi as numeric(18,4)) biaya_eksp,
  cast(abs(t2.biaya_ekspedisi)*abs(t2.qty) as numeric(18,2)) eksp_rp
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
 join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-103' and t1.tipe_trans='05' and t1.tgl between '2026-05-01' and '2026-05-31'
"@
$cn.Close()
