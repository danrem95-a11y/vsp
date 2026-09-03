$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
$accIn="(select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')"

Show "1. STOK persediaan (sinv total) per periode - kapan menggelembung?" @"
select periode, cast(sum(sv.nilai) as numeric(18,2)) stok_total
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan is not null and gr.persediaan<>'' and sv.periode in ('2026-01-01','2026-02-01','2026-03-01','2026-04-01','2026-05-01','2026-06-01','2026-07-01')
group by periode order by periode
"@

Show "2. Khusus 102-001: sinv per periode" @"
select sv.periode, cast(sum(sv.nilai) as numeric(18,2)) stok, cast(sum(sv.qty) as numeric(18,2)) qty, count(*) n_item
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and sv.periode in ('2026-01-01','2026-02-01','2026-05-01','2026-07-01')
group by sv.periode order by sv.periode
"@

Show "3. 102-001 di April: 10 item nilai terbesar (cari yg menggelembung)" @"
select top 10 sv.stok_id, cast(sv.qty as numeric(18,2)) qty, cast(sv.nilai as numeric(18,2)) nilai, cast(sv.hpp_avg as numeric(18,4)) hpp_avg, left(pr.produk_desc,26) desc
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and sv.periode='2026-05-01' order by abs(sv.nilai) desc
"@

Show "4. Ledger 102-001 akhir April (opening+gl) vs stok" @"
select cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001')
          + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-001' and tgl>='2026-01-01' and tgl<'2026-05-01') as numeric(18,2)) ledger_apr
from SYS.DUMMY
"@
$cn.Close()
