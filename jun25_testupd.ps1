$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== Simulasi update set-based: sale hpp=0 EVAP Juni -> nilai yg AKAN di-set (dari consin) ==="
Reader @"
select sl.bukti_id sale_bukti, sl.stok_id, sl.evap,
  cast(isnull(sl.hpp,0) as numeric(18,2)) sale_hpp_now,
  cast(isnull((select max(t2.hpp) from tstok2 t2
     where t2.bukti_id='102'+substr(sl.bukti_id,4) and t2.stok_id=sl.stok_id
       and isnull(t2.coa_id,'')=isnull(sl.evap,'') and isnull(t2.produk_id,'')=isnull(sl.cond,'')),0) as numeric(18,2)) would_set
from tsales1 s1 join tsales2 sl on s1.bukti_id=sl.bukti_id
where s1.tipe_trans in ('22','88') and s1.order_oke='Y' and isnull(sl.hpp,0)=0 and isnull(sl.evap,'')<>''
  and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01'
order by sl.stok_id
"@
$cn.Close()
