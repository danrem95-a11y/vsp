$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "Grup yang persediaan=102-103" "select kode_group, nama_group from im_product_group where persediaan='102-103'"

Qry "Cek angka akun 102-103: stok(sinv) vs GL, Apr & Mei closing" @"
select 'stok_close_apr(sinv 05-01)' k, cast(sum(nilai) as numeric(20,2)) v from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-103' and s.periode='2026-05-01'
union all select 'stok_close_mei(sinv 06-01)', cast(sum(nilai) as numeric(20,2)) from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-103' and s.periode='2026-06-01'
union all select 'GL_close_apr', cast((select sum(amountdebet-amountcredit) from gl_balance where accountcode='102-103' and period='2026-01-01') + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-103' and tgl<='2026-04-30') as numeric(20,2))
union all select 'GL_close_mei', cast((select sum(amountdebet-amountcredit) from gl_balance where accountcode='102-103' and period='2026-01-01') + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-103' and tgl<='2026-05-31') as numeric(20,2))
"@

Qry "Per item NDS: delta nilai Mei (sinv 06-01 - 05-01) + qty keluar Mei" @"
select b.stok_id, cast(a.qty as numeric(18,2)) qty_awal, cast(b.qty as numeric(18,2)) qty_akhir,
  cast(a.hpp_avg as numeric(18,4)) hpp_awal, cast(b.hpp_avg as numeric(18,4)) hpp_akhir,
  cast(b.nilai-a.nilai as numeric(18,2)) delta_nilai
from sinv a join sinv b on b.stok_id=a.stok_id and b.periode='2026-06-01'
     join im_produk pr on pr.produk_id=a.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where a.periode='2026-05-01' and gr.persediaan='102-103'
  and abs(b.nilai-a.nilai) > 0.001
order by abs(b.nilai-a.nilai) desc
"@
$cn.Close()
