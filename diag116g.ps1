$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
$out += "=== tstok1 header: biaya_ekspedisi & freight vs alokasi & jurnal ==="
foreach($oc in '10126040500001','10126040500002','10126040500003'){
  $cmd.CommandText = "SELECT order_client, biaya_ekspedisi, freight, freight_curr, freight_kurs, kurs, kurs1, kurs2 FROM tstok1 WHERE order_client='$oc'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "oc=$($r[0]) hdr_biayaEx=$($r[1]) hdr_freight=$($r[2]) fcurr=$($r[3]) fkurs=$($r[4]) kurs=$($r[5]) kurs1=$($r[6]) kurs2=$($r[7])" }; $r.Close()
}
$out += ""
$out += "=== Pembanding 2025 (yang jurnalnya cocok): 10125120500001 & 10125110500001 ==="
foreach($oc in '10125120500001','10125110500001','10125100500001'){
  $cmd.CommandText = "SELECT order_client, biaya_ekspedisi, freight, kurs, kurs2 FROM tstok1 WHERE order_client='$oc'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "oc=$($r[0]) hdr_biayaEx=$($r[1]) hdr_freight=$($r[2]) kurs=$($r[3]) kurs2=$($r[4])" }; $r.Close()
  $cmd.CommandText = "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='$oc'"
  $out += "   alloc_sum=" + $cmd.ExecuteScalar()
  $cmd.CommandText = "SELECT ttl_kotor, ttl_ppn, ttl_netto FROM ap_trans WHERE order_client='$oc'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "   ap: kotor=$($r[0]) ppn=$($r[1]) netto=$($r[2])" }; $r.Close()
}
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116g_out.txt -Encoding UTF8
