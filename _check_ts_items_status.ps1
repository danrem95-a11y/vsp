$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Q([string]$sql){
  $m=$c.CreateCommand(); $m.CommandText=$sql; $m.CommandTimeout=180
  $rd=$m.ExecuteReader(); $rows=@()
  while($rd.Read()){ $row=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){ $row[$rd.GetName($i)]=$rd.GetValue($i) }; $rows+=,$row }
  $rd.Close(); return $rows
}

Write-Output "== Cek akun im_produk utk TS.066-8344C & TS.102-1081 =="
$r = Q "select produk_id, group_product from im_produk where produk_id in ('TS.066-8344C','TS.102-1081')"
foreach($row in $r){ Write-Output ("  "+$row['produk_id']+" | group="+$row['group_product']) }

Write-Output ""
Write-Output "== SINV nilai per bulan utk 2 item ini, Jan-Jul 2026 =="
$months=@('2026-01-01','2026-02-01','2026-03-01','2026-04-01','2026-05-01','2026-06-01','2026-07-01','2026-08-01')
foreach($item in @('TS.066-8344C','TS.102-1081')){
  Write-Output ""
  Write-Output "--- $item ---"
  foreach($m in $months){
    $rr = Q "select cast(qty as numeric(14,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(16,2)) hpp_avg from sinv where stok_id='$item' and periode='$m'"
    if($rr.Count -gt 0){
      Write-Output ("  "+$m+" | qty="+$rr[0]['qty']+" | nilai="+('{0:N2}' -f $rr[0]['nilai'])+" | hpp_avg="+('{0:N2}' -f $rr[0]['hpp_avg']))
    } else {
      Write-Output ("  "+$m+" | (tidak ada baris)")
    }
  }
}
$c.Close()
