$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "SEMUA tsales item grup NDS Mei (tipe apapun): qty, netto, hpp, kurs" @"
select s1.tipe_trans, s2.stok_id, cast(s2.qty as numeric(18,2)) qty,
  cast(s2.netto as numeric(18,4)) netto, cast(s2.hpp as numeric(18,4)) hpp, cast(isnull(s1.kurs,1) as numeric(18,4)) kurs,
  cast(abs(s2.netto)*isnull(s1.kurs,1) as numeric(18,2)) netto_kurs, cast(abs(s2.qty)*s2.hpp as numeric(18,2)) qty_hpp
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
     join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-103' and s1.tgl between '2026-05-01' and '2026-05-31'
order by s1.tipe_trans, s2.stok_id
"@

Qry "RET_JUAL report NDS Mei: netto_kurs (report LAMA) vs qty*hpp (benar) - selisih" @"
select cast(sum(abs(s2.netto)*isnull(s1.kurs,1)) as numeric(18,2)) ret_jual_rp_report,
  cast(sum(abs(s2.qty)*s2.hpp) as numeric(18,2)) ret_jual_at_hpp,
  cast(sum(abs(s2.netto)*isnull(s1.kurs,1)) - sum(abs(s2.qty)*s2.hpp) as numeric(18,2)) selisih
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
     join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-103' and s1.tipe_trans in ('32','26','36') and s1.tgl between '2026-05-01' and '2026-05-31'
  and isnull(s2.qty,0)<>0 and isnull(s2.hrg,0)<>0
"@
$cn.Close()
