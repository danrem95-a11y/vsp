$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sqlC = Get-Content C:/BTV/debug/_dwrs_C.sql -Raw
$nilaiExpr = "(case when q.AKHIR < 0 then 0 else (isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0)) end)"
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== KONDISI C (B + fix '19' avg-awal) : SINV per akun vs GL ==="
Reader ("select q.PERSEDIAAN acc, cast(sum($nilaiExpr) as numeric(18,0)) sinv_C from ( $sqlC ) q where q.PERSEDIAAN in ('102-001','102-110') group by q.PERSEDIAAN order by q.PERSEDIAAN")
Write-Host "=== C : LC.12.0012 & LF.05.0002 ==="
Reader ("select q.PRODUK_ID, cast(q.AKHIR as numeric(18,2)) akhir, cast($nilaiExpr as numeric(18,0)) nilai from ( $sqlC ) q where q.PRODUK_ID in ('LC.12.0012','LF.05.0002') order by q.PRODUK_ID")
$cn.Close()
