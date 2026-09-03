$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
$acc='102-001'; $m0='2026-01-01'; $m1='2026-02-01'; $mend='2026-01-31'
$sql = @"
select
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='$acc' and sv.periode='$m0'),0) as numeric(20,2)) sinv_open,
  cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='$acc' and sv.periode='$m1'),0) as numeric(20,2)) sinv_close,
  cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='$acc' and g.tgl between '$m0' and '$mend'),0) as numeric(20,2)) gl_mutasi
"@
Write-Output $sql
try{
  $cmd=$c.CreateCommand(); $cmd.CommandText=$sql; $cmd.CommandTimeout=60
  $rd=$cmd.ExecuteReader()
  Write-Output ("FieldCount: "+$rd.FieldCount)
  $n=0
  while($rd.Read()){ $n++; for($i=0;$i -lt $rd.FieldCount;$i++){ Write-Output ($rd.GetName($i)+"="+$rd.GetValue($i)) } }
  Write-Output ("Rows: "+$n)
  $rd.Close()
}catch{
  Write-Output "EXCEPTION:"
  Write-Output $_.Exception.Message
  Write-Output $_.Exception.ToString()
}
$c.Close()
