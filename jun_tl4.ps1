$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Konsistensi sinv TL/TSA Jul: sum(nilai) vs sum(qty*hpp_avg)" @"
select cast(sum(sv.nilai) as numeric(18,2)) tot_nilai, cast(sum(sv.qty*sv.hpp_avg) as numeric(18,2)) tot_qty_x_hpp, cast(sum(sv.nilai)-sum(sv.qty*sv.hpp_avg) as numeric(18,2)) beda
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-102' and sv.periode='2026-07-01'
"@

Qry "2. Mutasi tipe 09/19 TL/TSA Jun: netto(GL) vs moving-avg(qty*hpp_avg Jul) per tipe" @"
select t1.tipe_trans, cast(sum(t2.netto) as numeric(18,2)) netto_gl, cast(sum(t2.qty*isnull(sv.hpp_avg,0)) as numeric(18,2)) movavg, cast(sum(t2.netto)-sum(t2.qty*isnull(sv.hpp_avg,0)) as numeric(18,2)) selisih
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
 join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
 left join sinv sv on sv.stok_id=t2.stok_id and sv.periode='2026-07-01'
where gr.persediaan='102-102' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' and t1.tipe_trans in ('09','19')
group by t1.tipe_trans
"@

Qry "3. Per-item mutasi 09/19 dgn selisih netto vs movavg terbesar (top 15)" @"
select top 15 t1.tipe_trans, t2.stok_id, cast(t2.qty as numeric(18,2)) qty, cast(t2.netto as numeric(18,2)) netto_gl,
 cast(isnull(sv.hpp_avg,0) as numeric(18,2)) hpp_avg, cast(t2.netto - t2.qty*isnull(sv.hpp_avg,0) as numeric(18,2)) selisih, left(t1.bukti_id,18) bukti
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
 join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
 left join sinv sv on sv.stok_id=t2.stok_id and sv.periode='2026-07-01'
where gr.persediaan='102-102' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' and t1.tipe_trans in ('09','19')
order by abs(t2.netto - t2.qty*isnull(sv.hpp_avg,0)) desc
"@
$cn.Close()
