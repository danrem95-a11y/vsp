$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
# komponen per stok (group TR / akun 102-001), lalu AKHIR_B & nilai_B (al_minus: <0 -> 0), cost = awal_rp/awal
$base = @"
from (select p.produk_id sid, isnull(aw.awal,0) awal, isnull(aw.awal_rp,0) awal_rp,
    isnull(jb.q,0) jual_all, isnull(jne.q,0) jual_nonevap, isnull(je.q,0) jbe, isnull(co.q,0) consout, isnull(ci.q,0) consin
  from im_produk p
  join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product and gr.PERSEDIAAN='102-001'
  left join (select stok_id, sum(qty) awal, sum(nilai) awal_rp from sinv where periode='2026-04-01' group by stok_id) aw on aw.stok_id=p.produk_id
  left join (select B.STOK_ID sid, sum(B.QTY) q from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='22' and A.TGL between '2026-04-01' and '2026-04-30' and isnull(B.qty,0)<>0 and A.ORDER_OKE='Y' and B.STOK_ID+isnull(B.EVAP,'') not in (select B2.STOK_ID+isnull(B2.EVAP,'') from TSALES1 A2,TSALES2 B2 where A2.BUKTI_ID=B2.BUKTI_ID and A2.TIPE_TRANS='88' and A2.TGL<'2026-04-01') group by B.STOK_ID) jb on jb.sid=p.produk_id
  left join (select B.STOK_ID sid, sum(B.QTY) q from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='22' and isnull(B.EVAP,'')='' and A.TGL between '2026-04-01' and '2026-04-30' and isnull(B.qty,0)<>0 and A.ORDER_OKE='Y' and B.STOK_ID+isnull(B.EVAP,'') not in (select B2.STOK_ID+isnull(B2.EVAP,'') from TSALES1 A2,TSALES2 B2 where A2.BUKTI_ID=B2.BUKTI_ID and A2.TIPE_TRANS='88' and A2.TGL<'2026-04-01') group by B.STOK_ID) jne on jne.sid=p.produk_id
  left join (select B.STOK_ID sid, sum(B.QTY) q from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='22' and isnull(B.EVAP,'')<>'' and isnull(B.QTY,0)<>0 and A.TGL between '2026-04-01' and '2026-04-30' group by B.STOK_ID) je on je.sid=p.produk_id
  left join (select B.STOK_ID sid, sum(B.QTY) q from TSALES1 A,TSALES2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='88' and A.TGL between '2026-04-01' and '2026-04-30' group by B.STOK_ID) co on co.sid=p.produk_id
  left join (select B.STOK_ID sid, sum(B.QTY) q from TSTOK1 A,TSTOK2 B where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='88' and A.TGL between '2026-04-01' and '2026-04-30' group by B.STOK_ID) ci on ci.sid=p.produk_id
) x
"@
Write-Host "=== 3 unit contoh: AKHIR & nilai existing vs fix ==="
Reader ("select sid, cast(awal as numeric(18,2)) qawal, cast(awal-jual_all-jbe-consout+consin as numeric(18,2)) akhir_A, cast(awal-jual_nonevap-jbe-consout+consin as numeric(18,2)) akhir_B, cast(case when awal>0 then awal_rp/awal else 0 end as numeric(18,0)) unitcost " + $base + " where sid in ('TR.038A','TR.039A','TR.910A','TR.1007A','TR.040A') order by sid")
Write-Host "`n=== TOTAL 102-001: nilai existing (SINV skrg) vs nilai_B simulasi vs GL ==="
Reader ("select cast(sum(case when (awal-jual_nonevap-jbe-consout+consin)>0 then (awal-jual_nonevap-jbe-consout+consin)*(case when awal>0 then awal_rp/awal else 0 end) else 0 end) as numeric(18,0)) nilai_B_sim " + $base)
Reader "select cast(sum(nilai) as numeric(18,0)) sinv_existing from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product where gr.PERSEDIAAN='102-001' and s.periode='2026-05-01'"
Write-Host "  GL 102-001 end-Apr = 7.528.916.452"
$cn.Close()
