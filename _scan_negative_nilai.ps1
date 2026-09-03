$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Q([string]$sql){
  $m=$c.CreateCommand(); $m.CommandText=$sql; $m.CommandTimeout=180
  $rd=$m.ExecuteReader(); $rows=@()
  while($rd.Read()){ $row=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){ $row[$rd.GetName($i)]=$rd.GetValue($i) }; $rows+=,$row }
  $rd.Close(); return $rows
}

Write-Output "== Scan SINV Jan-Jul 2026: item dgn nilai negatif ATAU hpp_avg negatif (indikasi residu/corruption) =="
$sql = @"
select sv.stok_id, gr.persediaan, sv.periode, cast(sv.qty as numeric(14,2)) qty, cast(sv.nilai as numeric(18,2)) nilai, cast(sv.hpp_avg as numeric(16,2)) hpp_avg
  from sinv sv
  join im_produk pr on pr.produk_id=sv.stok_id
  join im_product_group gr on gr.kode_group=pr.group_product
 where sv.periode between '2026-01-01' and '2026-08-01'
   and (sv.nilai<0 or sv.hpp_avg<0)
 order by sv.nilai asc
"@
$r = Q $sql
if($r.Count -eq 0){ Write-Output "  (0 baris - TIDAK ADA nilai/hpp_avg negatif di seluruh persediaan Jan-Jul 2026)" }
foreach($row in $r){
  Write-Output ("  "+$row['stok_id']+" | "+$row['persediaan']+" | "+$row['periode']+" | qty="+$row['qty']+" | nilai="+('{0:N2}' -f $row['nilai'])+" | hpp_avg="+('{0:N2}' -f $row['hpp_avg']))
}

Write-Output ""
Write-Output "== Scan item dgn |nilai| tak wajar besar per-unit (hpp_avg > 50.000.000, kandidat residu compounding) =="
$sql2 = @"
select sv.stok_id, gr.persediaan, sv.periode, cast(sv.qty as numeric(14,2)) qty, cast(sv.nilai as numeric(18,2)) nilai, cast(sv.hpp_avg as numeric(16,2)) hpp_avg
  from sinv sv
  join im_produk pr on pr.produk_id=sv.stok_id
  join im_product_group gr on gr.kode_group=pr.group_product
 where sv.periode between '2026-01-01' and '2026-08-01'
   and sv.qty<>0 and abs(sv.hpp_avg) > 50000000
 order by abs(sv.hpp_avg) desc
"@
$r2 = Q $sql2
if($r2.Count -eq 0){ Write-Output "  (0 baris - tidak ada HPP per-unit tak wajar)" }
foreach($row in $r2){
  Write-Output ("  "+$row['stok_id']+" | "+$row['persediaan']+" | "+$row['periode']+" | qty="+$row['qty']+" | nilai="+('{0:N2}' -f $row['nilai'])+" | hpp_avg="+('{0:N2}' -f $row['hpp_avg']))
}
$c.Close()
