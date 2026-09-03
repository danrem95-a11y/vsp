$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=200; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. gl_balance akun 102-201 semua periode (saldo AWAL tiap tahun)" @"
select Period, cast(sum(AmountDebet-AmountCredit) as numeric(18,2)) saldo_awal
from gl_balance where site_id='101' and AccountCode='102-201' group by Period order by Period
"@

Qry "B. GL 102-201 saldo AKHIR 2025 = awal2025 + jurnal2025 ; vs awal 2026" @"
select
  cast((select isnull(sum(AmountDebet-AmountCredit),0) from gl_balance where site_id='101' and AccountCode='102-201' and Period='2025-01-01') as numeric(18,2)) gl_awal_2025,
  cast((select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='102-201' and tgl>='2025-01-01' and tgl<'2026-01-01') as numeric(18,2)) gl_mutasi_2025,
  cast((select isnull(sum(AmountDebet-AmountCredit),0) from gl_balance where site_id='101' and AccountCode='102-201' and Period='2025-01-01')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='102-201' and tgl>='2025-01-01' and tgl<'2026-01-01') as numeric(18,2)) gl_akhir_2025,
  cast((select isnull(sum(AmountDebet-AmountCredit),0) from gl_balance where site_id='101' and AccountCode='102-201' and Period='2026-01-01') as numeric(18,2)) gl_awal_2026
from SYS.DUMMY
"@

Qry "C. STOK (SINV) MT: periode yg tersedia + total nilai (cari batas 2025->2026)" @"
select sv.periode, cast(sum(sv.nilai) as numeric(18,2)) stok_nilai, cast(sum(sv.qty) as numeric(18,2)) qty
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id
where pr.group_product='MT' and sv.periode>='2025-11-01' and sv.periode<='2026-02-01'
group by sv.periode order by sv.periode
"@

Qry "D. Ringkas: GL awal 2026 vs STOK awal 2026 (selisih)" @"
select
  cast((select isnull(sum(AmountDebet-AmountCredit),0) from gl_balance where site_id='101' and AccountCode='102-201' and Period='2026-01-01') as numeric(18,2)) gl_awal_2026,
  cast((select isnull(sum(sv.nilai),0) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id where pr.group_product='MT' and sv.periode='2026-01-01') as numeric(18,2)) stok_awal_2026,
  cast((select isnull(sum(AmountDebet-AmountCredit),0) from gl_balance where site_id='101' and AccountCode='102-201' and Period='2026-01-01')
     - (select isnull(sum(sv.nilai),0) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id where pr.group_product='MT' and sv.periode='2026-01-01') as numeric(18,2)) selisih
from SYS.DUMMY
"@

$cn.Close()
