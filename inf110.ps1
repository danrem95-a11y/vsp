$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
$q1 = @"
select top 12 s.stok_id, cast(a.qty as numeric(18,2)) q_mar, cast(a.nilai as numeric(18,0)) n_mar, cast(s.qty as numeric(18,2)) q_apr, cast(s.hpp_avg as numeric(18,2)) hpp_apr, cast(s.nilai as numeric(18,0)) n_apr
from sinv s join im_produk p on p.produk_id=s.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product left join sinv a on a.stok_id=s.stok_id and a.periode='2026-04-01'
where gr.PERSEDIAAN='102-110' and s.periode='2026-05-01' order by s.nilai desc
"@
Write-Host "=== 102-110: 12 produk nilai TERTINGGI (cari inflasi) ==="
Reader $q1
$q2 = @"
select b.stok_id, count(*) n, cast(sum(b.qty) as numeric(18,2)) qty, cast(sum(b.netto_hpp) as numeric(18,0)) netto_hpp
from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id join im_produk p on p.produk_id=b.stok_id join IM_PRODUCT_GROUP gr on gr.KODE_GROUP=p.group_product and gr.PERSEDIAAN='102-110'
where a.tipe_trans='19' and a.tgl between '2026-04-01' and '2026-04-30' group by b.stok_id order by abs(sum(b.netto_hpp)) desc
"@
Write-Host "`n=== 102-110: produk dgn transaksi '19' April ==="
Reader $q2
$cn.Close()
