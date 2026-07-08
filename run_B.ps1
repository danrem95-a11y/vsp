$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sqlB = Get-Content C:/BTV/debug/_dwrs_B.sql -Raw
$nilaiExpr = "(case when q.AKHIR < 0 then 0 else (isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0)) end)"
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== KONDISI B (fix JUAL EVAP='') : SINV simulasi per akun ==="
Reader ("select q.PERSEDIAAN acc, cast(sum($nilaiExpr) as numeric(18,0)) sinv_B from ( $sqlB ) q where q.PERSEDIAAN in ('102-001','102-110') group by q.PERSEDIAAN order by q.PERSEDIAAN")
Write-Host "=== KONDISI B : 5 unit contoh (akhir qty & nilai) ==="
Reader ("select q.PRODUK_ID, cast(q.AKHIR as numeric(18,2)) akhir_B, cast($nilaiExpr as numeric(18,0)) nilai_B from ( $sqlB ) q where q.PRODUK_ID in ('TR.038A','TR.039A','TR.910A','TR.040A','TR.1007A') order by q.PRODUK_ID")
Write-Host "`n=== GL per akun (end-Apr) ==="
Reader "select o.acc, cast(o.opening+isnull(m.mv,0) as numeric(18,0)) gl from (select AccountCode acc, sum(AmountDebet-AmountCredit) opening from gl_balance where Period='2026-01-01' and AccountCode in ('102-001','102-110') group by AccountCode) o left join (select account_id acc, sum(debet-kredit) mv from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-04-30' and account_id in ('102-001','102-110') group by account_id) m on m.acc=o.acc order by o.acc"
$cn.Close()
