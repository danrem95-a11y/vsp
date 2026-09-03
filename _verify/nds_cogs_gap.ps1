$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

# Semua barang KELUAR grup NDS Mei via tsales, dgn HPP dibukukan (tsales2.hpp) vs HPP rata2 sinv (06-01)
Qry "NDS keluar Mei (tsales): COGS dibukukan vs hpp_avg sinv, cari gap" @"
select s2.stok_id, cast(sum(s2.qty) as numeric(18,2)) qty,
  cast(avg(s2.hpp) as numeric(18,4)) hpp_cogs,
  cast(max(sv.hpp_avg) as numeric(18,4)) hpp_sinv,
  cast(sum(s2.qty)*max(sv.hpp_avg) - sum(s2.qty*s2.hpp) as numeric(18,2)) gap_sinv_minus_cogs
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
     join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
     left join sinv sv on sv.stok_id=s2.stok_id and sv.periode='2026-06-01'
where gr.persediaan='102-103' and s1.tgl between '2026-05-01' and '2026-05-31'
group by s2.stok_id
having abs(sum(s2.qty)*max(sv.hpp_avg) - sum(s2.qty*s2.hpp)) > 0.01
order by abs(sum(s2.qty)*max(sv.hpp_avg) - sum(s2.qty*s2.hpp)) desc
"@

# Total COGS NDS Mei vs total pengurangan nilai sinv dari penjualan
Qry "Total gap NDS Mei = Sigma(qty*hpp_avg - qty*hpp_cogs)" @"
select cast(sum(s2.qty*sv.hpp_avg - s2.qty*s2.hpp) as numeric(18,2)) total_gap, count(distinct s2.stok_id) n_item
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
     join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
     left join sinv sv on sv.stok_id=s2.stok_id and sv.periode='2026-06-01'
where gr.persediaan='102-103' and s1.tgl between '2026-05-01' and '2026-05-31'
"@
$cn.Close()
