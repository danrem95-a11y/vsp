$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== GL consin (AS debit) senilai 27.275.970,15 (Juni, 102-001) ==="
Reader @"
select voucher, doc_reff, tgl, cast(debet as numeric(18,2)) debet, left(ket,45) ket
from gl_journal where account_id='102-001' and modul_id='AS' and posting='P'
  and abs(debet-27275970.15)<1 and tgl>='2026-06-01' and tgl<'2026-07-01'
order by tgl, voucher
"@

Write-Host "`n=== STOK consin (tstok88 TR) senilai 27.275.970,15 (Juni) ==="
Reader @"
select t1.bukti_id, t1.order_client, t1.tgl, t2.stok_id, cast(t2.netto as numeric(18,2)) netto, t2.qty, t2.no_seri
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id
where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y'
  and abs(t2.netto-27275970.15)<1 and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01'
order by t1.tgl, t1.bukti_id
"@

Write-Host "`n=== Bandingkan doc_reff GL vs order_client stok (nilai 27,3jt) ==="
Write-Host "-- GL doc_reff list --"
Reader @"
select distinct doc_reff from gl_journal where account_id='102-001' and modul_id='AS' and posting='P'
  and abs(debet-27275970.15)<1 and tgl>='2026-06-01' and tgl<'2026-07-01' order by doc_reff
"@
Write-Host "-- stok order_client list --"
Reader @"
select distinct t1.order_client from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id
where pr.group_product='TR' and t1.tipe_trans='88' and t1.order_oke='Y'
  and abs(t2.netto-27275970.15)<1 and t1.tgl>='2026-06-01' and t1.tgl<'2026-07-01' order by t1.order_client
"@

$cn.Close()
