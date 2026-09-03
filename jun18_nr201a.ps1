$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Master NR.201A (grup, evap?) ==="
Reader "select produk_id, produk_desc, group_product from im_produk where produk_id='NR.201A'"

Write-Host "`n=== SEMUA gerakan JUAL/KONSINYASI NR.201A (tsales) Apr-Jul ==="
Reader @"
select s1.tgl, s1.tipe_trans, s1.bukti_id, s1.order_client, cast(s2.qty as numeric(18,2)) qty,
       cast(isnull(s2.hpp,0) as numeric(18,2)) hpp, isnull(s2.evap,'') evap
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s2.stok_id='NR.201A' and s1.tgl>='2026-04-01' and s1.tgl<'2026-08-01'
order by s1.tgl, s1.tipe_trans
"@

Write-Host "`n=== SEMUA gerakan STOK NR.201A (tstok: beli/consin/mutasi) Apr-Jul ==="
Reader @"
select t1.tgl, t1.tipe_trans, t1.bukti_id, t1.order_client, cast(t2.qty as numeric(18,2)) qty,
       cast(isnull(t2.netto,0) as numeric(18,2)) netto, cast(isnull(t2.hpp,0) as numeric(18,2)) hpp
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='NR.201A' and t1.tgl>='2026-04-01' and t1.tgl<'2026-08-01'
order by t1.tgl, t1.tipe_trans
"@

Write-Host "`n=== SINV NR.201A semua periode 2026 ==="
Reader "select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp_avg from sinv where stok_id='NR.201A' and periode>='2026-01-01' order by periode"

$cn.Close()
