$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== CONSIN per voucher: GL AS-debit vs tstok88 netto (TR, Juni), beda>1 ==="
Reader @"
select isnull(g.voucher,t.bukti_id) v,
   cast(isnull(g.gl_deb,0) as numeric(18,2)) gl_deb,
   cast(isnull(t.stok_netto,0) as numeric(18,2)) stok_netto,
   cast(isnull(t.stok_nettohpp,0) as numeric(18,2)) stok_nettohpp,
   cast(isnull(g.gl_deb,0)-isnull(t.stok_netto,0) as numeric(18,2)) diff
from
 (select voucher, sum(debet) gl_deb from gl_journal
    where posting='P' and account_id='102-001' and modul_id='AS' and debet>0
      and tgl>='2026-06-01' and tgl<'2026-07-01' group by voucher) g
 full outer join
 (select t1.bukti_id, sum(t2.netto) stok_netto, sum(t2.netto_hpp) stok_nettohpp
    from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id
    where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y'
      and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' group by t1.bukti_id) t
 on g.voucher=t.bukti_id
where abs(isnull(g.gl_deb,0)-isnull(t.stok_netto,0)) > 1
order by abs(isnull(g.gl_deb,0)-isnull(t.stok_netto,0)) desc
"@

Write-Host "`n=== Total cek: GL AS-deb consin vs tstok88 netto (TR Juni) ==="
Reader @"
select
 (select cast(sum(debet) as numeric(18,2)) from gl_journal where posting='P' and account_id='102-001' and modul_id='AS' and debet>0 and tgl>='2026-06-01' and tgl<'2026-07-01') gl_consin_deb,
 (select cast(sum(t2.netto) as numeric(18,2)) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y' and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01') stok_consin_netto
"@

$cn.Close()
