$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
foreach($oc in '10126040500001','10126040500002','10126040500003'){
  $out += "=== $oc ==="
  $cmd.CommandText = "SELECT t2.voucher, t1.voucher_manual, t1.tgl, t2.nilai_bayar, t2.nilai_bayar_idr FROM tbyr2 t2 JOIN tbyr1 t1 ON t1.voucher=t2.voucher WHERE t2.bukti_id='$oc'"
  $r=$cmd.ExecuteReader(); $n=0
  while($r.Read()){ $n++; $out += "  DIBAYAR: v=[$($r[0])] vm=[$($r[1])] tgl=$($r[2]) bayar=$($r[3]) idr=$($r[4])" }
  $r.Close()
  if($n -eq 0){ $out += "  belum ada pembayaran terkait" }
}
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116h_out.txt -Encoding UTF8
