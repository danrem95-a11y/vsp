$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong / tidak ada break>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$acc = "(select distinct persediaan acc from im_product_group where isnull(persediaan,'')<>'')"

# Per akun persediaan: apakah opening Mei (sinv 2026-05-01) = opening Apr (sinv 2026-04-01) + mutasi GL April?
Qry "STOK rollforward Apr->Mei per akun (opening Mei vs opening Apr + mutasi GL Apr)" @"
select g.acc,
  cast(isnull(oa.stk,0) as numeric(20,2))  opening_apr,
  cast(isnull(om.stk,0) as numeric(20,2))  opening_mei_eq_close_apr,
  cast(isnull(om.stk,0)-isnull(oa.stk,0) as numeric(20,2)) mutasi_stok,
  cast(isnull(mv.mov,0) as numeric(20,2))  mutasi_gl,
  cast((isnull(om.stk,0)-isnull(oa.stk,0))-isnull(mv.mov,0) as numeric(20,2)) BREAK
from $acc g
left join (select gr.persediaan acc,sum(s.nilai) stk from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='2026-04-01' group by gr.persediaan) oa on oa.acc=g.acc
left join (select gr.persediaan acc,sum(s.nilai) stk from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='2026-05-01' group by gr.persediaan) om on om.acc=g.acc
left join (select account_id acc,sum(debet-kredit) mov from gl_journal where posting='P' and tgl between '2026-04-01' and '2026-04-30' group by account_id) mv on mv.acc=g.acc
where abs((isnull(om.stk,0)-isnull(oa.stk,0))-isnull(mv.mov,0)) > 0.005
order by abs((isnull(om.stk,0)-isnull(oa.stk,0))-isnull(mv.mov,0)) desc
"@

# Drill per item: sinv 2026-05-01 vs 2026-04-01 (qty & nilai) - lihat item yang berubah anomali
Qry "TOP item: perubahan hpp_avg antar 2026-04-01 -> 2026-05-01 dgn qty SAMA (revaluasi diam)" @"
select a.stok_id, pr.produk_desc,
  cast(a.qty as numeric(18,2)) qty_apr, cast(b.qty as numeric(18,2)) qty_mei,
  cast(a.hpp_avg as numeric(18,4)) hpp_apr, cast(b.hpp_avg as numeric(18,4)) hpp_mei,
  cast(a.nilai as numeric(18,2)) nilai_apr, cast(b.nilai as numeric(18,2)) nilai_mei
from sinv a join sinv b on b.stok_id=a.stok_id and b.periode='2026-05-01'
     join im_produk pr on pr.produk_id=a.stok_id
where a.periode='2026-04-01' and abs(a.qty-b.qty) < 0.001 and abs(a.hpp_avg-b.hpp_avg) > 0.01
order by abs(a.nilai-b.nilai) desc
"@
$cn.Close()
