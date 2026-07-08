$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sqlB = Get-Content C:/BTV/debug/_dwrs_B.sql -Raw
$nilQ = "(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$mo  = "isnull(q.MUTASI_OUT_RP,0)"
$q19 = "isnull(q.MUTASI_OUT,0)"
$hAwal = "isnull((select max(hpp_avg) from sinv where stok_id=q.PRODUK_ID and periode='2026-04-01'),0)"
$moA = "abs($hAwal * $q19)"
$nilUn = "($nilQ + $mo - $moA)"
$nilCl = "(case when q.AKHIR<0 then 0 else $nilUn end)"
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=900; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== R1: KOMPOSISI komponen L (102-110) ==="
$r1 = "select cast(sum(isnull(q.AWAL_RP,0)) as numeric(18,0)) awal_rp, cast(sum(isnull(q.BELI_RP,0)) as numeric(18,0)) beli_rp_inc_eksp, cast(sum(isnull(q.EKSPEDISI_RP,0)) as numeric(18,0)) eksp_only, cast(sum(isnull(q.RET_JUAL_RP,0)) as numeric(18,0)) retjual_rp, cast(sum(isnull(q.CONSIN_RP,0)) as numeric(18,0)) consin_rp, cast(sum(isnull(q.CONSIN_BY_EVAP_RP,0)) as numeric(18,0)) consin_evap_rp, cast(sum(isnull(q.MUTASI_IN_RP,0)) as numeric(18,0)) mutin_rp, cast(sum(isnull(q.JUAL_REAL,0)) as numeric(18,0)) jual_real, cast(sum(isnull(q.JUAL_BY_EVAP_RP,0)) as numeric(18,0)) jual_evap_rp, cast(sum(isnull(q.RET_BELI_RP,0)) as numeric(18,0)) retbeli_rp, cast(sum(isnull(q.CONSOUT_RP,0)) as numeric(18,0)) consout_rp, cast(sum($moA) as numeric(18,0)) mutout_A, cast(sum($nilCl) as numeric(18,0)) total_clamped from ( $sqlB ) q where q.PERSEDIAAN='102-110'"
Reader $r1

Write-Host "=== R2: dampak CLAMP (AKHIR<0 -> 0) di L ==="
$r2 = "select cast(sum(case when q.AKHIR<0 then $nilUn else 0 end) as numeric(18,0)) discarded_by_clamp, count(case when q.AKHIR<0 then 1 else null end) n_clamped, cast(sum(case when q.AKHIR>=0 and $nilUn<0 then $nilUn else 0 end) as numeric(18,0)) neg_valued_kept, count(case when q.AKHIR>=0 and $nilUn<0 then 1 else null end) n_negval, cast(sum(case when q.AKHIR<0 and $nilUn>0 then $nilUn else 0 end) as numeric(18,0)) clamp_pos_lost, cast(sum(case when q.AKHIR<0 and $nilUn<0 then $nilUn else 0 end) as numeric(18,0)) clamp_neg_avoided from ( $sqlB ) q where q.PERSEDIAAN='102-110'"
Reader $r2

Write-Host "=== R3: top 15 unit L by nilai (desc) ==="
Reader ("select top 15 q.PRODUK_ID, cast(q.AKHIR as numeric(18,2)) akhir, cast($nilCl as numeric(18,0)) nil from ( $sqlB ) q where q.PERSEDIAAN='102-110' order by $nilCl desc")
Write-Host "=== R4: top 15 unit L nilai NEGATIF (asc), AKHIR>=0 ==="
Reader ("select top 15 q.PRODUK_ID, cast(q.AKHIR as numeric(18,2)) akhir, cast($nilUn as numeric(18,0)) nilun from ( $sqlB ) q where q.PERSEDIAAN='102-110' and q.AKHIR>=0 order by $nilUn asc")
$cn.Close()
