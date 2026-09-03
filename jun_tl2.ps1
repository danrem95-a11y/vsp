$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. GL 102-102 JUNI per modul" @"
select modul_id, count(*) n, cast(sum(debet) as numeric(18,2)) db, cast(sum(kredit) as numeric(18,2)) kr, cast(sum(debet)-sum(kredit) as numeric(18,2)) net_val
from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-06-01' and tgl<'2026-07-01' group by modul_id
"@

Qry "2. Perubahan STOK grup TL/TSA: sinv akhir Mei vs akhir Jun (nilai)" @"
select
 cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-06-01') as numeric(18,2)) stok_awal_jun,
 cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-07-01') as numeric(18,2)) stok_akhir_jun
from SYS.DUMMY
"@

Qry "3. Ledger 102-102: saldo awal Jun vs akhir Jun (utk delta)" @"
select
 cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-06-01') as numeric(18,2)) ledger_awal_jun,
 cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-07-01') as numeric(18,2)) ledger_akhir_jun
from SYS.DUMMY
"@

Qry "4. Cek gap per bulan (kapan tepatnya muncul 105rb)" @"
select p bln,
 cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<dateadd(month,1,p)) as numeric(18,2))
 - cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode=dateadd(month,1,p)) as numeric(18,2)) gap
from (select cast('2026-05-01' as date) p union all select cast('2026-06-01' as date)) x order by p
"@
$cn.Close()
