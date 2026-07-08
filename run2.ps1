$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sql = Get-Content C:/BTV/debug/_dwrs_run2.sql -Raw
$arp = "(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$hppx = "(case when q.AKHIR<>0 then $arp / q.AKHIR else 0 end)"
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== CLOSING #2 (real query, netto_hpp='19' = output#1 = SINV.hpp_avg x qty) : LC.12.0012 ==="
Reader ("select q.PRODUK_ID, cast(q.AKHIR as numeric(18,2)) akhir, cast($arp as numeric(18,0)) akhir_rpxx_run2, cast($hppx as numeric(18,0)) hppx_run2, cast(q.MUTASI_OUT_RP as numeric(18,0)) mutout_rp_run2 from ( $sql ) q where q.PRODUK_ID='LC.12.0012'")
$c=$cn.CreateCommand(); $c.CommandText="select cast(hpp_avg as numeric(18,0)) hppavg_run1 from sinv where stok_id='LC.12.0012' and periode='2026-05-01'"; $o=$c.ExecuteScalar()
Write-Host ("=== Output Closing #1 (SINV.hpp_avg existing) = " + $o)
$cn.Close()
