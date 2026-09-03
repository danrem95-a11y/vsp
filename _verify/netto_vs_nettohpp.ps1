$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "NDS tipe-19 Mei: NETTO (report LAMA) vs NETTO_HPP (report BARU) per item" @"
select t2.stok_id, cast(t2.qty as numeric(18,2)) qty,
  cast(t2.netto as numeric(18,4)) netto_lama,
  cast(t2.netto_hpp as numeric(18,4)) netto_hpp_baru,
  cast(abs(t2.netto_hpp)-abs(t2.netto) as numeric(18,2)) selisih
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
     join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-103' and t1.tipe_trans='19' and t1.tgl between '2026-05-01' and '2026-05-31'
order by abs(abs(t2.netto_hpp)-abs(t2.netto)) desc
"@

Qry "TOTAL: (Sigma NETTO_HPP - Sigma NETTO) NDS tipe-19 Mei = harus 422,43" @"
select cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) tot_netto_hpp_baru,
       cast(sum(abs(t2.netto)) as numeric(18,2)) tot_netto_lama,
       cast(sum(abs(t2.netto_hpp))-sum(abs(t2.netto)) as numeric(18,2)) selisih_422
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
     join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-103' and t1.tipe_trans='19' and t1.tgl between '2026-05-01' and '2026-05-31'
"@
$cn.Close()
