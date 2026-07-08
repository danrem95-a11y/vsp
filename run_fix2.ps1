$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$sql=Get-Content C:/BTV/debug/_dwsgl_fix2.sql -Raw
$akhir="(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$q="select q.PERSEDIAAN acc, cast(sum($akhir) as numeric(18,2)) rp from ( $sql ) q where q.PERSEDIAAN in ('102-001','102-006','102-101','102-110') group by q.PERSEDIAAN order by q.PERSEDIAAN"
$c=$cn.CreateCommand();$c.CommandTimeout=600;$c.CommandText=$q
try{$rd=$c.ExecuteReader();while($rd.Read()){Write-Host ("  "+$rd["acc"]+" = "+$rd["rp"])};$rd.Close()}catch{Write-Host ("ERR:"+$_.Exception.Message)}
$cn.Close()
