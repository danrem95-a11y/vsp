$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sqlB = Get-Content C:/BTV/debug/_dwrs_B.sql -Raw   # JUAL sudah di-fix
# nilai base akhir_rpxx (dgn mutasi_out query) :
$nilQ = "(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$mo  = "isnull(q.MUTASI_OUT_RP,0)"           # mutasi_out_rp versi query (korup)
$q19 = "isnull(q.MUTASI_OUT,0)"              # qty '19'
$infRp = "(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.MUTASI_IN_RP,0))"
$infQ  = "(isnull(q.AWAL,0)+isnull(q.BELI,0)+isnull(q.CONSIN,0)+isnull(q.CONSIN_BY_EVAP,0)+isnull(q.RET_JUAL,0)+isnull(q.MUTASI_IN,0))"
$hrgB  = "(case when $infQ<>0 then $infRp/$infQ else 0 end)"
$hAwal = "isnull((select max(hpp_avg) from sinv where stok_id=q.PRODUK_ID and periode='2026-04-01'),0)"
$moA = "abs($hAwal * $q19)"
$moB = "abs($hrgB * $q19)"
$nilA = "(case when q.AKHIR<0 then 0 else ($nilQ + $mo - $moA) end)"
$nilB = "(case when q.AKHIR<0 then 0 else ($nilQ + $mo - $moB) end)"
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== A (awal) vs B (avg periode berjalan) per akun ==="
Reader ("select q.PERSEDIAAN acc, cast(sum($nilA) as numeric(18,0)) simA, cast(sum($nilB) as numeric(18,0)) simB from ( $sqlB ) q where q.PERSEDIAAN in ('102-101','102-102','102-110') group by q.PERSEDIAAN order by q.PERSEDIAAN")
$cn.Close()
