$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 120
$out=@()
foreach($oc in '10126040500001','10126040500002','10126040500003'){
  $out += "########## $oc ##########"
  $out += "--- gl_journal (EX) ---"
  $cmd.CommandText = "SELECT urut, account_id, debet, kredit, ket, voucher_manual, rate_rp FROM gl_journal WHERE modul_id='EX' AND doc_reff='$oc' ORDER BY urut"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  urut=$($r[0]) acc=$($r[1]) Dr=$($r[2]) Cr=$($r[3]) ket=[$($r[4])] vm=[$($r[5])] rate=$($r[6])" }; $r.Close()
  $out += "--- ap_trans header ---"
  $cmd.CommandText = "SELECT order_client, tgl, curr_id, kurs, ttl_kotor, ttl_pot, ttl_ppn, ttl_netto, keterangan FROM ap_trans WHERE order_client='$oc'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  oc=$($r[0]) tgl=$($r[1]) curr=$($r[2]) kurs=$($r[3]) kotor=$($r[4]) pot=$($r[5]) ppn=$($r[6]) netto=$($r[7]) ket=[$($r[8])]" }; $r.Close()
  $out += "--- tstok1 header ---"
  $cmd.CommandText = "SELECT order_client, tipe_trans, tgl, curr_id, kurs, kurs1, kurs2, freight_kurs, keterangan FROM tstok1 WHERE order_client='$oc'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  oc=$($r[0]) tipe=$($r[1]) tgl=$($r[2]) curr=$($r[3]) kurs=$($r[4]) kurs1=$($r[5]) kurs2=$($r[6]) fkurs=$($r[7]) ket=[$($r[8])]" }; $r.Close()
  $out += "--- tstok2 lines (bukti_id) ---"
  $cmd.CommandText = "SELECT COUNT(*), SUM(kotor), SUM(netto), SUM(ABS(biaya_ekspedisi)*ABS(qty)), SUM(biaya_ekspedisi) FROM tstok2 WHERE bukti_id='$oc'"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "  n=$($r[0]) sum_kotor=$($r[1]) sum_netto=$($r[2]) sum_biayaXqty=$($r[3]) sum_biaya=$($r[4])" }; $r.Close()
  $cmd.CommandText = "SELECT urut, stok_id, qty, hrg, kotor, netto, biaya_ekspedisi, coa_id FROM tstok2 WHERE bukti_id='$oc' ORDER BY urut"
  $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "    line urut=$($r[0]) stok=$($r[1]) qty=$($r[2]) hrg=$($r[3]) kotor=$($r[4]) netto=$($r[5]) biayaEx=$($r[6]) coa=$($r[7])" }; $r.Close()
  $out += ""
}
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116c_out.txt -Encoding UTF8
