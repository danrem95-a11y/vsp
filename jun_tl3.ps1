$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. STOK-side: nilai tstok2 per tipe (TL/TSA, Jun) vs GL PO/AS" @"
select t1.tipe_trans, count(*) n, cast(sum(t2.netto) as numeric(18,2)) netto
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
 join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-102' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01'
group by t1.tipe_trans order by t1.tipe_trans
"@

Qry "B. STOK-side: COGS tsales (hpp*qty) per tipe (TL/TSA, Jun) vs GL HP 14.960.954,19" @"
select s1.tipe_trans, count(*) n, cast(sum(isnull(s2.hpp,0)*s2.qty) as numeric(18,2)) cogs
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
 join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-102' and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01'
group by s1.tipe_trans order by s1.tipe_trans
"@

Qry "C. GL 102-102 Juni: voucher AS (adjustment) detail" @"
select voucher, cast(sum(debet) as numeric(18,2)) db, cast(sum(kredit) as numeric(18,2)) kr, left(max(ket),40) ket
from gl_journal where posting='P' and account_id='102-102' and modul_id='AS' and tgl>='2026-06-01' and tgl<'2026-07-01'
group by voucher order by voucher
"@
$cn.Close()
