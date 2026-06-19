$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG109: Decompose akhir_rpxx vs GL for TR products (102-001) - $(Get-Date) ==="

$out += ""
$out += "=== A: tstok1 tipe_trans summary for TR products in Jan 2026 ==="
$cmd.CommandText = @"
SELECT t1.tipe_trans, COUNT(*) as cnt,
    SUM(t2.qty) as qty,
    SUM(ISNULL(t2.netto,0)*ISNULL(t1.kurs,1)) as netto_rp,
    SUM(ISNULL(t2.netto_hpp,0)) as netto_hpp,
    SUM(ISNULL(t2.biaya_ekspedisi,0)*ABS(ISNULL(t2.qty,0))) as ekspedisi_rp
FROM tstok1 t1, tstok2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t2.stok_id LIKE 'TR.%'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND ISNULL(t1.order_oke,'N') = 'Y'
GROUP BY t1.tipe_trans
ORDER BY t1.tipe_trans
"@
$r = $cmd.ExecuteReader()
$out += "tipe_trans | cnt | qty | netto_rp | netto_hpp | ekspedisi_rp"
while ($r.Read()) { $out += "$($r[0]) | $($r[1]) | $($r[2]) | $($r[3]) | $($r[4]) | $($r[5])" }
$r.Close()

$out += ""
$out += "=== B: tsales1 tipe_trans summary for TR products in Jan 2026 ==="
$cmd.CommandText = @"
SELECT t1.tipe_trans, COUNT(*) as cnt,
    SUM(t2.qty) as qty,
    SUM(t2.qty * ISNULL(t2.hpp,0)) as nilai_hpp,
    SUM(ISNULL(t2.netto,0)*ISNULL(t1.kurs,1)) as netto_rp
FROM tsales1 t1, tsales2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t2.stok_id LIKE 'TR.%'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
GROUP BY t1.tipe_trans
ORDER BY t1.tipe_trans
"@
$r2 = $cmd.ExecuteReader()
$out += "tipe_trans | cnt | qty | nilai_hpp | netto_rp"
while ($r2.Read()) { $out += "$($r2[0]) | $($r2[1]) | $($r2[2]) | $($r2[3]) | $($r2[4])" }
$r2.Close()

$out += ""
$out += "=== C: Compute akhir_rpxx components for ALL TR products (account 102-001) ==="
$cmd.CommandText = @"
SELECT
    SUM(ISNULL(aw.awal_rp,0)) as awal_rp,
    SUM(ISNULL(beli_rp.beli,0)) + SUM(ISNULL(beli_rp.ekspedisi,0)) as beli_rp,
    SUM(ISNULL(beli_rp.mutasi_in,0)) as mutasi_in_rp,
    SUM(ISNULL(beli_rp.ret_beli,0)) as ret_beli_rp,
    SUM(ISNULL(beli.beli,0)) as beli_qty,
    SUM(ISNULL(beli.mutasi_in,0)) as mutasi_in_qty,
    SUM(ISNULL(beli.ret_beli,0)) as ret_beli_qty,
    SUM(ISNULL(aw.awal,0)) as awal_qty,
    SUM(ISNULL(rj.ret_jual,0)) as ret_jual_qty,
    SUM(ISNULL(rj.ret_jual_rp,0)) as ret_jual_rp,
    SUM(ISNULL(stok_consin.consin_qty,0)) as consin_qty,
    SUM(ISNULL(stok_consin.consin_rp,0)) as consin_rp,
    SUM(ISNULL(stok_mutout.mutout_qty,0)) as mutout_qty,
    SUM(ISNULL(stok_mutout.mutout_rp,0)) as mutout_rp,
    SUM(ISNULL(jual22.jual_qty,0)) as jual22_qty,
    SUM(ISNULL(consout88.consout_qty,0)) as consout88_qty,
    SUM(ISNULL(consinbyevap.consin_by_evap_rp,0)) as consin_by_evap_rp,
    SUM(ISNULL(jualbyevap.jual_by_evap_rp,0)) as jual_by_evap_rp
FROM im_produk p
JOIN im_product_group g ON g.kode_group = p.group_product
LEFT OUTER JOIN (SELECT stok_id, SUM(qty) as awal, SUM(nilai) as awal_rp FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) aw ON aw.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans='02' THEN t2.qty ELSE 0 END) as beli, SUM(CASE WHEN t1.tipe_trans='12' THEN t2.qty ELSE 0 END) as ret_beli, SUM(CASE WHEN t1.tipe_trans='09' THEN t2.qty ELSE 0 END) as mutasi_in FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) beli ON beli.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans='02' THEN t2.netto*ISNULL(t1.kurs,1) ELSE 0 END) as beli, SUM(CASE WHEN t1.tipe_trans='12' THEN ABS(t2.netto_hpp) ELSE 0 END) as ret_beli, SUM(CASE WHEN t1.tipe_trans='09' THEN t2.netto ELSE 0 END) as mutasi_in, SUM(CASE WHEN t1.tipe_trans='05' THEN ABS(t2.biaya_ekspedisi)*ABS(ISNULL(t2.qty,0)) ELSE 0 END) as ekspedisi FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) beli_rp ON beli_rp.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN t2.qty ELSE 0 END) as ret_jual, SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN ABS(t2.netto*ISNULL(t1.kurs,1)) ELSE 0 END) as ret_jual_rp FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' AND t1.tipe_trans IN ('32','26','36') GROUP BY t2.stok_id) rj ON rj.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as consin_qty, SUM(t2.netto*ISNULL(t1.kurs,1)) as consin_rp FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) stok_consin ON stok_consin.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as mutout_qty, SUM(ABS(t2.netto_hpp)) as mutout_rp FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='19' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND ISNULL(t1.order_oke,'N')='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) stok_mutout ON stok_mutout.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as jual_qty FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='22' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) jual22 ON jual22.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT t2.stok_id, SUM(t2.qty) as consout_qty FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y' AND ISNULL(t2.qty,0)<>0 GROUP BY t2.stok_id) consout88 ON consout88.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT A.stok_id, SUM(A.qty * ISNULL(B.hpp,0)) as consin_by_evap_rp FROM (SELECT t2.stok_id, t2.qty, t2.stok_id+ISNULL(t2.coa_id,'') as key1 FROM tstok1 t1, tstok2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND ISNULL(t2.qty,0)<>0 AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31') A, (SELECT t2.stok_id+ISNULL(t2.evap,'') as key1, ISNULL(t2.hpp,0) as hpp FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl < '2026-01-01') B WHERE A.key1 = B.key1 GROUP BY A.stok_id) consinbyevap ON consinbyevap.stok_id = p.produk_id
LEFT OUTER JOIN (SELECT A.stok_id, SUM(A.qty * ISNULL(B.hpp,0)) as jual_by_evap_rp FROM (SELECT t2.stok_id, t2.qty, t2.stok_id+ISNULL(t2.evap,'') as key1 FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='22' AND ISNULL(t2.evap,'')<>'' AND ISNULL(t2.qty,0)<>0 AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31' AND t1.order_oke='Y') A, (SELECT t2.stok_id+ISNULL(t2.evap,'') as key1, ISNULL(t2.hpp,0) as hpp FROM tsales1 t1, tsales2 t2 WHERE t1.bukti_id=t2.bukti_id AND t1.tipe_trans='88' AND t1.tgl < '2026-01-01') B WHERE A.key1 = B.key1 GROUP BY A.stok_id) jualbyevap ON jualbyevap.stok_id = p.produk_id
WHERE p.stok_item='Y' AND g.persediaan = '102-001'
"@
$r3 = $cmd.ExecuteReader()
while ($r3.Read()) {
    $awal_rp = if ($r3[0] -ne [DBNull]::Value) { [decimal]$r3[0] } else { 0 }
    $beli_rp = if ($r3[1] -ne [DBNull]::Value) { [decimal]$r3[1] } else { 0 }
    $mutasi_in_rp = if ($r3[2] -ne [DBNull]::Value) { [decimal]$r3[2] } else { 0 }
    $ret_beli_rp = if ($r3[3] -ne [DBNull]::Value) { [decimal]$r3[3] } else { 0 }
    $beli_qty = if ($r3[4] -ne [DBNull]::Value) { [decimal]$r3[4] } else { 0 }
    $mutasi_in_qty = if ($r3[5] -ne [DBNull]::Value) { [decimal]$r3[5] } else { 0 }
    $ret_beli_qty = if ($r3[6] -ne [DBNull]::Value) { [decimal]$r3[6] } else { 0 }
    $awal_qty = if ($r3[7] -ne [DBNull]::Value) { [decimal]$r3[7] } else { 0 }
    $ret_jual_qty = if ($r3[8] -ne [DBNull]::Value) { [decimal]$r3[8] } else { 0 }
    $ret_jual_rp = if ($r3[9] -ne [DBNull]::Value) { [decimal]$r3[9] } else { 0 }
    $consin_qty = if ($r3[10] -ne [DBNull]::Value) { [decimal]$r3[10] } else { 0 }
    $consin_rp = if ($r3[11] -ne [DBNull]::Value) { [decimal]$r3[11] } else { 0 }
    $mutout_qty = if ($r3[12] -ne [DBNull]::Value) { [decimal]$r3[12] } else { 0 }
    $mutout_rp = if ($r3[13] -ne [DBNull]::Value) { [decimal]$r3[13] } else { 0 }
    $jual22_qty = if ($r3[14] -ne [DBNull]::Value) { [decimal]$r3[14] } else { 0 }
    $consout88_qty = if ($r3[15] -ne [DBNull]::Value) { [decimal]$r3[15] } else { 0 }
    $consin_by_evap_rp = if ($r3[16] -ne [DBNull]::Value) { [decimal]$r3[16] } else { 0 }
    $jual_by_evap_rp = if ($r3[17] -ne [DBNull]::Value) { [decimal]$r3[17] } else { 0 }

    $denom = $awal_qty + $beli_qty + $mutasi_in_qty + $ret_jual_qty - $ret_beli_qty
    if ($denom -ne 0) {
        $hppx = ($awal_rp + $beli_rp + $mutasi_in_rp + $ret_jual_rp - $ret_beli_rp) / $denom
    } else { $hppx = 0 }
    $cjual_rp = $jual_by_evap_rp + ($jual22_qty * $hppx)
    if ($hppx -ne 0) { $consin_eff = $consin_qty * $hppx } else { $consin_eff = $consin_rp }
    $akhir_rpxx = $awal_rp + $beli_rp + $ret_jual_rp + $consin_by_evap_rp + $consin_eff + $mutasi_in_rp - $cjual_rp - $ret_beli_rp - ($consout88_qty * $hppx) - $mutout_rp

    $out += "awal_rp       = $awal_rp"
    $out += "beli_rp       = $beli_rp"
    $out += "mutasi_in_rp  = $mutasi_in_rp"
    $out += "ret_beli_rp   = $ret_beli_rp"
    $out += "awal_qty      = $awal_qty"
    $out += "beli_qty      = $beli_qty"
    $out += "mutasi_in_qty = $mutasi_in_qty"
    $out += "ret_beli_qty  = $ret_beli_qty"
    $out += "ret_jual_qty  = $ret_jual_qty"
    $out += "ret_jual_rp   = $ret_jual_rp"
    $out += "consin_qty    = $consin_qty"
    $out += "consin_rp     = $consin_rp"
    $out += "consin_by_evap_rp = $consin_by_evap_rp"
    $out += "jual_by_evap_rp = $jual_by_evap_rp"
    $out += "consout88_qty = $consout88_qty"
    $out += "mutout_qty    = $mutout_qty"
    $out += "mutout_rp     = $mutout_rp"
    $out += "jual22_qty    = $jual22_qty"
    $out += "--- COMPUTED ---"
    $out += "hppx          = $hppx"
    $out += "cjual_rp      = $cjual_rp"
    $out += "consin_eff    = $consin_eff"
    $out += "akhir_rpxx    = $akhir_rpxx"
}
$r3.Close()

$out += ""
$out += "=== D: SINV Feb for TR products total ==="
$cmd.CommandText = @"
SELECT SUM(ISNULL(nilai,0)) as total_nilai FROM sinv WHERE MONTH(periode)=2 AND YEAR(periode)=2026 AND stok_id LIKE 'TR.%'
"@
$r4 = $cmd.ExecuteReader()
while ($r4.Read()) { $out += "SINV Feb TR total = $($r4[0])" }
$r4.Close()

$out += ""
$out += "=== E: GL journal 102-001 Jan 2026 detail - ALL modul types ==="
$cmd.CommandText = @"
SELECT modul_id, tipe_trans,
    SUM(debet) as Dr,
    SUM(kredit) as Cr,
    COUNT(*) as cnt
FROM gl_journal
WHERE account_id = '102-001'
  AND tgl BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY modul_id, tipe_trans
ORDER BY Cr DESC
"@
$r5 = $cmd.ExecuteReader()
$out += "modul_id | tipe_trans | Dr | Cr | cnt"
while ($r5.Read()) { $out += "$($r5[0]) | $($r5[1]) | $($r5[2]) | $($r5[3]) | $($r5[4])" }
$r5.Close()

$out += ""
$out += "=== F: Consin (tstok tipe 88) detail for TR products Jan 2026 ==="
$cmd.CommandText = @"
SELECT t2.stok_id, t1.bukti_id, t2.qty,
    t2.netto, t1.kurs,
    t2.netto*ISNULL(t1.kurs,1) as netto_rp,
    t2.netto_hpp
FROM tstok1 t1, tstok2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t2.stok_id LIKE 'TR.%'
  AND t1.tipe_trans = '88'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND ISNULL(t1.order_oke,'N') = 'Y'
ORDER BY t2.stok_id
"@
$r6 = $cmd.ExecuteReader()
$out += "stok_id | bukti_id | qty | netto | kurs | netto_rp | netto_hpp"
while ($r6.Read()) { $out += "$($r6[0]) | $($r6[1]) | $($r6[2]) | $($r6[3]) | $($r6[4]) | $($r6[5]) | $($r6[6])" }
$r6.Close()

$out += ""
$out += "=== G: What GL entries exist for 102-001 that are NOT from tsales/tstok? ==="
$cmd.CommandText = @"
SELECT j.voucher, j.modul_id, j.tipe_trans, j.tgl,
    j.debet, j.kredit, j.ket,
    j.kas_id
FROM gl_journal j
WHERE j.account_id = '102-001'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND j.modul_id NOT IN ('HP','PO')
ORDER BY j.tgl, j.voucher
"@
$r7 = $cmd.ExecuteReader()
$out += "voucher | modul | tipe | tgl | debet | kredit | ket | kas_id"
while ($r7.Read()) { $out += "$($r7[0]) | $($r7[1]) | $($r7[2]) | $($r7[3]) | $($r7[4]) | $($r7[5]) | $($r7[6]) | $($r7[7])" }
$r7.Close()

$conn.Close()

$out | Out-File -FilePath "c:\BTV\debug\diag109_decompose_out.txt" -Encoding UTF8
Write-Host "Done. Output: c:\BTV\debug\diag109_decompose_out.txt"
