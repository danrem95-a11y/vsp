$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

foreach($sku in @('LC.12.0012','LF.05.0002')){
  Write-Host ("############ SKU="+$sku+" ############")
  Write-Host "=== TSTOK transaksi Jan-Jun 2026 (tipe,tgl,qty,hrg,netto,netto_hpp) ==="
  $q="select t1.tipe_trans, t1.tgl, t1.bukti_id, cast(t2.qty as numeric(18,2)) qty, cast(t2.hrg as numeric(18,2)) hrg, cast(t2.netto as numeric(18,2)) netto, cast(t2.netto_hpp as numeric(18,2)) netto_hpp, cast(t2.hpp as numeric(18,2)) hpp from TSTOK1 t1, TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.stok_id='"+$sku+"' and t1.tgl between '2026-01-01' and '2026-06-30' order by t1.tgl, t1.bukti_id"
  Reader $q
  Write-Host "=== TSALES transaksi Jan-Jun 2026 (tipe,tgl,qty,hpp,netto) ==="
  $q2="select s1.tipe_trans, s1.tgl, s1.bukti_id, cast(s2.qty as numeric(18,2)) qty, cast(s2.hpp as numeric(18,2)) hpp, cast(s2.netto as numeric(18,2)) netto, isnull(s2.evap,'') evap from TSALES1 s1, TSALES2 s2 where s1.bukti_id=s2.bukti_id and s2.stok_id='"+$sku+"' and s1.tgl between '2026-01-01' and '2026-06-30' order by s1.tgl, s1.bukti_id"
  Reader $q2
  Write-Host "=== SINV per periode 2026 (qty,nilai,hpp_avg) ==="
  Reader ("select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp_avg from SINV where stok_id='"+$sku+"' and periode between '2026-01-01' and '2026-07-01' order by periode")
}
$cn.Close()
