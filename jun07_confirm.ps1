$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== CONSIN GL vs STOK join BENAR (doc_reff=order_client), TR Juni, beda>1 ==="
Reader @"
select isnull(g.dr,t.oc) ref, cast(isnull(g.gl,0) as numeric(18,2)) gl_deb, cast(isnull(t.st,0) as numeric(18,2)) stok_netto,
   cast(isnull(g.gl,0)-isnull(t.st,0) as numeric(18,2)) diff
from
 (select doc_reff dr, sum(debet) gl from gl_journal
    where posting='P' and account_id='102-001' and modul_id='AS' and debet>0 and tgl>='2026-06-01' and tgl<'2026-07-01'
    group by doc_reff) g
 full outer join
 (select t1.order_client oc, sum(t2.netto) st
    from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id
    where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01'
    group by t1.order_client) t
 on g.dr=t.oc
where abs(isnull(g.gl,0)-isnull(t.st,0))>1
order by abs(isnull(g.gl,0)-isnull(t.st,0)) desc
"@

Write-Host "`n=== Nama akun 102-001 & 102-020 ==="
Reader "select accountcode, accountname from gl_acc where accountcode in ('102-001','102-020')"

Write-Host "`n=== Histori TR.910A: consout(tsales88) & consin(tstok88) Jun-Jul ==="
Write-Host "-- consout tsales88 --"
Reader @"
select s1.bukti_id, s1.order_client, s1.tgl, cast(s2.qty as numeric(18,2)) qty, cast(s2.hpp as numeric(18,2)) hpp
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s2.stok_id='TR.910A' and s1.tipe_trans='88' and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01' order by s1.tgl
"@
Write-Host "-- consin tstok88 --"
Reader @"
select t1.bukti_id, t1.order_client, t1.tgl, cast(t2.qty as numeric(18,2)) qty, cast(t2.netto as numeric(18,2)) netto
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='TR.910A' and t1.tipe_trans='88' and t1.tgl>='2026-06-01' and t1.tgl<'2026-08-01' order by t1.tgl
"@

Write-Host "`n=== 102-201 (MT) opening: SINV 01/01 vs GL_balance opening (buktikan beda saldo awal) ==="
Reader @"
select 'stok_sinv_0101' k, cast(sum(sv.nilai) as numeric(18,2)) v
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan='102-201' and sv.periode='2026-01-01'
union all
select 'gl_opening_0101', cast(sum(amountdebet-amountcredit) as numeric(18,2)) from gl_balance
where site_id='101' and period='2026-01-01' and accountcode='102-201'
"@

$cn.Close()
