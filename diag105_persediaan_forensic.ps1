$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== FORENSIC: Persediaan Selisih Jan 2026 - $(Get-Date) ==="

# ===== STEP 1: GL Persediaan Balance Jan 2026 =====
$out += ""
$out += "=== STEP 1: GL Persediaan (BS2015) saldo awal + mutasi Jan 2026 ==="
$cmd.CommandText = @"
SELECT 
    SUM(g.AmountDebet) as opening_Dr,
    SUM(g.AmountCredit) as opening_Cr,
    SUM(g.AmountDebet) - SUM(g.AmountCredit) as saldo_awal_jan
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-01-01'
  AND a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
"@
$r = $cmd.ExecuteReader()
while ($r.Read()) {
    $saldo_awal_jan = [decimal]$r[2]
    $out += "Opening Jan 2026 (gl_balance): Dr=$($r[0]) Cr=$($r[1]) SALDO_AWAL=$saldo_awal_jan"
}
$r.Close()

$cmd.CommandText = @"
SELECT 
    SUM(j.debet) as jan_Dr,
    SUM(j.kredit) as jan_Cr,
    SUM(j.debet) - SUM(j.kredit) as mutasi_net
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
"@
$r2 = $cmd.ExecuteReader()
while ($r2.Read()) {
    $jan_Dr = if ($r2[0] -ne [DBNull]::Value) { [decimal]$r2[0] } else { 0 }
    $jan_Cr = if ($r2[1] -ne [DBNull]::Value) { [decimal]$r2[1] } else { 0 }
    $out += "Jan 2026 GL journal: Dr=$jan_Dr Cr=$jan_Cr Net=$($r2[2])"
}
$r2.Close()

# ===== STEP 2: GL Persediaan by modul_id =====
$out += ""
$out += "=== STEP 2: GL Persediaan Jan 2026 - by modul_id ==="
$cmd.CommandText = @"
SELECT j.modul_id,
    SUM(j.debet) as Dr,
    SUM(j.kredit) as Cr,
    COUNT(*) as cnt
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY j.modul_id
ORDER BY Cr DESC
"@
$r3 = $cmd.ExecuteReader()
$out += "modul_id | Dr | Cr | cnt"
while ($r3.Read()) {
    $out += "$($r3[0]) | $($r3[1]) | $($r3[2]) | $($r3[3])"
}
$r3.Close()

# ===== STEP 3: SINV saldo awal Feb 2026 (= saldo akhir Jan dari closing) =====
$out += ""
$out += "=== STEP 3: SINV saldo awal Feb 2026 (from closing Jan) ==="
$cmd.CommandText = @"
SELECT 
    COUNT(*) as rows,
    SUM(ISNULL(qty,0)) as total_qty,
    SUM(ISNULL(nilai,0)) as total_nilai
FROM sinv
WHERE MONTH(periode) = 2 AND YEAR(periode) = 2026
"@
$r4 = $cmd.ExecuteReader()
while ($r4.Read()) {
    $sinv_feb_nilai = if ($r4[2] -ne [DBNull]::Value) { [decimal]$r4[2] } else { 0 }
    $out += "SINV Feb 2026: rows=$($r4[0]) qty=$($r4[1]) nilai=$sinv_feb_nilai"
}
$r4.Close()

# ===== STEP 4: SINV saldo awal Jan 2026 (from closing Dec) =====
$out += ""
$out += "=== STEP 4: SINV saldo awal Jan 2026 ==="
$cmd.CommandText = @"
SELECT 
    COUNT(*) as rows,
    SUM(ISNULL(qty,0)) as total_qty,
    SUM(ISNULL(nilai,0)) as total_nilai
FROM sinv
WHERE MONTH(periode) = 1 AND YEAR(periode) = 2026
"@
$r5 = $cmd.ExecuteReader()
while ($r5.Read()) {
    $sinv_jan_nilai = if ($r5[2] -ne [DBNull]::Value) { [decimal]$r5[2] } else { 0 }
    $out += "SINV Jan 2026 (awal): rows=$($r5[0]) qty=$($r5[1]) nilai=$sinv_jan_nilai"
}
$r5.Close()

# ===== STEP 5: Mutasi Keluar Stok Jan 2026 from tsales2 (JUAL = tipe 22, CONSOUT = tipe 88, MUTASI_OUT = tipe 19) =====
$out += ""
$out += "=== STEP 5: Mutasi Keluar dari tsales/tstok (current tsales2.hpp) ==="
$cmd.CommandText = @"
SELECT 'JUAL-22' as jenis,
    SUM(t2.qty) as qty,
    SUM(t2.qty * ISNULL(t2.hpp,0)) as nilai_hpp
FROM tsales1 t1, tsales2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t1.tipe_trans = '22'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
  AND ISNULL(t2.qty,0) <> 0
"@
$r6 = $cmd.ExecuteReader()
while ($r6.Read()) {
    $out += "Jenis=$($r6[0]) qty=$($r6[1]) nilai_hpp=$($r6[2])"
}
$r6.Close()

$cmd.CommandText = @"
SELECT 'CONSOUT-88' as jenis,
    SUM(t2.qty) as qty,
    SUM(t2.qty * ISNULL(t2.hpp,0)) as nilai_hpp
FROM tsales1 t1, tsales2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t1.tipe_trans = '88'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
  AND ISNULL(t2.qty,0) <> 0
"@
$r7 = $cmd.ExecuteReader()
while ($r7.Read()) {
    $out += "Jenis=$($r7[0]) qty=$($r7[1]) nilai_hpp=$($r7[2])"
}
$r7.Close()

$cmd.CommandText = @"
SELECT 'MUTASI-OUT-19' as jenis,
    SUM(t2.qty) as qty,
    SUM(ISNULL(t2.netto_hpp,0)) as nilai_hpp
FROM tstok1 t1, tstok2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t1.tipe_trans = '19'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND ISNULL(t1.order_oke,'N') = 'Y'
  AND ISNULL(t2.qty,0) <> 0
"@
$r8 = $cmd.ExecuteReader()
while ($r8.Read()) {
    $out += "Jenis=$($r8[0]) qty=$($r8[1]) nilai_hpp=$($r8[2])"
}
$r8.Close()

# ===== STEP 6: GL Persediaan KREDIT Jan 2026 detail - find discrepancy ====
$out += ""
$out += "=== STEP 6: GL Persediaan KREDIT Jan 2026 by account ==="
$cmd.CommandText = @"
SELECT j.account_id, a.AccountDes,
    SUM(j.kredit) as total_kredit,
    COUNT(*) as cnt
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND j.kredit > 0
GROUP BY j.account_id, a.AccountDes
ORDER BY total_kredit DESC
"@
$r9 = $cmd.ExecuteReader()
$out += "account_id | description | total_kredit | cnt"
while ($r9.Read()) {
    $out += "$($r9[0]) | $($r9[1]) | $($r9[2]) | $($r9[3])"
}
$r9.Close()

# ===== STEP 7: Compare tsales2.hpp vs SINV-based HPP average (identify changed items) =====
$out += ""
$out += "=== STEP 7: HPP Average recalculation check - top 20 items by diff ==="
$cmd.CommandText = @"
SELECT TOP 20 p.produk_id, p.produk_desc,
    SUM(t2.qty) as jual_qty,
    SUM(t2.qty * ISNULL(t2.hpp,0)) as jual_nilai_current_hpp,
    AVG(ISNULL(t2.hpp,0)) as avg_hpp_current,
    CASE WHEN (ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0) - ISNULL(beli.ret_beli,0)) <> 0
         THEN (ISNULL(aw.awal_rp,0) + ISNULL(beli_rp.beli,0) + ISNULL(beli_rp.mutasi_in,0) + ISNULL(beli_rp.ekspedisi,0) + ISNULL(rj.ret_jual_rp,0) - ISNULL(beli_rp.ret_beli,0)) /
              (ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0) - ISNULL(beli.ret_beli,0))
         ELSE 0 END AS hpp_avg_formula,
    SUM(t2.qty) * (
       CASE WHEN (ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0) - ISNULL(beli.ret_beli,0)) <> 0
            THEN (ISNULL(aw.awal_rp,0) + ISNULL(beli_rp.beli,0) + ISNULL(beli_rp.mutasi_in,0) + ISNULL(beli_rp.ekspedisi,0) + ISNULL(rj.ret_jual_rp,0) - ISNULL(beli_rp.ret_beli,0)) /
                 (ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0) - ISNULL(beli.ret_beli,0))
            ELSE 0 END
    ) as jual_nilai_formula_hpp,
    SUM(t2.qty * ISNULL(t2.hpp,0)) - SUM(t2.qty) * (
       CASE WHEN (ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0) - ISNULL(beli.ret_beli,0)) <> 0
            THEN (ISNULL(aw.awal_rp,0) + ISNULL(beli_rp.beli,0) + ISNULL(beli_rp.mutasi_in,0) + ISNULL(beli_rp.ekspedisi,0) + ISNULL(rj.ret_jual_rp,0) - ISNULL(beli_rp.ret_beli,0)) /
                 (ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0) - ISNULL(beli.ret_beli,0))
            ELSE 0 END
    ) as selisih_hpp
FROM tsales1 t1
JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
JOIN im_produk p ON p.produk_id = t2.stok_id
LEFT OUTER JOIN (
   SELECT stok_id, SUM(qty) AS awal, SUM(nilai) AS awal_rp FROM sinv
   WHERE MONTH(periode) = 1 AND YEAR(periode) = 2026 GROUP BY stok_id
) aw ON p.produk_id = aw.stok_id
LEFT OUTER JOIN (
   SELECT t2b.stok_id,
      SUM(CASE WHEN t1b.tipe_trans='02' THEN t2b.qty ELSE 0 END) AS beli,
      SUM(CASE WHEN t1b.tipe_trans='12' THEN t2b.qty ELSE 0 END) AS ret_beli,
      SUM(CASE WHEN t1b.tipe_trans='09' THEN t2b.qty ELSE 0 END) AS mutasi_in
   FROM tstok1 t1b, tstok2 t2b
   WHERE t1b.bukti_id = t2b.bukti_id AND t1b.tgl BETWEEN '2026-01-01' AND '2026-01-31'
     AND ISNULL(t1b.order_oke,'N') = 'Y' AND ISNULL(t2b.qty,0) <> 0
   GROUP BY t2b.stok_id
) beli ON p.produk_id = beli.stok_id
LEFT OUTER JOIN (
   SELECT t2b.stok_id,
      SUM(CASE WHEN t1b.tipe_trans='02' THEN t2b.netto*ISNULL(t1b.kurs,1) ELSE 0 END) AS beli,
      SUM(CASE WHEN t1b.tipe_trans='12' THEN ABS(t2b.netto_hpp) ELSE 0 END) AS ret_beli,
      SUM(CASE WHEN t1b.tipe_trans='09' THEN t2b.netto ELSE 0 END) AS mutasi_in,
      SUM(CASE WHEN t1b.tipe_trans='05' THEN ABS(t2b.biaya_ekspedisi)*ABS(ISNULL(t2b.qty,0)) ELSE 0 END) AS ekspedisi
   FROM tstok1 t1b, tstok2 t2b
   WHERE t1b.bukti_id = t2b.bukti_id AND t1b.tgl BETWEEN '2026-01-01' AND '2026-01-31'
     AND ISNULL(t1b.order_oke,'N') = 'Y' AND ISNULL(t2b.qty,0) <> 0
   GROUP BY t2b.stok_id
) beli_rp ON p.produk_id = beli_rp.stok_id
LEFT OUTER JOIN (
   SELECT t2b.stok_id,
      SUM(CASE WHEN t1b.tipe_trans IN ('32','26','36') THEN t2b.qty ELSE 0 END) AS ret_jual,
      SUM(CASE WHEN t1b.tipe_trans IN ('32','26','36') THEN ABS(t2b.netto*ISNULL(t1b.kurs,1)) ELSE 0 END) AS ret_jual_rp
   FROM tsales1 t1b, tsales2 t2b
   WHERE t1b.bukti_id = t2b.bukti_id AND t1b.tgl BETWEEN '2026-01-01' AND '2026-01-31'
     AND t1b.order_oke = 'Y' AND t1b.tipe_trans IN ('32','26','36')
   GROUP BY t2b.stok_id
) rj ON p.produk_id = rj.stok_id
WHERE t1.tipe_trans = '22'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
  AND ISNULL(t2.qty,0) <> 0
GROUP BY p.produk_id, p.produk_desc, aw.awal, aw.awal_rp, beli.beli, beli.ret_beli, beli.mutasi_in,
         beli_rp.beli, beli_rp.ret_beli, beli_rp.mutasi_in, beli_rp.ekspedisi, rj.ret_jual, rj.ret_jual_rp
HAVING ABS(SUM(t2.qty * ISNULL(t2.hpp,0)) - SUM(t2.qty) * (
       CASE WHEN (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)+ISNULL(rj.ret_jual,0)-ISNULL(beli.ret_beli,0)) <> 0
            THEN (ISNULL(aw.awal_rp,0)+ISNULL(beli_rp.beli,0)+ISNULL(beli_rp.mutasi_in,0)+ISNULL(beli_rp.ekspedisi,0)+ISNULL(rj.ret_jual_rp,0)-ISNULL(beli_rp.ret_beli,0)) /
                 (ISNULL(aw.awal,0)+ISNULL(beli.beli,0)+ISNULL(beli.mutasi_in,0)+ISNULL(rj.ret_jual,0)-ISNULL(beli.ret_beli,0))
            ELSE 0 END
   )) > 100
ORDER BY ABS(selisih_hpp) DESC
"@
$r10 = $cmd.ExecuteReader()
$out += "produk_id | produk_desc | jual_qty | nilai_current | avg_hpp | hpp_formula | nilai_formula | selisih"
while ($r10.Read()) {
    $out += "$($r10[0]) | $($r10[1]) | $($r10[2]) | $($r10[3]) | $($r10[4]) | $($r10[5]) | $($r10[6]) | $($r10[7])"
}
$r10.Close()

# ===== STEP 8: GL kredit persediaan Jan 2026 vs tsales2 HPP total =====
$out += ""
$out += "=== STEP 8: RECONCILIATION SUMMARY ==="
$cmd.CommandText = @"
SELECT SUM(j.kredit) as gl_kredit_persediaan
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND j.kredit > 0
"@
$r11 = $cmd.ExecuteReader()
while ($r11.Read()) {
    $gl_kredit = if ($r11[0] -ne [DBNull]::Value) { [decimal]$r11[0] } else { 0 }
    $out += "Total GL KREDIT Persediaan Jan 2026 = $gl_kredit"
}
$r11.Close()

$cmd.CommandText = @"
SELECT SUM(t2.qty * ISNULL(t2.hpp,0)) as total_jual_hpp
FROM tsales1 t1, tsales2 t2
WHERE t1.bukti_id = t2.bukti_id
  AND t1.tipe_trans = '22'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
  AND ISNULL(t2.qty,0) <> 0
"@
$r12 = $cmd.ExecuteReader()
while ($r12.Read()) {
    $out += "Total JUAL (qty*hpp) from tsales2 [tipe_22] = $($r12[0])"
}
$r12.Close()

# STEP 9: SINV check - products where Feb awal <> Jan akhir
$out += ""
$out += "=== STEP 9: SINV per product - Jan vs Feb nilai (top 20 biggest diff) ==="
$cmd.CommandText = @"
SELECT TOP 20 
    ISNULL(jan.stok_id, feb.stok_id) as stok_id,
    ISNULL(jan.jan_nilai,0) as jan_sinv_nilai,
    ISNULL(feb.feb_nilai,0) as feb_sinv_nilai,
    ISNULL(jan.jan_nilai,0) - ISNULL(feb.feb_nilai,0) as sinv_diff
FROM
(SELECT stok_id, SUM(nilai) as jan_nilai FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026 GROUP BY stok_id) jan
FULL OUTER JOIN
(SELECT stok_id, SUM(nilai) as feb_nilai FROM sinv WHERE MONTH(periode)=2 AND YEAR(periode)=2026 GROUP BY stok_id) feb
ON jan.stok_id = feb.stok_id
WHERE ABS(ISNULL(jan.jan_nilai,0) - ISNULL(feb.feb_nilai,0)) > 100
ORDER BY ABS(ISNULL(jan.jan_nilai,0) - ISNULL(feb.feb_nilai,0)) DESC
"@
$r13 = $cmd.ExecuteReader()
$out += "stok_id | sinv_jan_nilai | sinv_feb_nilai | diff"
while ($r13.Read()) {
    $out += "$($r13[0]) | $($r13[1]) | $($r13[2]) | $($r13[3])"
}
$r13.Close()

# STEP 10: tipe_trans list in tstok1 Jan 2026
$out += ""
$out += "=== STEP 10: tstok1 tipe_trans summary Jan 2026 ==="
$cmd.CommandText = @"
SELECT t1.tipe_trans, COUNT(*) as cnt,
    SUM(t2.qty) as qty,
    SUM(ISNULL(t2.netto_hpp,0)) as netto_hpp
FROM tstok1 t1
JOIN tstok2 t2 ON t1.bukti_id = t2.bukti_id
WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND ISNULL(t1.order_oke,'N') = 'Y'
GROUP BY t1.tipe_trans
ORDER BY t1.tipe_trans
"@
$r14 = $cmd.ExecuteReader()
$out += "tipe_trans | cnt | qty | netto_hpp"
while ($r14.Read()) {
    $out += "$($r14[0]) | $($r14[1]) | $($r14[2]) | $($r14[3])"
}
$r14.Close()

# STEP 11: Verify akhir Jan
$out += ""
$out += "=== STEP 11: Computed saldo akhir Jan from GL ==="
$cmd.CommandText = @"
SELECT 
    SUM(g.AmountDebet) - SUM(g.AmountCredit) as sinv_awal_jan,
    (SELECT ISNULL(SUM(j.debet),0) FROM gl_journal j
     JOIN gl_acc a ON a.AccountCode = j.account_id
     WHERE a.FinCatCode='BS2015' AND a.DetailYN='1'
     AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31') as jan_debet,
    (SELECT ISNULL(SUM(j.kredit),0) FROM gl_journal j
     JOIN gl_acc a ON a.AccountCode = j.account_id
     WHERE a.FinCatCode='BS2015' AND a.DetailYN='1'
     AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31') as jan_kredit
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-01-01' AND a.FinCatCode = 'BS2015' AND a.DetailYN = '1'
"@
$r15 = $cmd.ExecuteReader()
while ($r15.Read()) {
    $sinv_awal = [decimal]$r15[0]
    $gl_dr = [decimal]$r15[1]
    $gl_cr = [decimal]$r15[2]
    $akhir_gl = $sinv_awal + $gl_dr - $gl_cr
    $out += "SINV awal Jan=$sinv_awal + GL Jan Dr=$gl_dr - GL Jan Cr=$gl_cr"
    $out += "COMPUTED saldo akhir Jan 2026 (from GL): $akhir_gl"
    $out += "User reported: 9072870161.90"
    $out += "User reported SINV Feb awal: 9072336891"
    $out += "Expected diff (GL akhir Jan - SINV Feb awal): $($akhir_gl - 9072336891)"
}
$r15.Close()

$conn.Close()
$out | Set-Content "c:\BTV\debug\diag105_persediaan_forensic_out.txt" -Encoding UTF8
Write-Host "Done. Results in diag105_persediaan_forensic_out.txt"
