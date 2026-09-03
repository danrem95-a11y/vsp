$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Q([string]$sql){
  $m=$c.CreateCommand(); $m.CommandText=$sql; $m.CommandTimeout=180
  $rd=$m.ExecuteReader(); $rows=@()
  while($rd.Read()){ $row=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){ $row[$rd.GetName($i)]=$rd.GetValue($i) }; $rows+=,$row }
  $rd.Close(); return $rows
}

Write-Output "== Akun persediaan utk group L (TS.066-8344C) dan TS (TS.102-1081) =="
$r0 = Q "select kode_group, persediaan from im_product_group where kode_group in ('L','TS')"
foreach($row in $r0){ Write-Output ("  group="+$row['kode_group']+" -> persediaan="+$row['persediaan']) }

Write-Output ""
Write-Output "== SINV Jan-Aug 2026 kedua item (satu query) =="
$sql = @"
select stok_id, periode, cast(qty as numeric(14,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(16,2)) hpp_avg
  from sinv
 where stok_id in ('TS.066-8344C','TS.102-1081')
   and periode between '2026-01-01' and '2026-08-01'
 order by stok_id, periode
"@
$r1 = Q $sql
foreach($row in $r1){
  Write-Output ("  "+$row['stok_id']+" | "+$row['periode']+" | qty="+$row['qty']+" | nilai="+('{0:N2}' -f $row['nilai'])+" | hpp_avg="+('{0:N2}' -f $row['hpp_avg']))
}
$c.Close()
