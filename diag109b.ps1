$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG109b: Find 533271 root cause - fast queries - $(Get-Date) ==="

$out += ""
$out += "=== A: GL journal 102-001 Jan 2026 - show ALL unique vouchers by modul/tipe ==="
$cmd.CommandText = @"
SELECT modul_id, ISNULL(tipe_trans,'?') as tipe, COUNT(*) as cnt,
    SUM(debet) as Dr,
    SUM(kredit) as Cr
FROM gl_journal
WHERE account_id = '102-001'
  AND tgl BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY modul_id, tipe_trans
ORDER BY Cr DESC
"@
$r = $cmd.ExecuteReader()
$out += "modul | tipe | cnt | Dr | Cr"
while ($r.Read()) { $out += "$($r[0]) | $($r[1]) | $($r[2]) | $($r[3]) | $($r[4])" }
$r.Close()

$out += ""
$out += "=== B: tstok1 tipe 88 for TR products Jan 2026 - detail ==="
$cmd.CommandText = @"
SELECT t2.stok_id, t1.tipe_trans, t1.tgl, t1.bukti_id,
    t2.qty, t2.netto, t1.kurs,
    t2.netto*ISNULL(t1.kurs,1) as netto_rp, t2.netto_hpp
FROM tstok1 t1, tstok2 t2
WHERE t1.bukti_id=t2.bukti_id AND t2.stok_id LIKE 'TR.%'
  AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND ISNULL(t1.order_oke,'N')='Y'
ORDER BY t2.stok_id, t1.tgl
"@
$r2 = $cmd.ExecuteReader()
$out += "stok_id | tipe | tgl | bukti_id | qty | netto | kurs | netto_rp | netto_hpp"
while ($r2.Read()) { $out += "$($r2[0]) | $($r2[1]) | $($r2[2]) | $($r2[3]) | $($r2[4]) | $($r2[5]) | $($r2[6]) | $($r2[7]) | $($r2[8])" }
$r2.Close()

$out += ""
$out += "=== C: GL debet/kredit 102-001 by modul AS - detail view ==="
$cmd.CommandText = @"
SELECT j.voucher, j.tgl, j.debet, j.kredit, j.ket, j.modul_id
FROM gl_journal j
WHERE j.account_id = '102-001'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND j.modul_id = 'AS'
ORDER BY j.debet DESC, j.kredit DESC
"@
$r3 = $cmd.ExecuteReader()
$out += "voucher | tgl | debet | kredit | ket | modul"
while ($r3.Read()) { $out += "$($r3[0]) | $($r3[1]) | $($r3[2]) | $($r3[3]) | LEFT10=$($r3[4].ToString().Substring(0,[Math]::Min(30,$r3[4].ToString().Length))) | $($r3[5])" }
$r3.Close()

$out += ""
$out += "=== D: Compare consin_rp vs consin*hppx for TR products ==="
$cmd.CommandText = @"
SELECT p.produk_id,
    ISNULL(ci.consin_qty,0) as consin_qty,
    ISNULL(ci.consin_rp,0) as consin_rp,
    ISNULL(aw.awal,0) as awal_qty,
    ISNULL(aw.awal_rp,0) as awal_rp,
    CASE WHEN (ISNULL(aw.awal,0)+ISNULL(bq.beli,0)+ISNULL(bq.mutasi_in,0)-ISNULL(bq.ret_beli,0)) <> 0
         THEN (ISNULL(aw.awal_rp,0)+ISNULL(brp.beli,0)+ISNULL(brp.ekspedisi,0)+ISNULL(brp.mutasi_in,0)-ISNULL(brp.ret_beli,0)) /
              (ISNULL(aw.awal,0)+ISNULL(bq.beli,0)+ISNULL(bq.mutasi_in,0)-ISNULL(bq.ret_beli,0))
         ELSE 0 END as hppx,
    ISNULL(ci.consin_qty,0) * CASE WHEN (ISNULL(aw.awal,0)+ISNULL(bq.beli,0)+ISNULL(bq.mutasi_in,0)-ISNULL(bq.ret_beli,0)) <> 0
         THEN (ISNULL(aw.awal_rp,0)+ISNULL(brp.beli,0)+ISNULL(brp.ekspedisi,0)+ISNULL(brp.mutasi_in,0)-ISNULL(brp.ret_beli,0)) /
              (ISNULL(aw.awal,0)+ISNULL(bq.beli,0)+ISNULL(bq.mutasi_in,0)-ISNULL(bq.ret_beli,0))
         ELSE 0 END as consin_times_hppx
FROM im_produk p
JOIN im_product_group g ON g.kode_group = p.group_product
LEFT OUTER JOIN (SELECT stok_id, SUM(qty) as awal, SUM(nilai) as awal_rp FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) aw ON aw.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans='02' THEN t2.qty ELSE 0 END) as beli, SUM(CASE WHEN t1.tipe_trans='12' THEN t2.qty ELSE 0 END) as ret_beli, SUM(CASE WHEN t1.tipe_trans='09' THEN t2.qty ELSE 0 END) as mutasi_in FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) bq ON bq.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans='02' THEN t2.netto*ISNULL(t1.kurs,1) ELSE 0 END) as beli, SUM(CASE WHEN t1.tipe_trans='12' THEN ABS(t2.netto_hpp) ELSE 0 END) as ret_beli, SUM(CASE WHEN t1.tipe_trans='09' THEN t2.netto ELSE 0 END) as mutasi_in, SUM(CASE WHEN t1.tipe_trans='05' THEN ABS(t2.biaya_ekspedisi)*ABS(ISNULL(t2.qty,0)) ELSE 0 END) as ekspedisi FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) brp ON brp.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as consin_qty, SUM(t2.netto*ISNULL(t1.kurs,1)) as consin_rp FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) ci ON ci.stok_id = p.produk_id
WHERE p.stok_item='Y' AND g.persediaan='102-001' AND ISNULL(ci.consin_qty,0) <> 0
ORDER BY p.produk_id
"@
$r4 = $cmd.ExecuteReader()
$out += "produk_id | consin_qty | consin_rp | awal_qty | awal_rp | hppx | consin*hppx | diff(consin_rp - consin*hppx)"
while ($r4.Read()) {
    $consin_rp = if ($r4[2] -ne [DBNull]::Value) { [decimal]$r4[2] } else { 0 }
    $consin_x_hppx = if ($r4[6] -ne [DBNull]::Value) { [decimal]$r4[6] } else { 0 }
    $diff = $consin_rp - $consin_x_hppx
    $out += "$($r4[0]) | $($r4[1]) | $consin_rp | $($r4[3]) | $($r4[4]) | $($r4[5]) | $consin_x_hppx | $diff"
}
$r4.Close()

$out += ""
$out += "=== E: For each TR product sold in Jan: sinv_feb vs manually computed nilai ==="
$cmd.CommandText = @"
SELECT s.stok_id,
    s.qty as sinv_feb_qty,
    s.nilai as sinv_feb_nilai,
    s.hpp_avg as sinv_feb_hpp_avg,
    sjan.jan_qty,
    sjan.jan_nilai
FROM sinv s
JOIN (SELECT stok_id, SUM(qty) as jan_qty, SUM(nilai) as jan_nilai FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) sjan ON sjan.stok_id = s.stok_id
WHERE MONTH(s.periode)=2 AND YEAR(s.periode)=2026
  AND s.stok_id LIKE 'TR.%'
  AND ABS(ISNULL(s.nilai,0)) > 0
ORDER BY s.stok_id
"@
$r5 = $cmd.ExecuteReader()
$out += "stok_id | feb_qty | feb_nilai | feb_hpp_avg | jan_qty | jan_nilai"
while ($r5.Read()) { $out += "$($r5[0]) | $($r5[1]) | $($r5[2]) | $($r5[3]) | $($r5[4]) | $($r5[5])" }
$r5.Close()

$conn.Close()

$out | Out-File -FilePath "c:\BTV\debug\diag109b_out.txt" -Encoding UTF8
Write-Host "Done: c:\BTV\debug\diag109b_out.txt"
