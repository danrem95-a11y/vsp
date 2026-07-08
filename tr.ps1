$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=400;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== MAT: SINV per periode 2026 (buktikan gap opening, bukan April) ==="
Qry "select s.periode, cast(sum(s.nilai) as numeric(18,2)) sinv, count(*) n from sinv s, im_produk p where s.stok_id=p.produk_id and p.group_product='MT' and s.periode in ('2026-01-01','2026-04-01','2026-05-01') group by s.periode order by s.periode"
Write-Host "   GL opening MAT 2026-01-01 = 120.790.251,61 (vs SINV 01-01 di atas)"
Write-Host ""
Write-Host "=== TR per-unit: report akhir_rpxx vs SINV(05-01), top selisih ==="
$sql=Get-Content C:/BTV/debug/_tr.sql -Raw
$akhir="(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$q="select top 15 q.PRODUK_ID, cast($akhir as numeric(18,2)) rpt, cast(isnull(sv.nilai,0) as numeric(18,2)) sinv, cast($akhir - isnull(sv.nilai,0) as numeric(18,2)) selisih from ( $sql ) q left outer join sinv sv on (sv.stok_id=q.PRODUK_ID and sv.periode='2026-05-01') order by abs($akhir - isnull(sv.nilai,0)) desc"
Qry $q
$cn.Close()
