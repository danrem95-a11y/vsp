$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$sql = Get-Content C:/BTV/debug/_dwsgl.sql -Raw
$akhir = "(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$q = "select q.PERSEDIAAN acc, cast(sum($akhir) as numeric(18,2)) saldo_akhir_rp, count(*) n from ( $sql ) q group by q.PERSEDIAAN order by q.PERSEDIAAN"
$c=$cn.CreateCommand();$c.CommandTimeout=600;$c.CommandText=$q
$sw=[Diagnostics.Stopwatch]::StartNew()
try{$rd=$c.ExecuteReader()
  Write-Host ("retrieve ok "+$sw.ElapsedMilliseconds+" ms")
  while($rd.Read()){ Write-Host ("  "+$rd["acc"]+" | "+$rd["saldo_akhir_rp"]+" | n="+$rd["n"]) }
  $rd.Close()
}catch{Write-Host ("ERR "+$sw.ElapsedMilliseconds+"ms: "+$_.Exception.Message)}
$cn.Close()
