$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
foreach($fr in '1012604FR05001','1012604FR05002','1012604FR05003'){
  $out += "=== GL semua modul utk $fr ==="
  $cmd.CommandText = "SELECT modul_id, urut, account_id, debet, kredit, ket, voucher_manual FROM gl_journal WHERE doc_reff='$fr' ORDER BY modul_id, urut"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  mod=$($r[0]) urut=$($r[1]) acc=$($r[2]) Dr=$($r[3]) Cr=$($r[4]) ket=[$($r[5])] vm=[$($r[6])]" }; $r.Close()
  $cmd.CommandText = "SELECT t2.voucher, t1.voucher_manual, t1.tgl, t2.nilai_bayar_idr FROM tbyr2 t2 JOIN tbyr1 t1 ON t1.voucher=t2.voucher WHERE t2.bukti_id='$fr'"
  $r=$cmd.ExecuteReader(); $n=0
  while($r.Read()){ $n++; $out += "  DIBAYAR: v=[$($r[0])] vm=[$($r[1])] tgl=$($r[2]) idr=$($r[3])" }; $r.Close()
  if($n -eq 0){ $out += "  belum dibayar" }
}
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag117b_out.txt -Encoding UTF8
