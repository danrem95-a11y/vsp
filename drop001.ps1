$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== 102-001: produk dgn penurunan nilai Mar->Apr terbesar (q_apr, hpp_apr) ==="
Reader @"
select top 15 m.stok_id, cast(a.qty as numeric(18,2)) q_mar, cast(a.nilai as numeric(18,0)) n_mar,
   cast(m.qty as numeric(18,2)) q_apr, cast(m.hpp_avg as numeric(18,2)) h_apr, cast(m.nilai as numeric(18,0)) n_apr,
   cast(a.nilai-m.nilai as numeric(18,0)) turun
from sinv m join im_produk p on p.produk_id=m.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product
   join sinv a on a.stok_id=m.stok_id and a.periode='2026-04-01'
where gr.PERSEDIAAN='102-001' and m.periode='2026-05-01'
order by (a.nilai-m.nilai) desc
"@
Write-Host "`n=== unit EVAP TR.038A/039A/040A/910A skrg (di-nol al_minus?) ==="
Reader "select stok_id, cast(qty as numeric(18,2)) qty, cast(hpp_avg as numeric(18,2)) hpp, cast(nilai as numeric(18,0)) nilai from sinv where periode='2026-05-01' and stok_id in ('TR.038A','TR.039A','TR.040A','TR.910A','TR.1007A','TR.1002A','TR.1004A')"
$cn.Close()
