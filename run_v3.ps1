$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== V3: '19' & '09' di akun 102-110, April : NETTO vs NETTO_HPP vs qty ==="
$q="select t1.tipe_trans, cast(sum(abs(t2.netto)) as numeric(18,2)) sum_netto, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) sum_netto_hpp, cast(sum(abs(t2.qty)) as numeric(18,2)) sum_qty, count(*) n from TSTOK1 t1, TSTOK2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110' and t1.tgl between '2026-04-01' and '2026-04-30' and t1.order_oke='Y' and t1.tipe_trans in('19','09') group by t1.tipe_trans order by t1.tipe_trans"
Reader $q
Write-Host "=== V3b: cross-check mutout_A simulasi (hpp_avg 2026-04-01 x qty19) di 102-110 ==="
$q2="select cast(sum(abs(isnull(sv.hpp_avg,0)*t2.qty)) as numeric(18,2)) mutout_hppavg_awal from TSTOK1 t1, TSTOK2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g, (select stok_id, max(hpp_avg) hpp_avg from SINV where periode='2026-04-01' group by stok_id) sv where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110' and sv.stok_id=t2.stok_id and t1.tgl between '2026-04-01' and '2026-04-30' and t1.order_oke='Y' and t1.tipe_trans='19'"
Reader $q2
$cn.Close()
