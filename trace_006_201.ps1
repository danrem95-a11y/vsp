$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

foreach($acc in @('102-006','102-201')){
 Show "TRAJEKTORI 2025 $acc : stok vs GL per akhir bulan (cari titik pisah)" @"
select sp.periode,
 cast(sp.stok as numeric(18,2)) stok,
 cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2025-01-01' and accountcode='$acc')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='$acc' and tgl>='2025-01-01' and tgl<sp.periode) as numeric(18,2)) ledger,
 cast(sp.stok - ((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2025-01-01' and accountcode='$acc')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='$acc' and tgl>='2025-01-01' and tgl<sp.periode)) as numeric(18,2)) gap
from (select periode, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
      where gr.persediaan='$acc' and sv.periode in ('2025-01-01','2025-06-01','2025-11-01','2025-12-01','2026-01-01') group by periode) sp order by sp.periode
"@
}

Show "102-006: '88' cons-in SELURUH waktu (tstok) - apakah konsinyasi tahun lama?" @"
select year(t1.tgl) thn, count(*) n, cast(sum(t2.qty) as numeric(18,2)) qty, cast(sum(t2.netto) as numeric(18,2)) nilai
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-006' and t1.tipe_trans='88' group by year(t1.tgl) order by thn
"@
Show "102-006: item + qty saldo awal 2026 + tipe transaksi 2025 (02/09/88/dst)" @"
select sv.stok_id, left(max(pr.produk_desc),26) nm, cast(sum(sv.qty) as numeric(18,2)) qty, cast(sum(sv.nilai) as numeric(18,2)) nilai,
 (select list(distinct t1.tipe_trans) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t2.stok_id=sv.stok_id and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01') tstok_tipe2025
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-006' and sv.periode='2026-01-01' and sv.qty<>0 group by sv.stok_id order by abs(sum(sv.nilai)) desc
"@
Show "102-201 MT: item saldo awal 2026 (qty & nilai) - apa isinya" @"
select sv.stok_id, left(max(pr.produk_desc),30) nm, cast(sum(sv.qty) as numeric(18,2)) qty, cast(sum(sv.nilai) as numeric(18,2)) nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-201' and sv.periode='2026-01-01' group by sv.stok_id order by abs(sum(sv.nilai)) desc
"@
$P.Close()
