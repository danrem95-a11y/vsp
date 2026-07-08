$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
foreach($t in @('TSALES1','TSALES2','TSTOK1','TSTOK2','IM_PRODUK')){
  Write-Host ("=== index "+$t+" ===")
  $dt=$cn.GetSchema("Indexes",@($null,$null,$t))
  $seen=@{}
  foreach($r in $dt.Rows){ $k=$r["INDEX_NAME"]; if(-not $seen.ContainsKey($k)){$seen[$k]=@()}; $seen[$k]+=$r["COLUMN_NAME"] }
  foreach($k in $seen.Keys){ Write-Host ("  "+$k+" : "+($seen[$k] -join ",")) }
}
function Cnt($s){ $c=$cn.CreateCommand();$c.CommandText=$s;$v=$c.ExecuteScalar();Write-Host ("  "+$s+" = "+$v) }
Write-Host "=== volume ==="
Cnt "select count(*) from tsales2"
Cnt "select count(*) from tstok2"
Cnt "select count(*) from tsales2 t2, tsales1 t1 where t1.bukti_id=t2.bukti_id and t1.tgl between '2026-04-01' and '2026-04-30'"
$cn.Close()
