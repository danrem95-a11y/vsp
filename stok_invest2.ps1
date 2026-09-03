$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
$accIn="(select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')"

Show "1. GAP total per periode (refreshed vs Juni yg belum) - stok vs ledger" @"
select x.p periode, cast(x.stok as numeric(18,2)) stok, cast(x.led as numeric(18,2)) ledger, cast(x.stok-x.led as numeric(18,2)) gap
from (
 select '2026-02-01' p, (select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan is not null and gr.persediaan<>'' and sv.periode='2026-02-01') stok,
   (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn)+(select sum(debet-kredit) from gl_journal where posting='P' and account_id in $accIn and tgl>='2026-01-01' and tgl<'2026-02-01') led
 union all select '2026-05-01', (select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan is not null and gr.persediaan<>'' and sv.periode='2026-05-01'),
   (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn)+(select sum(debet-kredit) from gl_journal where posting='P' and account_id in $accIn and tgl>='2026-01-01' and tgl<'2026-05-01')
 union all select '2026-07-01(Jun,blm refresh)', (select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan is not null and gr.persediaan<>'' and sv.periode='2026-07-01'),
   (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn)+(select sum(debet-kredit) from gl_journal where posting='P' and account_id in $accIn and tgl>='2026-01-01' and tgl<'2026-07-01')
) x order by x.p
"@

Show "2. 102-001: opening gl_balance vs opening sinv (2026-01-01) - mismatch?" @"
select cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001') as numeric(18,2)) gl_opening,
       cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-001' and sv.periode='2026-01-01') as numeric(18,2)) sinv_opening
from SYS.DUMMY
"@

Show "3. 102-001 April: 8 item nilai terbesar" @"
select top 8 sv.stok_id, cast(sv.qty as numeric(18,2)) qty, cast(sv.nilai as numeric(18,2)) nilai, cast(sv.hpp_avg as numeric(18,2)) hpp_avg, left(pr.produk_desc,24) nm
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and sv.periode='2026-05-01' order by abs(sv.nilai) desc
"@
$cn.Close()
