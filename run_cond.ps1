param([string]$sqlfile,[string]$label)
$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sql = Get-Content $sqlfile -Raw
$nilaiExpr = "(case when q.AKHIR < 0 then 0 else (isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0)) end)"
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host ("=== KONDISI $label : per akun (SINV simulasi) ===")
Reader ("select q.PERSEDIAAN acc, cast(sum($nilaiExpr) as numeric(18,0)) sinv_sim, count(*) n from ( $sql ) q where q.PERSEDIAAN in ('102-001','102-110') group by q.PERSEDIAAN order by q.PERSEDIAAN")
Write-Host ("=== KONDISI $label : 3 unit contoh (akhir qty & nilai) ===")
Reader ("select q.PRODUK_ID, cast(q.AKHIR as numeric(18,2)) akhir_qty, cast($nilaiExpr as numeric(18,0)) nilai from ( $sql ) q where q.PRODUK_ID in ('TR.038A','TR.039A','TR.910A') order by q.PRODUK_ID")
$cn.Close()
