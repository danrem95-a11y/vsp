$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 180
$out=@()
$out += "=== Baris tstok2 dgn rasio k V1 (0.11926011) - semua bukti ==="
$cmd.CommandText = @"
SELECT t2.bukti_id, MIN(t1.tgl), MIN(t1.tipe_trans), COUNT(*) n, SUM(t2.netto) base, SUM(t2.biaya_ekspedisi*t2.qty) alloc
FROM tstok2 t2 JOIN tstok1 t1 ON t1.order_client = t2.bukti_id
WHERE t1.tgl >= '2025-12-01' AND t2.hrg > 0
  AND t2.biaya_ekspedisi >= t2.hrg*0.119258 AND t2.biaya_ekspedisi <= t2.hrg*0.119263
GROUP BY t2.bukti_id ORDER BY MIN(t1.tgl)
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "bukti=[$($r[0])] tgl=$($r[1]) tipe=$($r[2]) n=$($r[3]) base=$($r[4]) alloc=$($r[5])" }; $r.Close()
$out += ""
$out += "=== Baris tstok2 dgn rasio k V2 (0.08961558) - semua bukti ==="
$cmd.CommandText = @"
SELECT t2.bukti_id, MIN(t1.tgl), MIN(t1.tipe_trans), COUNT(*) n, SUM(t2.netto) base, SUM(t2.biaya_ekspedisi*t2.qty) alloc
FROM tstok2 t2 JOIN tstok1 t1 ON t1.order_client = t2.bukti_id
WHERE t1.tgl >= '2025-12-01' AND t2.hrg > 0
  AND t2.biaya_ekspedisi >= t2.hrg*0.089613 AND t2.biaya_ekspedisi <= t2.hrg*0.089618
GROUP BY t2.bukti_id ORDER BY MIN(t1.tgl)
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "bukti=[$($r[0])] tgl=$($r[1]) tipe=$($r[2]) n=$($r[3]) base=$($r[4]) alloc=$($r[5])" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116e_out.txt -Encoding UTF8
