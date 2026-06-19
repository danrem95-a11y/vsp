$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG107: Persediaan Selisih Final Proof - $(Get-Date) ==="

$out += ""
$out += "=== A: SINV Feb 2026 total for TR products (stok_id LIKE 'TR.%') ==="
$cmd.CommandText = @"
SELECT COUNT(*) as rows,
    SUM(ISNULL(qty,0)) as qty,
    SUM(ISNULL(nilai,0)) as nilai
FROM sinv
WHERE MONTH(periode) = 2 AND YEAR(periode) = 2026
  AND stok_id LIKE 'TR.%'
"@
$r = $cmd.ExecuteReader()
while ($r.Read()) {
    $sinv_tr_feb = if ($r[2] -ne [DBNull]::Value) { [decimal]$r[2] } else { 0 }
    $out += "SINV Feb 2026 TR products: rows=$($r[0]) qty=$($r[1]) nilai=$sinv_tr_feb"
}
$r.Close()

$out += ""
$out += "=== B: GL saldo akhir Jan 2026 for account 102-001 ==="
$out += "(= gl_balance Jan Dr - gl_balance Jan Cr + gl_journal Jan Dr - gl_journal Jan Cr)"
$cmd.CommandText = @"
SELECT (bal.AmountDebet - bal.AmountCredit + ISNULL(mut.dr,0) - ISNULL(mut.cr,0)) as saldo_akhir_jan,
       bal.AmountDebet - bal.AmountCredit as saldo_awal_jan,
       ISNULL(mut.dr,0) as jan_dr,
       ISNULL(mut.cr,0) as jan_cr
FROM (
    SELECT SUM(AmountDebet) as AmountDebet, SUM(AmountCredit) as AmountCredit
    FROM gl_balance
    WHERE AccountCode = '102-001' AND Period = '2026-01-01'
) bal,
(
    SELECT SUM(debet) as dr, SUM(kredit) as cr
    FROM gl_journal
    WHERE account_id = '102-001'
      AND tgl BETWEEN '2026-01-01' AND '2026-01-31'
) mut
"@
$r2 = $cmd.ExecuteReader()
while ($r2.Read()) {
    $gl_akhir = if ($r2[0] -ne [DBNull]::Value) { [decimal]$r2[0] } else { 0 }
    $out += "GL saldo akhir Jan 102-001 = $gl_akhir"
    $out += "  (awal=$($r2[1]) + dr=$($r2[2]) - cr=$($r2[3]))"
}
$r2.Close()

$out += ""
$out += "=== C: SELISIH = GL saldo akhir Jan vs SINV Feb TR total ==="
$cmd.CommandText = @"
SELECT
    (bal.saldo_awal + ISNULL(mut.dr,0) - ISNULL(mut.cr,0)) as gl_akhir_jan,
    sinv_feb.nilai as sinv_feb_nilai,
    (bal.saldo_awal + ISNULL(mut.dr,0) - ISNULL(mut.cr,0)) - sinv_feb.nilai as selisih
FROM
  (SELECT SUM(AmountDebet) - SUM(AmountCredit) as saldo_awal
   FROM gl_balance WHERE AccountCode = '102-001' AND Period = '2026-01-01') bal,
  (SELECT SUM(debet) as dr, SUM(kredit) as cr
   FROM gl_journal WHERE account_id = '102-001'
   AND tgl BETWEEN '2026-01-01' AND '2026-01-31') mut,
  (SELECT SUM(ISNULL(nilai,0)) as nilai
   FROM sinv WHERE MONTH(periode)=2 AND YEAR(periode)=2026
   AND stok_id LIKE 'TR.%') sinv_feb
"@
$r3 = $cmd.ExecuteReader()
while ($r3.Read()) {
    $out += "GL saldo akhir Jan 102-001 = $($r3[0])"
    $out += "SINV Feb 2026 TR total    = $($r3[1])"
    $out += "SELISIH                   = $($r3[2])"
}
$r3.Close()

$out += ""
$out += "=== D: GL journal Jan 2026 for 102-001 by modul_id and show_hide ==="
$cmd.CommandText = @"
SELECT modul_id, show_hide,
    SUM(debet) as Dr,
    SUM(kredit) as Cr,
    COUNT(*) as cnt
FROM gl_journal
WHERE account_id = '102-001'
  AND tgl BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY modul_id, show_hide
ORDER BY Cr DESC
"@
$r4 = $cmd.ExecuteReader()
$out += "modul_id | show_hide | Dr | Cr | cnt"
while ($r4.Read()) {
    $out += "$($r4[0]) | $($r4[1]) | $($r4[2]) | $($r4[3]) | $($r4[4])"
}
$r4.Close()

$out += ""
$out += "=== E: tsales2 HPP vs SINV-based formula for TR products (show diff only) ==="
$cmd.CommandText = @"
SELECT TOP 10 t2.stok_id,
    SUM(t2.qty) as jual_qty,
    SUM(t2.qty * ISNULL(t2.hpp,0)) as nilai_current_hpp,
    ISNULL(aw.awal,0) as sinv_qty,
    ISNULL(aw.awal_rp,0) as sinv_rp,
    CASE WHEN ISNULL(aw.awal,0) <> 0 THEN ISNULL(aw.awal_rp,0) / ISNULL(aw.awal,0) ELSE 0 END as sinv_hpp_avg,
    AVG(ISNULL(t2.hpp,0)) as tsales2_hpp_avg
FROM tsales1 t1, tsales2 t2
LEFT OUTER JOIN (
    SELECT stok_id, SUM(qty) AS awal, SUM(nilai) AS awal_rp
    FROM sinv WHERE MONTH(periode)=1 AND YEAR(periode)=2026
    GROUP BY stok_id
) aw ON aw.stok_id = t2.stok_id
WHERE t1.bukti_id = t2.bukti_id
  AND t1.tipe_trans = '22'
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.order_oke = 'Y'
  AND t2.stok_id LIKE 'TR.%'
GROUP BY t2.stok_id, aw.awal, aw.awal_rp
HAVING ABS(AVG(ISNULL(t2.hpp,0)) - CASE WHEN ISNULL(aw.awal,0)<>0 THEN ISNULL(aw.awal_rp,0)/ISNULL(aw.awal,0) ELSE 0 END) > 1
ORDER BY ABS(AVG(ISNULL(t2.hpp,0)) - CASE WHEN ISNULL(aw.awal,0)<>0 THEN ISNULL(aw.awal_rp,0)/ISNULL(aw.awal,0) ELSE 0 END) DESC
"@
$r5 = $cmd.ExecuteReader()
$out += "stok_id | jual_qty | nilai_current | sinv_qty | sinv_rp | sinv_hpp | tsales2_hpp"
while ($r5.Read()) {
    $out += "$($r5[0]) | $($r5[1]) | $($r5[2]) | $($r5[3]) | $($r5[4]) | $($r5[5]) | $($r5[6])"
}
$r5.Close()

$out += ""
$out += "=== F: SINV Jan 2026 for TR products (awal Jan) ==="
$cmd.CommandText = @"
SELECT stok_id,
    SUM(ISNULL(qty,0)) as qty,
    SUM(ISNULL(nilai,0)) as nilai,
    AVG(ISNULL(hpp_avg,0)) as hpp_avg
FROM sinv
WHERE MONTH(periode) = 1 AND YEAR(periode) = 2026
  AND stok_id LIKE 'TR.%'
GROUP BY stok_id
ORDER BY nilai DESC
"@
$r6 = $cmd.ExecuteReader()
$out += "stok_id | qty | nilai | hpp_avg"
while ($r6.Read()) {
    $out += "$($r6[0]) | $($r6[1]) | $($r6[2]) | $($r6[3])"
}
$r6.Close()

$conn.Close()

$out | Out-File -FilePath "c:\BTV\debug\diag107_tr_proof_out.txt" -Encoding UTF8
Write-Host "Done. Output: c:\BTV\debug\diag107_tr_proof_out.txt"
