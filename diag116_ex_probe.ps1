$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 120
$out=@()
$out += "=== Jurnal EX terbaru (modul_id='EX'), 15 voucher terakhir ==="
$cmd.CommandText = @"
SELECT TOP 15 doc_reff, tgl, SUM(debet) dr, SUM(kredit) cr, MIN(account_id), MAX(account_id), MAX(curr_id), MAX(rate_rp)
FROM gl_journal WHERE modul_id='EX'
GROUP BY doc_reff, tgl ORDER BY tgl DESC
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "doc=[$($r[0])] tgl=$($r[1]) Dr=$($r[2]) Cr=$($r[3]) acc=$($r[4])..$($r[5]) curr=$($r[6]) rate=$($r[7])" }; $r.Close()

$out += ""
$out += "=== Detail jurnal EX voucher terakhir ==="
$cmd.CommandText = "SELECT TOP 1 doc_reff FROM gl_journal WHERE modul_id='EX' ORDER BY tgl DESC"
$doc = $cmd.ExecuteScalar()
$out += "doc_reff sampel: $doc"
$cmd.CommandText = "SELECT urut, account_id, debet, kredit, debet_kurs, kredit_kurs, curr_id, rate_rp, ket, voucher_manual FROM gl_journal WHERE modul_id='EX' AND doc_reff='$doc' ORDER BY urut"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "urut=$($r[0]) acc=$($r[1]) Dr=$($r[2]) Cr=$($r[3]) DrK=$($r[4]) CrK=$($r[5]) curr=$($r[6]) rate=$($r[7]) ket=[$($r[8])] vm=[$($r[9])]" }; $r.Close()

$out += ""
$out += "=== Sumber input: ap_trans utk doc tsb ==="
$cmd.CommandText = "SELECT order_client, tipe_trans, curr_id, kurs, kurs1, kurs2, freight_kurs, ttl_kotor, ttl_pot, ttl_ppn, ttl_netto FROM ap_trans WHERE order_client='$doc'"
try { $r=$cmd.ExecuteReader(); while($r.Read()){ $v=@(); for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"}; $out += ($v -join ' | ') }; $r.Close() } catch { $out += "ap_trans err: $($_.Exception.Message)" }

$out += ""
$out += "=== Sumber input: tstok1/tstok2 utk doc tsb ==="
$cmd.CommandText = "SELECT order_client, tipe_trans, curr_id, kurs, kurs1, kurs2, freight_kurs FROM tstok1 WHERE order_client='$doc'"
try { $r=$cmd.ExecuteReader(); while($r.Read()){ $v=@(); for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"}; $out += ($v -join ' | ') }; $r.Close() } catch { $out += "tstok1 err: $($_.Exception.Message)" }
$cmd.CommandText = "SELECT COUNT(*), SUM(biaya_ekspedisi*qty), SUM(ABS(biaya_ekspedisi)*ABS(qty)) FROM tstok2 WHERE order_client='$doc'"
try { $r=$cmd.ExecuteReader(); while($r.Read()){ $out += "tstok2: n=$($r[0]) sum(biaya*qty)=$($r[1]) sum(abs)=$($r[2])" }; $r.Close() } catch { $out += "tstok2 err: $($_.Exception.Message)" }

$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116_ex_probe_out.txt -Encoding UTF8
