$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=250; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. gl_balance 102-001: opening 2025 vs opening 2026 (dan cek konsisten dgn gl_journal 2025)" @"
select cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2025-01-01' and accountcode='102-001') as numeric(18,2)) gl_awal_2025,
       cast((select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-001' and tgl>='2025-01-01' and tgl<'2026-01-01') as numeric(18,2)) gl_gerak_2025,
       cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2025-01-01' and accountcode='102-001')
          + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-001' and tgl>='2025-01-01' and tgl<'2026-01-01') as numeric(18,2)) gl_akhir_2025_hitung,
       cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001') as numeric(18,2)) gl_awal_2026_tersimpan
from SYS.DUMMY
"@

Show "2. sinv 102-001 (stok) per akhir bulan 2025 - ada periodenya?" @"
select periode, cast(sum(sv.nilai) as numeric(18,2)) stok, cast(sum(sv.qty) as numeric(18,2)) qty
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and sv.periode>='2025-01-01' and sv.periode<='2026-01-01'
group by periode order by periode
"@

Show "3. GAP stok vs GL 102-001 per akhir bulan 2025 (cari kapan berpisah)" @"
select sp.periode,
 cast(sp.stok as numeric(18,2)) stok,
 cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2025-01-01' and accountcode='102-001')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-001' and tgl>='2025-01-01' and tgl<sp.periode) as numeric(18,2)) ledger,
 cast(sp.stok - ((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2025-01-01' and accountcode='102-001')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-001' and tgl>='2025-01-01' and tgl<sp.periode)) as numeric(18,2)) gap
from (select periode, sum(sv.nilai) stok from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
      where gr.persediaan='102-001' and sv.periode>='2025-02-01' and sv.periode<='2026-01-01' group by periode) sp order by sp.periode
"@
$P.Close()
