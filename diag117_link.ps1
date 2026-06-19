$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
foreach($fr in '1012604FR05001','1012604FR05002','1012604FR05003'){
  $out += "=== $fr ==="
  $cmd.CommandText = "SELECT order_client, order_reff, bukti_id, ttl_kotor, ttl_netto, vendor_id FROM ap_trans WHERE order_client='$fr'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  ap: oc=$($r[0]) order_reff=[$($r[1])] bukti=[$($r[2])] kotor=$($r[3]) netto=$($r[4]) vendor=[$($r[5])]" }; $r.Close()
  $cmd.CommandText = "SELECT order_client, order_reff FROM tstok1 WHERE order_client='$fr'"
  try{ $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  tstok1: oc=$($r[0]) order_reff=[$($r[1])]" }; $r.Close() }catch{ $out += "  tstok1: err $($_.Exception.Message)" }
  $cmd.CommandText = "SELECT COUNT(*), SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='$fr'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  tstok2: n=$($r[0]) sum_biayaXqty=$($r[1])" }; $r.Close()
}
$out += ""
$out += "=== apakah ap_trans FR ber-order_reff ke dok utama? cek arah sebaliknya ==="
$cmd.CommandText = "SELECT order_client, order_reff, ttl_netto FROM ap_trans WHERE order_reff IN ('10126040500001','10126040500002','10126040500003') "
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  oc=$($r[0]) order_reff=[$($r[1])] netto=$($r[2])" }; $r.Close()
$out += ""
$out += "=== tstok1.order_reff utk dok utama ==="
$cmd.CommandText = "SELECT order_client, order_reff FROM tstok1 WHERE order_client IN ('10126040500001','10126040500002','10126040500003')"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  oc=$($r[0]) order_reff=[$($r[1])]" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag117_link_out.txt -Encoding UTF8
