$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=250; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. Item 102-001 yg QTY-nya berubah: akhir Nov (2025-12-01) vs akhir Des (2026-01-01)" @"
select nov.stok_id, left(max(pr.produk_desc),28) nm, cast(isnull(nov.q,0) as numeric(18,2)) qty_nov, cast(isnull(des.q,0) as numeric(18,2)) qty_des, cast(isnull(des.q,0)-isnull(nov.q,0) as numeric(18,2)) delta, cast(isnull(des.n,0)-isnull(nov.n,0) as numeric(18,2)) delta_nilai
from (select stok_id, qty q, nilai n from sinv where periode='2026-01-01') des
 full outer join (select stok_id, qty q, nilai n from sinv where periode='2025-12-01') nov on nov.stok_id=des.stok_id
 join im_produk pr on pr.produk_id=isnull(des.stok_id,nov.stok_id)
 join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and abs(isnull(des.q,0)-isnull(nov.q,0))>0.01
group by nov.stok_id, des.stok_id, nov.q, des.q, nov.n, des.n order by abs(isnull(des.q,0)-isnull(nov.q,0)) desc
"@

Show "2. Transaksi TSTOK 102-001 Desember 2025 per tipe (ada gerakan riil +62 unit?)" @"
select t1.tipe_trans, count(*) n, cast(sum(t2.qty) as numeric(18,2)) qty
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and t1.tgl>='2025-12-01' and t1.tgl<'2026-01-01' group by t1.tipe_trans order by t1.tipe_trans
"@
Show "3. Transaksi TSALES 102-001 Desember 2025 per tipe" @"
select s1.tipe_trans, count(*) n, cast(sum(s2.qty) as numeric(18,2)) qty
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and s1.tgl>='2025-12-01' and s1.tgl<'2026-01-01' group by s1.tipe_trans order by s1.tipe_trans
"@
$P.Close()
