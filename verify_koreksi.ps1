$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. KOREKSI masuk? (baris TL.203.0504 hrs qty=20000 hrg=430; TL.078-1882 tetap 6)" @"
select stok_id, cast(qty as numeric(18,2)) qty, cast(qty1 as numeric(18,2)) qty1, cast(hrg as numeric(18,4)) hrg, cast(netto as numeric(18,2)) netto
from tstok2 where bukti_id='10126010200006' order by stok_id
"@

Show "2. sinv TL.203.0504 2026 (hpp_avg masih NEGATIF=belum re-close; ~430 positif=sudah)" @"
select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,4)) hpp_avg
from sinv where stok_id='TL.203.0504' and periode>='2026-01-01' order by periode
"@

Show "3. Gap 102-102 Juni: Ledger vs Stok (105.161,32 = belum beres; ~0 = beres)" @"
select
 cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')
    + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-07-01') as numeric(18,2)) ledger_akhir_jun,
 cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-07-01') as numeric(18,2)) stok_akhir_jun
from SYS.DUMMY
"@
$P.Close()
