$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 180
$out=@()
# k(V1)=17337.54/145375.65=0.119260...  k(V2)=68775.92/767454.96=0.089616...
$out += "=== Baris tstok2 2026 dgn rasio k V1 (0.1192601) di bukti lain ==="
$cmd.CommandText = @"
SELECT t2.bukti_id, t1.tgl, t1.tipe_trans, COUNT(*) n, SUM(t2.netto) base, SUM(t2.biaya_ekspedisi*t2.qty) alloc
FROM tstok2 t2 JOIN tstok1 t1 ON t1.order_client = t2.bukti_id
WHERE t1.tgl >= '2026-01-01' AND t2.hrg > 0 AND t2.biaya_ekspedisi > 0
  AND ABS(t2.biaya_ekspedisi/t2.hrg - 0.11926011) < 0.000002
GROUP BY t2.bukti_id, t1.tgl, t1.tipe_trans ORDER BY t1.tgl
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "bukti=[$($r[0])] tgl=$($r[1]) tipe=$($r[2]) n=$($r[3]) base=$($r[4]) alloc=$($r[5])" }; $r.Close()
$out += ""
$out += "=== Baris tstok2 2026 dgn rasio k V2 (0.0896156) di bukti lain ==="
$cmd.CommandText = @"
SELECT t2.bukti_id, t1.tgl, t1.tipe_trans, COUNT(*) n, SUM(t2.netto) base, SUM(t2.biaya_ekspedisi*t2.qty) alloc
FROM tstok2 t2 JOIN tstok1 t1 ON t1.order_client = t2.bukti_id
WHERE t1.tgl >= '2026-01-01' AND t2.hrg > 0 AND t2.biaya_ekspedisi > 0
  AND ABS(t2.biaya_ekspedisi/t2.hrg - 0.08961558) < 0.000002
GROUP BY t2.bukti_id, t1.tgl, t1.tipe_trans ORDER BY t1.tgl
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "bukti=[$($r[0])] tgl=$($r[1]) tipe=$($r[2]) n=$($r[3]) base=$($r[4]) alloc=$($r[5])" }; $r.Close()

$out += ""
$out += "=== voucher_manual EX duplikat ==="
$cmd.CommandText = "SELECT voucher_manual, COUNT(DISTINCT doc_reff) FROM gl_journal WHERE modul_id='EX' AND tgl>='2025-01-01' GROUP BY voucher_manual HAVING COUNT(DISTINCT doc_reff) > 1"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "vm=[$($r[0])] jml_doc=$($r[1])" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116d_out.txt -Encoding UTF8
