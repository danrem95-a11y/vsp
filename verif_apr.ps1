$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=250; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. TL.203.0504 moving-avg per periode (Feb-Mei 2026 hrs POSITIF sekarang)" @"
select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,4)) hpp_avg
from sinv where stok_id='TL.203.0504' and periode>='2026-01-01' and periode<='2026-08-01' order by periode
"@

Show "2. Gap 102-102 per akhir bulan (Ledger vs Stok) - Jan..Apr" @"
select p.bln,
 cast(p.led as numeric(18,2)) ledger, cast(s.stok as numeric(18,2)) stok, cast(p.led - s.stok as numeric(18,2)) gap
from
 (select '2026-02-01' bln, (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-02-01') led
  union all select '2026-03-01', (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')+(select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-03-01')
  union all select '2026-04-01', (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')+(select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-04-01')
  union all select '2026-05-01', (select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')+(select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-05-01')
 ) p
 join (select '2026-02-01' bln, (select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-02-01') stok
  union all select '2026-03-01',(select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-03-01')
  union all select '2026-04-01',(select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-04-01')
  union all select '2026-05-01',(select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-05-01')
 ) s on s.bln=p.bln order by p.bln
"@

Show "3. INTEGRITAS 2025 (cross-month delete? hrs 3 record ADA + gl 51.128)" @"
select (select count(*) from tbyr1 where voucher in ('25112004R117R','25122004R009R','200410125100303')) tbyr_metro_bingshan_hrs3,
       (select count(*) from gl_journal where tgl>='2025-01-01' and tgl<'2026-01-01') gl_2025_hrs51128
from SYS.DUMMY
"@

Show "4. GL per bulan Jan-Apr: net non-RL (semua modul refresh hrs 0)" @"
select month(tgl) bln, cast(sum(debet)-sum(kredit) as numeric(18,2)) net_total, cast(sum(case when modul_id='GJ' then debet-kredit else 0 end) as numeric(18,2)) net_gj_rl
from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'2026-05-01' group by month(tgl) order by month(tgl)
"@
$P.Close()
