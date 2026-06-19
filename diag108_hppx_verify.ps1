$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG108: Verify hppx Formula Mismatch = Root Cause of 533271 - $(Get-Date) ==="

$out += ""
$out += "=== A: OLD hppx vs NEW hppx for TR products (102-001) Jan 2026 ==="
$out += "(OLD = without ret_jual, NEW = with ret_jual - same as w_refresh_journal.srw)"
$cmd.CommandText = @"
SELECT p.produk_id,
    ISNULL(aw.awal,0) as sinv_qty,
    ISNULL(aw.awal_rp,0) as sinv_rp,
    ISNULL(beli.beli,0) as beli_qty,
    ISNULL(beli_rp.beli,0) + ISNULL(beli_rp.ekspedisi,0) as beli_rp,
    ISNULL(beli.mutasi_in,0) as mutasi_in,
    ISNULL(beli_rp.mutasi_in,0) as mutasi_in_rp,
    ISNULL(beli.ret_beli,0) as ret_beli,
    ISNULL(beli_rp.ret_beli,0) as ret_beli_rp,
    ISNULL(rj.ret_jual,0) as ret_jual,
    ISNULL(rj.ret_jual_rp,0) as ret_jual_rp,
    CASE WHEN (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)-ISNULL(beli.ret_beli,0)) <> 0
         THEN (ISNULL(aw.awal_rp,0)+ISNULL(beli_rp.beli,0)+ISNULL(beli_rp.ekspedisi,0)+ISNULL(beli_rp.mutasi_in,0)-ISNULL(beli_rp.ret_beli,0)) /
              (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)-ISNULL(beli.ret_beli,0))
         ELSE 0 END AS hppx_OLD,
    CASE WHEN (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)+ISNULL(rj.ret_jual,0)-ISNULL(beli.ret_beli,0)) <> 0
         THEN (ISNULL(aw.awal_rp,0)+ISNULL(beli_rp.beli,0)+ISNULL(beli_rp.ekspedisi,0)+ISNULL(beli_rp.mutasi_in,0)+ISNULL(rj.ret_jual_rp,0)-ISNULL(beli_rp.ret_beli,0)) /
              (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)+ISNULL(rj.ret_jual,0)-ISNULL(beli.ret_beli,0))
         ELSE 0 END AS hppx_NEW
FROM im_produk p
JOIN im_product_group g ON g.kode_group = p.group_product
LEFT OUTER JOIN (SELECT stok_id, SUM(qty) as awal, SUM(nilai) as awal_rp FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) aw ON aw.stok_id = p.produk_id
LEFT OUTER JOIN (
    SELECT t2.stok_id,
        SUM(CASE WHEN t1.tipe_trans='02' THEN t2.qty ELSE 0 END) as beli,
        SUM(CASE WHEN t1.tipe_trans='12' THEN t2.qty ELSE 0 END) as ret_beli,
        SUM(CASE WHEN t1.tipe_trans='09' THEN t2.qty ELSE 0 END) as mutasi_in
    FROM tstok1 t1, tstok2 t2
    WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
    AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0
    GROUP BY t2.stok_id
) beli ON beli.stok_id = p.produk_id
LEFT OUTER JOIN (
    SELECT t2.stok_id,
        SUM(CASE WHEN t1.tipe_trans='02' THEN t2.netto*ISNULL(t1.kurs,1) ELSE 0 END) as beli,
        SUM(CASE WHEN t1.tipe_trans='12' THEN ABS(t2.netto_hpp) ELSE 0 END) as ret_beli,
        SUM(CASE WHEN t1.tipe_trans='09' THEN t2.netto ELSE 0 END) as mutasi_in,
        SUM(CASE WHEN t1.tipe_trans='05' THEN ABS(t2.biaya_ekspedisi)*ABS(ISNULL(t2.qty,0)) ELSE 0 END) as ekspedisi
    FROM tstok1 t1, tstok2 t2
    WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
    AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0
    GROUP BY t2.stok_id
) beli_rp ON beli_rp.stok_id = p.produk_id
LEFT OUTER JOIN (
    SELECT t2.stok_id,
        SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN t2.qty ELSE 0 END) as ret_jual,
        SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN ABS(t2.netto*ISNULL(t1.kurs,1)) ELSE 0 END) as ret_jual_rp
    FROM tsales1 t1, tsales2 t2
    WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
    AND t1.order_oke='Y' AND t1.tipe_trans IN ('32','26','36')
    GROUP BY t2.stok_id
) rj ON rj.stok_id = p.produk_id
WHERE p.stok_item='Y'
  AND g.persediaan = '102-001'
  AND ISNULL(rj.ret_jual,0) <> 0
ORDER BY p.produk_id
"@
$r = $cmd.ExecuteReader()
$out += "produk_id | sinv_qty | beli_qty | ret_beli | ret_jual | ret_jual_rp | hppx_OLD | hppx_NEW | diff_hpp"
while ($r.Read()) {
    $hppx_old = if ($r[11] -ne [DBNull]::Value) { [decimal]$r[11] } else { 0 }
    $hppx_new = if ($r[12] -ne [DBNull]::Value) { [decimal]$r[12] } else { 0 }
    $out += "$($r[0]) | $($r[1]) | $($r[3]) | $($r[7]) | $($r[9]) | $($r[10]) | $hppx_old | $hppx_new | $($hppx_old - $hppx_new)"
}
$r.Close()

$out += ""
$out += "=== B: JUAL qty per TR product (for computing selisih impact) ==="
$cmd.CommandText = @"
SELECT t2.stok_id,
    SUM(t2.qty) as jual_qty,
    AVG(ISNULL(t2.hpp,0)) as tsales2_hpp_current,
    p.group_product,
    g.persediaan as coa
FROM tsales1 t1, tsales2 t2
JOIN im_produk p ON p.produk_id = t2.stok_id
JOIN im_product_group g ON g.kode_group = p.group_product
WHERE t1.bukti_id = t2.bukti_id
  AND t1.tipe_trans = '22'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
  AND g.persediaan = '102-001'
  AND ISNULL(t2.qty,0) <> 0
GROUP BY t2.stok_id, p.group_product, g.persediaan
ORDER BY t2.stok_id
"@
$r2 = $cmd.ExecuteReader()
$out += "stok_id | jual_qty | tsales2_hpp_current | coa"
while ($r2.Read()) {
    $out += "$($r2[0]) | $($r2[1]) | $($r2[2]) | $($r2[4])"
}
$r2.Close()

$out += ""
$out += "=== C: Total selisih impact OLD vs NEW hppx for account 102-001 ==="
$cmd.CommandText = @"
SELECT
    SUM(jual_qty * hppx_OLD) as nilai_jual_OLD,
    SUM(jual_qty * hppx_NEW) as nilai_jual_NEW,
    SUM(jual_qty * hppx_OLD) - SUM(jual_qty * hppx_NEW) as selisih_jual,
    SUM(consout_qty * hppx_OLD) - SUM(consout_qty * hppx_NEW) as selisih_consout,
    SUM(consin_qty * hppx_OLD) - SUM(consin_qty * hppx_NEW) as selisih_consin
FROM (
    SELECT p.produk_id,
        ISNULL(j.jual_qty, 0) as jual_qty,
        ISNULL(co.consout_qty, 0) as consout_qty,
        ISNULL(ci.consin_qty, 0) as consin_qty,
        CASE WHEN (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)-ISNULL(beli.ret_beli,0)) <> 0
             THEN (ISNULL(aw.awal_rp,0)+ISNULL(beli_rp.beli,0)+ISNULL(beli_rp.ekspedisi,0)+ISNULL(beli_rp.mutasi_in,0)-ISNULL(beli_rp.ret_beli,0)) /
                  (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)-ISNULL(beli.ret_beli,0))
             ELSE 0 END AS hppx_OLD,
        CASE WHEN (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)+ISNULL(rj.ret_jual,0)-ISNULL(beli.ret_beli,0)) <> 0
             THEN (ISNULL(aw.awal_rp,0)+ISNULL(beli_rp.beli,0)+ISNULL(beli_rp.ekspedisi,0)+ISNULL(beli_rp.mutasi_in,0)+ISNULL(rj.ret_jual_rp,0)-ISNULL(beli_rp.ret_beli,0)) /
                  (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)+ISNULL(rj.ret_jual,0)-ISNULL(beli.ret_beli,0))
             ELSE 0 END AS hppx_NEW
    FROM im_produk p
    JOIN im_product_group g ON g.kode_group = p.group_product
    LEFT OUTER JOIN (SELECT stok_id, SUM(qty) as awal, SUM(nilai) as awal_rp FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) aw ON aw.stok_id = p.produk_id
    LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans='02' THEN t2.qty ELSE 0 END) as beli, SUM(CASE WHEN t1.tipe_trans='12' THEN t2.qty ELSE 0 END) as ret_beli, SUM(CASE WHEN t1.tipe_trans='09' THEN t2.qty ELSE 0 END) as mutasi_in FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) beli ON beli.stok_id = p.produk_id
    LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans='02' THEN t2.netto*ISNULL(t1.kurs,1) ELSE 0 END) as beli, SUM(CASE WHEN t1.tipe_trans='12' THEN ABS(t2.netto_hpp) ELSE 0 END) as ret_beli, SUM(CASE WHEN t1.tipe_trans='09' THEN t2.netto ELSE 0 END) as mutasi_in, SUM(CASE WHEN t1.tipe_trans='05' THEN ABS(t2.biaya_ekspedisi)*ABS(ISNULL(t2.qty,0)) ELSE 0 END) as ekspedisi FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) beli_rp ON beli_rp.stok_id = p.produk_id
    LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN t2.qty ELSE 0 END) as ret_jual, SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN ABS(t2.netto*ISNULL(t1.kurs,1)) ELSE 0 END) as ret_jual_rp FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' AND t1.tipe_trans IN ('32','26','36') GROUP BY t2.stok_id) rj ON rj.stok_id = p.produk_id
    LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as jual_qty FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='22' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) j ON j.stok_id = p.produk_id
    LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as consout_qty FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) co ON co.stok_id = p.produk_id
    LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as consin_qty FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) ci ON ci.stok_id = p.produk_id
    WHERE p.stok_item='Y' AND g.persediaan = '102-001'
) sub
"@
$r3 = $cmd.ExecuteReader()
$out += "nilai_jual_OLD | nilai_jual_NEW | selisih_jual | selisih_consout | selisih_consin"
while ($r3.Read()) {
    $out += "$($r3[0]) | $($r3[1]) | $($r3[2]) | $($r3[3]) | $($r3[4])"
}
$r3.Close()

$out += ""
$out += "=== D: Also check: ret_jual at GL (HPP cost) vs ret_jual_rp (selling price) impact ==="
$cmd.CommandText = @"
SELECT
    SUM(ISNULL(rj.ret_jual,0)) as ret_jual_qty,
    SUM(ISNULL(rj.ret_jual_rp,0)) as ret_jual_at_selling,
    SUM(ISNULL(rj.ret_jual,0) * ISNULL(s.hpp_avg,0)) as ret_jual_at_cost,
    SUM(ISNULL(rj.ret_jual_rp,0)) - SUM(ISNULL(rj.ret_jual,0) * ISNULL(s.hpp_avg,0)) as ret_jual_price_vs_cost
FROM im_produk p
JOIN im_product_group g ON g.kode_group = p.group_product
LEFT OUTER JOIN (
    SELECT t2.stok_id,
        SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN t2.qty ELSE 0 END) as ret_jual,
        SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN ABS(t2.netto*ISNULL(t1.kurs,1)) ELSE 0 END) as ret_jual_rp
    FROM tsales1 t1, tsales2 t2
    WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
    AND t1.order_oke='Y' AND t1.tipe_trans IN ('32','26','36')
    GROUP BY t2.stok_id
) rj ON rj.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT stok_id, AVG(hpp_avg) as hpp_avg FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) s ON s.stok_id = p.produk_id
WHERE p.stok_item='Y' AND g.persediaan = '102-001'
  AND ISNULL(rj.ret_jual,0) <> 0
"@
$r4 = $cmd.ExecuteReader()
$out += "ret_jual_qty | ret_jual_at_selling | ret_jual_at_cost | selling_minus_cost"
while ($r4.Read()) {
    $out += "$($r4[0]) | $($r4[1]) | $($r4[2]) | $($r4[3])"
}
$r4.Close()

$out += ""
$out += "=== E: Verify total selisih = GL saldo akhir - SINV Feb 2026 for 102-001 ==="
$out += "Expected: 9072870161.90 - 9072336890.75 = 533271.15"
$cmd.CommandText = @"
SELECT
    (bal.saldo_awal + ISNULL(mut.dr,0) - ISNULL(mut.cr,0)) as gl_saldo_akhir_jan,
    sinv_feb.nilai as sinv_feb_nilai,
    (bal.saldo_awal + ISNULL(mut.dr,0) - ISNULL(mut.cr,0)) - sinv_feb.nilai as selisih
FROM (SELECT SUM(AmountDebet)-SUM(AmountCredit) as saldo_awal FROM gl_balance WHERE AccountCode='102-001' AND Period='2026-01-01') bal,
     (SELECT SUM(debet) as dr, SUM(kredit) as cr FROM gl_journal WHERE account_id='102-001' AND tgl BETWEEN '2026-01-01' AND '2026-01-31') mut,
     (SELECT SUM(ISNULL(nilai,0)) as nilai FROM sinv WHERE MONTH(periode)=2 AND YEAR(periode)=2026 AND stok_id LIKE 'TR.%') sinv_feb
"@
$r5 = $cmd.ExecuteReader()
while ($r5.Read()) {
    $out += "GL saldo akhir = $($r5[0])  SINV Feb = $($r5[1])  Selisih = $($r5[2])"
}
$r5.Close()

$conn.Close()

$out | Out-File -FilePath "c:\BTV\debug\diag108_hppx_verify_out.txt" -Encoding UTF8
Write-Host "Done. Output: c:\BTV\debug\diag108_hppx_verify_out.txt"
