$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()

$out += "=== Payment voucher_manual containing faktur 101BTB250300036 (modul CO) ==="
$cmd.CommandText = "SELECT DISTINCT voucher_manual FROM gl_journal WHERE order_reff = '101BTB250300036' AND modul_id='CO'"
$r = $cmd.ExecuteReader(); $vms=@()
while ($r.Read()) { $vms += $r[0].ToString() }
$r.Close()
$out += ($vms -join ', ')

foreach ($vm in $vms) {
  $out += ""
  $out += "=== Full GL voucher_manual=[$vm] ==="
  $cmd.CommandText = "SELECT urut, account_id, debet, kredit, debet_kurs, kredit_kurs, curr_id, rate_rp, kas_id, doc_reff, order_reff, ket FROM gl_journal WHERE voucher_manual = '$vm' ORDER BY urut"
  $r = $cmd.ExecuteReader()
  while ($r.Read()) { $out += "urut=$($r[0]) acc=$($r[1]) Dr=$($r[2]) Cr=$($r[3]) DrK=$($r[4]) CrK=$($r[5]) curr=$($r[6]) rate=$($r[7]) kas=$($r[8]) doc=[$($r[9])] ord=[$($r[10])] ket=[$($r[11])]"}
  $r.Close()
  $out += "--- tbyr1 ---"
  $cmd.CommandText = "SELECT voucher, voucher_manual, kas_id, curr_id, kurs, flag_bayar, tgl FROM tbyr1 WHERE voucher_manual = '$vm'"
  $r = $cmd.ExecuteReader()
  while ($r.Read()) { $out += "v=[$($r[0])] vm=[$($r[1])] kas=$($r[2]) curr=$($r[3]) kurs=$($r[4]) flag=$($r[5]) tgl=$($r[6])" }
  $r.Close()
  $out += "--- tbyr2 ---"
  $cmd.CommandText = "SELECT t2.voucher, t2.urut, t2.bukti_id, t2.nilai_bayar, t2.nilai_bayar_idr, t2.acc_bayar FROM tbyr2 t2 WHERE t2.voucher IN (SELECT voucher FROM tbyr1 WHERE voucher_manual='$vm')"
  $r = $cmd.ExecuteReader()
  while ($r.Read()) { $out += "v=[$($r[0])] urut=$($r[1]) bukti=[$($r[2])] nilai_bayar=$($r[3]) nilai_idr=$($r[4]) acc=$($r[5])" }
  $r.Close()
}

$out += ""
$out += "=== Account 500-013 master ==="
$cmd.CommandText = "SELECT account_id, descript FROM macc WHERE account_id LIKE '500-013%'"
try {
  $r = $cmd.ExecuteReader()
  while ($r.Read()) { $out += "acc=$($r[0]) desc=[$($r[1])]" }
  $r.Close()
} catch { $out += "macc query failed: $($_.Exception.Message)" }

$out += ""
$out += "=== Vouchers (CO) that still have a 500-013 row ==="
$cmd.CommandText = "SELECT TOP 10 voucher_manual, SUM(debet), SUM(kredit) FROM gl_journal WHERE account_id='500-013' AND modul_id='CO' GROUP BY voucher_manual ORDER BY voucher_manual DESC"
$r = $cmd.ExecuteReader()
while ($r.Read()) { $out += "vm=[$($r[0])] Dr=$($r[1]) Cr=$($r[2])" }
$r.Close()

$conn.Close()
$out | Set-Content "c:\BTV\debug\diag113_case_probe_out.txt" -Encoding UTF8
Write-Host "Done"
