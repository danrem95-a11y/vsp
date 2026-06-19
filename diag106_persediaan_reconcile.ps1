$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out = @()
$out += "=== DIAG106: Persediaan Reconcile - $(Get-Date) ==="

$out += ""
$out += "=== A: gl_balance Feb 2026 for BS2015 accounts (= saldo awal Feb di Balance Sheet) ==="
$cmd.CommandText = @"
SELECT a.AccountCode, a.AccountDes,
    SUM(g.AmountDebet) as Dr,
    SUM(g.AmountCredit) as Cr,
    SUM(g.AmountDebet) - SUM(g.AmountCredit) as saldo
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-02-01'
  AND a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
GROUP BY a.AccountCode, a.AccountDes
ORDER BY saldo DESC
"@
$r = $cmd.ExecuteReader()
$out += "AccountCode | AccountDes | Dr | Cr | Saldo"
$total_feb_saldo = [decimal]0
while ($r.Read()) {
    $saldo = if ($r[4] -ne [DBNull]::Value) { [decimal]$r[4] } else { 0 }
    $total_feb_saldo += $saldo
    $out += "$($r[0]) | $($r[1]) | $($r[2]) | $($r[3]) | $saldo"
}
$r.Close()
$out += "TOTAL Feb 2026 gl_balance BS2015 = $total_feb_saldo"

$out += ""
$out += "=== B: gl_balance Jan 2026 for BS2015 accounts (= saldo awal Jan) ==="
$cmd.CommandText = @"
SELECT a.AccountCode, a.AccountDes,
    SUM(g.AmountDebet) as Dr,
    SUM(g.AmountCredit) as Cr,
    SUM(g.AmountDebet) - SUM(g.AmountCredit) as saldo
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-01-01'
  AND a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
GROUP BY a.AccountCode, a.AccountDes
ORDER BY saldo DESC
"@
$r2 = $cmd.ExecuteReader()
$out += "AccountCode | AccountDes | Dr | Cr | Saldo"
$total_jan_saldo = [decimal]0
while ($r2.Read()) {
    $saldo = if ($r2[4] -ne [DBNull]::Value) { [decimal]$r2[4] } else { 0 }
    $total_jan_saldo += $saldo
    $out += "$($r2[0]) | $($r2[1]) | $($r2[2]) | $($r2[3]) | $saldo"
}
$r2.Close()
$out += "TOTAL Jan 2026 gl_balance BS2015 = $total_jan_saldo"

$out += ""
$out += "=== C: gl_balance by site_id for Feb 2026, BS2015 ==="
$cmd.CommandText = @"
SELECT g.site_id,
    SUM(g.AmountDebet) as Dr,
    SUM(g.AmountCredit) as Cr,
    SUM(g.AmountDebet) - SUM(g.AmountCredit) as saldo
FROM gl_balance g
JOIN gl_acc a ON a.AccountCode = g.AccountCode
WHERE g.Period = '2026-02-01'
  AND a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
GROUP BY g.site_id
ORDER BY saldo DESC
"@
$r3 = $cmd.ExecuteReader()
$out += "site_id | Dr | Cr | Saldo"
while ($r3.Read()) {
    $out += "$($r3[0]) | $($r3[1]) | $($r3[2]) | $($r3[3])"
}
$r3.Close()

$out += ""
$out += "=== D: SINV Feb 2026 nilai by im_product_group ==="
$cmd.CommandText = @"
SELECT g.nama_group, g.persediaan as coa_persediaan,
    COUNT(s.stok_id) as rows,
    SUM(ISNULL(s.qty,0)) as qty,
    SUM(ISNULL(s.nilai,0)) as nilai
FROM sinv s
JOIN im_produk p ON p.produk_id = s.stok_id
JOIN im_product_group g ON g.group_product = p.group_product
WHERE MONTH(s.periode) = 2 AND YEAR(s.periode) = 2026
GROUP BY g.nama_group, g.persediaan
ORDER BY nilai DESC
"@
$r4 = $cmd.ExecuteReader()
$out += "nama_group | coa_persediaan | rows | qty | nilai"
$total_sinv_feb = [decimal]0
while ($r4.Read()) {
    $nilai = if ($r4[4] -ne [DBNull]::Value) { [decimal]$r4[4] } else { 0 }
    $total_sinv_feb += $nilai
    $out += "$($r4[0]) | $($r4[1]) | $($r4[2]) | $($r4[3]) | $nilai"
}
$r4.Close()
$out += "TOTAL SINV Feb 2026 by group = $total_sinv_feb"

$out += ""
$out += "=== E: SINV Jan 2026 nilai by im_product_group ==="
$cmd.CommandText = @"
SELECT g.nama_group, g.persediaan as coa_persediaan,
    COUNT(s.stok_id) as rows,
    SUM(ISNULL(s.qty,0)) as qty,
    SUM(ISNULL(s.nilai,0)) as nilai
FROM sinv s
JOIN im_produk p ON p.produk_id = s.stok_id
JOIN im_product_group g ON g.group_product = p.group_product
WHERE MONTH(s.periode) = 1 AND YEAR(s.periode) = 2026
GROUP BY g.nama_group, g.persediaan
ORDER BY nilai DESC
"@
$r5 = $cmd.ExecuteReader()
$out += "nama_group | coa_persediaan | rows | qty | nilai"
$total_sinv_jan = [decimal]0
while ($r5.Read()) {
    $nilai = if ($r5[4] -ne [DBNull]::Value) { [decimal]$r5[4] } else { 0 }
    $total_sinv_jan += $nilai
    $out += "$($r5[0]) | $($r5[1]) | $($r5[2]) | $($r5[3]) | $nilai"
}
$r5.Close()
$out += "TOTAL SINV Jan 2026 by group = $total_sinv_jan"

$out += ""
$out += "=== F: gl_journal Jan 2026 BS2015 mutasi by account ==="
$cmd.CommandText = @"
SELECT j.account_id, a.AccountDes,
    SUM(j.debet) as Dr,
    SUM(j.kredit) as Cr,
    SUM(j.debet) - SUM(j.kredit) as net_mutasi
FROM gl_journal j
JOIN gl_acc a ON a.AccountCode = j.account_id
WHERE a.FinCatCode = 'BS2015'
  AND a.DetailYN = '1'
  AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY j.account_id, a.AccountDes
ORDER BY net_mutasi
"@
$r6 = $cmd.ExecuteReader()
$out += "account_id | AccountDes | Dr | Cr | Net"
while ($r6.Read()) {
    $out += "$($r6[0]) | $($r6[1]) | $($r6[2]) | $($r6[3]) | $($r6[4])"
}
$r6.Close()

$out += ""
$out += "=== G: Verify saldo akhir Jan per account: gl_bal_jan + gl_mutasi_jan ==="
$cmd.CommandText = @"
SELECT bal.AccountCode, acc.AccountDes,
    (bal.saldo_awal + ISNULL(mut.dr,0) - ISNULL(mut.cr,0)) as saldo_akhir_jan,
    bal.saldo_awal,
    ISNULL(mut.dr,0) as jan_dr,
    ISNULL(mut.cr,0) as jan_cr
FROM (
    SELECT g.AccountCode,
           SUM(g.AmountDebet) - SUM(g.AmountCredit) as saldo_awal
    FROM gl_balance g
    JOIN gl_acc a ON a.AccountCode = g.AccountCode
    WHERE g.Period = '2026-01-01'
      AND a.FinCatCode = 'BS2015'
      AND a.DetailYN = '1'
    GROUP BY g.AccountCode
) bal
JOIN gl_acc acc ON acc.AccountCode = bal.AccountCode
LEFT OUTER JOIN (
    SELECT j.account_id,
           SUM(j.debet) as dr,
           SUM(j.kredit) as cr
    FROM gl_journal j
    JOIN gl_acc a ON a.AccountCode = j.account_id
    WHERE a.FinCatCode = 'BS2015'
      AND a.DetailYN = '1'
      AND j.tgl BETWEEN '2026-01-01' AND '2026-01-31'
    GROUP BY j.account_id
) mut ON mut.account_id = bal.AccountCode
ORDER BY saldo_akhir_jan DESC
"@
$r7 = $cmd.ExecuteReader()
$out += "AccountCode | AccountDes | SaldoAkhirJan | SaldoAwalJan | JanDr | JanCr"
$total_akhir_jan = [decimal]0
while ($r7.Read()) {
    $s = if ($r7[2] -ne [DBNull]::Value) { [decimal]$r7[2] } else { 0 }
    $total_akhir_jan += $s
    $out += "$($r7[0]) | $($r7[1]) | $s | $($r7[3]) | $($r7[4]) | $($r7[5])"
}
$r7.Close()
$out += "TOTAL GL saldo akhir Jan 2026 = $total_akhir_jan"

$out += ""
$out += "=== H: Spare parts (TS/L/TL/NDS) SINV Feb 2026 total ==="
$cmd.CommandText = @"
SELECT SUM(ISNULL(s.nilai,0)) as nilai_spareparts
FROM sinv s
JOIN im_produk p ON p.produk_id = s.stok_id
WHERE MONTH(s.periode) = 2 AND YEAR(s.periode) = 2026
  AND (p.produk_id LIKE 'TS.%' OR p.produk_id LIKE 'TL.%' OR p.produk_id LIKE 'L.%' OR p.produk_id LIKE 'NDS.%' OR p.produk_id LIKE 'MT.%')
"@
$r8 = $cmd.ExecuteReader()
while ($r8.Read()) {
    $out += "Spare parts only SINV Feb 2026 = $($r8[0])"
}
$r8.Close()

$conn.Close()

$out | Out-File -FilePath "c:\BTV\debug\diag106_persediaan_reconcile_out.txt" -Encoding UTF8
Write-Host "Done. Output: c:\BTV\debug\diag106_persediaan_reconcile_out.txt"
