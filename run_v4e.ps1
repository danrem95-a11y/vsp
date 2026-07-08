$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== V4e1: jejak SINV.hpp_avg per periode utk 2 unit korup ==="
Reader "select stok_id, periode, cast(hpp_avg as numeric(18,2)) hpp_avg, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai from SINV where stok_id in('LC.12.0012','LF.05.0002') order by stok_id, periode"

Write-Host "=== V4e2: riwayat PEMBELIAN ('02') 2 unit korup (hrg per unit, bebas closing) ==="
Reader "select t2.stok_id, min(t1.tgl) tgl_awal, max(t1.tgl) tgl_akhir, count(*) n, cast(sum(abs(t2.qty)) as numeric(18,2)) qty, cast(sum(abs(t2.netto)) as numeric(18,2)) netto, cast(avg(t2.hrg) as numeric(18,2)) avg_hrg from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and t2.stok_id in('LC.12.0012','LF.05.0002') group by t2.stok_id"

Write-Host "=== V4e3: nilai '19' RECOVERY 102-110 pakai 75 bersih apa adanya + 2 korup diganti hpp_avg awal ==="
Reader "select cast(sum(case when t2.stok_id in('LC.12.0012','LF.05.0002') then abs(isnull(sv.hpp_avg,0)*t2.qty) else abs(t2.netto_hpp) end) as numeric(18,2)) mutout_mix from TSTOK1 t1, TSTOK2 t2, IM_PRODUK p, IM_PRODUCT_GROUP g, (select stok_id, max(hpp_avg) hpp_avg from SINV where periode='2026-04-01' group by stok_id) sv where t1.bukti_id=t2.bukti_id and t2.stok_id=p.produk_id and p.group_product=g.kode_group and g.persediaan='102-110' and sv.stok_id=t2.stok_id and t1.tgl between '2026-04-01' and '2026-04-30' and t1.order_oke='Y' and t1.tipe_trans='19'"
$cn.Close()
