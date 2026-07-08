$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== TR.1002 & TR.1003: SINV 04/01 vs 05/01 (nilai hilang di April?) ==="
Reader "select s.stok_id, s.periode, cast(s.qty as numeric(18,2)) qty, cast(s.hpp_avg as numeric(18,2)) hpp, cast(s.nilai as numeric(18,0)) nilai from sinv s where s.stok_id in ('TR.1002','TR.1003','TR.1004') and s.periode in ('2026-04-01','2026-05-01') order by s.stok_id, s.periode"
Write-Host "`n=== 102-001 (TR): TOTAL Mar vs Apr + jumlah produk hpp=0 (qty>0) ==="
Reader @"
select periode, cast(sum(nilai) as numeric(18,0)) nilai, sum(case when qty>0 and isnull(hpp_avg,0)=0 then 1 else 0 end) produk_hpp0, cast(sum(case when qty>0 and isnull(hpp_avg,0)=0 then 0 else 0 end) as numeric(18,0)) x
from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product
where gr.PERSEDIAAN='102-001' and periode in ('2026-04-01','2026-05-01') group by periode order by periode
"@
Write-Host "`n=== TR.1002 di tstok April (transaksi apa yg mengubah nilainya) ==="
Reader "select a.tipe_trans, count(*) n, cast(sum(b.qty) as numeric(18,2)) qty, cast(sum(b.netto_hpp) as numeric(18,0)) netto_hpp, cast(max(b.hpp) as numeric(18,0)) maxhpp from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where b.stok_id='TR.1002' and a.tgl between '2026-04-01' and '2026-04-30' group by a.tipe_trans"
$cn.Close()
