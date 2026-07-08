$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== group(s) dgn PERSEDIAAN=102-110 ==="
Reader "select KODE_GROUP, NAMA_GROUP from IM_PRODUCT_GROUP where PERSEDIAAN='102-110'"
Write-Host "`n=== 102-110: produk dgn nilai negatif / qty minus / hpp<=0 (SINV 05/01) ==="
Reader @"
select top 15 s.stok_id, cast(s.qty as numeric(18,2)) qty, cast(s.hpp_avg as numeric(18,2)) hpp, cast(s.nilai as numeric(18,0)) nilai
from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product
where gr.PERSEDIAAN='102-110' and s.periode='2026-05-01' and (s.nilai<0 or s.qty<0 or (s.qty>0 and s.hpp_avg<=0))
order by s.nilai
"@
Write-Host "`n=== 102-110: Mar vs Apr total + jumlah neg ==="
Reader @"
select periode, cast(sum(nilai) as numeric(18,0)) nilai, sum(case when nilai<0 then 1 else 0 end) neg_nilai, sum(case when qty<0 then 1 else 0 end) neg_qty
from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product
where gr.PERSEDIAAN='102-110' and periode in ('2026-04-01','2026-05-01') group by periode order by periode
"@
$cn.Close()
