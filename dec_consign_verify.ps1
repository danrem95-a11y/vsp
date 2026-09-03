$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=250; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "0. Kolom sinv (cari flag konsinyasi)" "select cname from SYS.SYSCOLUMNS where tname='sinv' order by cname"
Show "1. sinv TR.038A @2026-01-01 semua baris (flag_vendor bedakan milik vs konsinyasi?)" @"
select site_id, flag_vendor, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp from sinv where stok_id='TR.038A' and periode='2026-01-01'
"@
Show "2. sinv 102-001 @2026-01-01 SPLIT per flag_vendor (milik vs titipan)" @"
select sv.flag_vendor, count(*) n_item, cast(sum(sv.qty) as numeric(18,2)) qty, cast(sum(sv.nilai) as numeric(18,2)) nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-001' and sv.periode='2026-01-01' group by sv.flag_vendor order by sv.flag_vendor
"@
Show "3. Cons-in '88' TR.038A Desember: bukti + ke akun GL mana nilainya?" @"
select t1.bukti_id, cast(t1.tgl as date) tgl, cast(t2.qty as numeric(18,2)) qty, cast(t2.netto as numeric(18,2)) netto,
  (select list(distinct g.account_id) from gl_journal g where g.posting='P' and g.voucher=t1.bukti_id) akun_gl
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='TR.038A' and t1.tipe_trans='88' and t1.tgl>='2025-12-01' and t1.tgl<'2026-01-01' order by t1.tgl
"@
Show "4. Saldo akun Titipan 102-020 (dan cari akun titipan lain)" @"
select accountcode, cast(sum(amountdebet-amountcredit) as numeric(18,2)) saldo_awal_2026 from gl_balance where site_id='101' and period='2026-01-01' and accountcode like '102-02%' group by accountcode order by accountcode
"@
$P.Close()
