$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

$berlubang = @"
select y.doc_reff from (
 select gj.doc_reff,
  sum(gj.kredit) gl_pay,
  isnull((select sum(t2.nilai_bayar_idr) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t2.bukti_id=gj.doc_reff and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01' and t1.flag_bayar in (1,2)),0) tbyr_pay
 from gl_journal gj where gj.posting='P' and gj.account_id='103-001' and gj.kredit>0 and gj.tgl>='2025-01-01' and gj.tgl<'2026-01-01' and isnull(gj.doc_reff,'')<>''
 group by gj.doc_reff
) y where y.gl_pay - y.tbyr_pay > 1
"@

Qry "1. Baris pembayaran GL (103-001 kredit) 2025 utk 3 faktur berlubang" @"
select left(gj.doc_reff,18) faktur, left(gj.voucher,18) voucher, cast(gj.tgl as date) tgl, gj.modul_id, cast(gj.kredit as numeric(18,2)) bayar, left(gj.ket,30) ket
from gl_journal gj where gj.posting='P' and gj.account_id='103-001' and gj.kredit>0 and gj.tgl>='2025-01-01' and gj.tgl<'2026-01-01'
  and gj.doc_reff in ($berlubang) order by gj.doc_reff, gj.tgl
"@

Qry "2. Sisi lawan (kas/bank) tiap voucher pembayaran itu" @"
select left(gj.voucher,18) voucher, gj.account_id, cast(gj.debet as numeric(18,2)) debet, cast(gj.kredit as numeric(18,2)) kredit
from gl_journal gj where gj.posting='P' and gj.voucher in (
  select voucher from gl_journal where posting='P' and account_id='103-001' and kredit>0 and tgl>='2025-01-01' and tgl<'2026-01-01' and doc_reff in ($berlubang)
) and gj.account_id<>'103-001' order by gj.voucher
"@

Qry "3. TEMPLATE TBYR1 (record 2026 CI Metro yg BENAR) - semua kolom penting" @"
select voucher, voucher_manual, cast(tgl as date) tgl, flag_bayar, flag_vendor, flag_dp, vendor_id, kas_id, curr_id, cast(kurs as numeric(18,2)) kurs, site_id, kolektor_id, left(isnull(keterangan,''),20) ket, user_id
from tbyr1 where voucher='26022004R086R'
"@
Qry "4. TEMPLATE TBYR2 (detail record itu)" @"
select voucher, urut, bukti_id, cast(nilai_bayar as numeric(18,2)) nb, cast(nilai_bayar_idr as numeric(18,2)) nb_idr, cast(nilai_asli as numeric(18,2)) nasli, cast(nilai_pot as numeric(18,2)) pot, acc_bayar, acc_pot, flag_order
from tbyr2 where voucher='26022004R086R'
"@
$cn.Close()
