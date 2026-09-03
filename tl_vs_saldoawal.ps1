$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. TL.203.0504 masuk akun apa? (koreksi TL menyentuh akun ini)" @"
select produk_id, group_product, (select persediaan from im_product_group where kode_group=im_produk.group_product) akun from im_produk where produk_id='TL.203.0504'
"@

Show "2. 102-102 (Spare Parts TL, tempat koreksi TL) - gap April: SUDAH BERES?" @"
select cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-102')
          + (select sum(debet-kredit) from gl_journal where posting='P' and account_id='102-102' and tgl>='2026-01-01' and tgl<'2026-05-01') as numeric(18,2)) ledger,
       cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-102' and sv.periode='2026-05-01') as numeric(18,2)) stok
from SYS.DUMMY
"@

Show "3. Apakah 102-001 (yg 10,1 M) memuat produk TL? (harusnya TIDAK - isinya TR reefer)" @"
select count(*) n_produk_TL from im_produk pr join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-001' and pr.produk_id like 'TL.%'
"@

Show "4. Selisih 102-001 ada di SALDO AWAL (2026-01-01) - sebelum transaksi Jan apa pun" @"
select cast((select sum(amountdebet-amountcredit) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001') as numeric(18,2)) gl_saldoawal,
       cast((select sum(sv.nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-001' and sv.periode='2026-01-01') as numeric(18,2)) sinv_saldoawal
from SYS.DUMMY
"@
$P.Close()
