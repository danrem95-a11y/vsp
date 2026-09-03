$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
$accIn="(select distinct persediaan from im_product_group where persediaan is not null and persediaan<>'')"

Show "1. SALDO AWAL 2026 per akun: sinv(01-01) vs gl_balance - akun mismatch >1jt" @"
select p.acc, cast(p.gl as numeric(18,2)) gl_saldoawal, cast(isnull(sv.stok,0) as numeric(18,2)) sinv_saldoawal, cast(isnull(sv.stok,0)-p.gl as numeric(18,2)) selisih
from (select accountcode acc, sum(amountdebet-amountcredit) gl from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn group by accountcode) p
 left join (select gr.persediaan acc, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-01-01' group by gr.persediaan) sv on sv.acc=p.acc
where abs(isnull(sv.stok,0)-p.gl)>1000000 order by abs(isnull(sv.stok,0)-p.gl) desc
"@

Show "2. TOTAL selisih saldo awal (sinv vs gl) semua akun persediaan" @"
select cast(sum(isnull(sv.stok,0)) as numeric(18,2)) sinv_total, cast(sum(p.gl) as numeric(18,2)) gl_total, cast(sum(isnull(sv.stok,0))-sum(p.gl) as numeric(18,2)) selisih_total
from (select accountcode acc, sum(amountdebet-amountcredit) gl from gl_balance where site_id='101' and period='2026-01-01' and accountcode in $accIn group by accountcode) p
 left join (select gr.persediaan acc, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-01-01' group by gr.persediaan) sv on sv.acc=p.acc
"@

Show "3. gl_journal 102-001 per bulan Jan-Jun (cek trajektori)" @"
select month(tgl) bln, cast(sum(debet-kredit) as numeric(18,2)) net, count(*) n from gl_journal where posting='P' and account_id='102-001' and tgl>='2026-01-01' and tgl<'2026-07-01' group by month(tgl) order by month(tgl)
"@
$P.Close()
