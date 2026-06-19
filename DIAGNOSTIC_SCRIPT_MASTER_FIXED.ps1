# ==================================================================
# DIAGNOSTIC SCRIPT: Profiling Penjualan Revenue Categories
# ==================================================================
# Purpose: Get REAL data from database untuk validasi formula report
# Database: vsp (Sybase SQL Anywhere 9)
# Credentials: UID=dba, PWD=jakarta
# ==================================================================

Write-Output "========================================================"
Write-Output "DIAGNOSTIC SCRIPT - PENJUALAN CATEGORY PROFILING"
Write-Output "Database: vsp | Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "========================================================"

# Function to execute SQL query
function Execute-SQLQuery {
    param(
        [string]$Query,
        [string]$OutputFile,
        [string]$QueryName
    )

    $tempFile = "$env:TEMP\query_$(Get-Random).sql"
    Set-Content -Path $tempFile -Value $Query -Encoding UTF8

    try {
        Write-Output "Executing $QueryName..."
        & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input $tempFile | Tee-Object $OutputFile
        Write-Output "[OK] $QueryName completed"
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Output "[ERROR] $QueryName failed: $_"
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# ==================================================================
# QUERY 1: PROFILING KOMBINASI penjualan vs group_product - GATE 1
# ==================================================================

Write-Output ""
Write-Output "[GATE 1] PROFILING: Kombinasi penjualan vs group_product"
Write-Output "-" * 60

$query1 = @'
SELECT
    ISNULL(im_product_group.penjualan, 'NULL') as penjualan,
    ISNULL(im_produk.group_product, 'NULL') as group_product,
    COUNT(*) as jumlah_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as total_kotor,
    MIN(tsales1.tgl) as tgl_pertama,
    MAX(tsales1.tgl) as tgl_terakhir
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tipe_trans <> '33'
GROUP BY
    im_product_group.penjualan,
    im_produk.group_product
ORDER BY
    im_product_group.penjualan,
    im_produk.group_product
'@

Execute-SQLQuery -Query $query1 -OutputFile "c:\BTV\debug\diag_penjualan_kombinasi.txt" -QueryName "GATE 1: Mapping"

# ==================================================================
# QUERY 2: AGREGASI group_product - GATE 2
# ==================================================================

Write-Output ""
Write-Output "[GATE 2] INVENTORY: Agregasi group_product dominan"
Write-Output "-" * 60

$query2 = @'
SELECT
    ISNULL(im_produk.group_product, 'NULL') as group_product,
    COUNT(*) as jumlah_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as total_kotor,
    ROUND(CAST(SUM(tsales2.kotor) AS FLOAT) /
          (SELECT SUM(tsales2.kotor) FROM tsales2
           JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
           WHERE tsales1.tipe_trans <> '33') * 100, 2) as pct_dari_total
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
WHERE tsales1.tipe_trans <> '33'
GROUP BY im_produk.group_product
ORDER BY total_kotor DESC
'@

Execute-SQLQuery -Query $query2 -OutputFile "c:\BTV\debug\diag_group_product_agregasi.txt" -QueryName "GATE 2: Inventory"

# ==================================================================
# QUERY 3: ORPHAN CATEGORY AUDIT - GATE 3
# ==================================================================

Write-Output ""
Write-Output "[GATE 3] AUDIT: Orphan Categories (bukan JS/SP/UNIT)"
Write-Output "-" * 60

$query3 = @'
SELECT
    ISNULL(im_produk.group_product, 'NULL') as group_product,
    COUNT(*) as jumlah,
    SUM(tsales2.kotor) as total_kotor
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
WHERE tsales1.tipe_trans <> '33'
  AND im_produk.group_product NOT IN ('JS', 'SP', 'UNIT')
  AND im_produk.group_product IS NOT NULL
GROUP BY im_produk.group_product
ORDER BY total_kotor DESC
'@

Execute-SQLQuery -Query $query3 -OutputFile "c:\BTV\debug\diag_orphan_category.txt" -QueryName "GATE 3: Orphan Audit"

# ==================================================================
# QUERY 4: BALANCE VALIDATION - GATE 4
# ==================================================================

Write-Output ""
Write-Output "[GATE 4] CRITICAL: Invoice yang NOT BALANCE (target: 0 rows)"
Write-Output "-" * 60

$query4 = @'
SELECT TOP 50
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name,
    CAST(SUM(CASE WHEN im_product_group.penjualan=('03') THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as unit_idr,
    CAST(SUM(CASE WHEN im_produk.group_product=('JS') THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as jasa_idr,
    CAST(SUM(CASE WHEN im_produk.group_product=('SP') THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as spare_idr,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_idr,
    CAST(ABS(
        (SUM(CASE WHEN im_product_group.penjualan=('03') THEN tsales2.kotor ELSE 0 END) +
         SUM(CASE WHEN im_produk.group_product=('JS') THEN tsales2.kotor ELSE 0 END) +
         SUM(CASE WHEN im_produk.group_product=('SP') THEN tsales2.kotor ELSE 0 END)) -
        SUM(tsales2.kotor)
    ) AS DECIMAL(18,2)) as variance
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tipe_trans <> '33'
GROUP BY
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name
HAVING ABS(
    (SUM(CASE WHEN im_product_group.penjualan=('03') THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product=('JS') THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product=('SP') THEN tsales2.kotor ELSE 0 END)) -
    SUM(tsales2.kotor)
) > 1
ORDER BY variance DESC
'@

Execute-SQLQuery -Query $query4 -OutputFile "c:\BTV\debug\diag_balance_not_ok.txt" -QueryName "GATE 4: Balance"

# ==================================================================
# QUERY 5: CURRENCY INTEGRITY - GATE 5
# ==================================================================

Write-Output ""
Write-Output "[GATE 5] CURRENCY: Validasi konversi kurs (multi-currency check)"
Write-Output "-" * 60

$query5 = @'
SELECT TOP 50
    tsales1.bukti_id,
    tsales1.tgl,
    COUNT(DISTINCT tsales1.curr_id) as jml_currency,
    STRING_AGG(DISTINCT tsales1.curr_id, ', ') as currencies,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as total_asli,
    CAST(SUM(tsales2.kotor * ISNULL(tsales1.kurs, 1)) AS DECIMAL(18,2)) as total_idr_correct,
    CAST((SUM(tsales2.kotor) * ISNULL(AVG(tsales1.kurs), 1)) AS DECIMAL(18,2)) as total_idr_wrong,
    CASE
        WHEN ABS(SUM(tsales2.kotor * ISNULL(tsales1.kurs, 1)) -
                (SUM(tsales2.kotor) * ISNULL(AVG(tsales1.kurs), 1))) < 1
        THEN 'OK - Line item conversion'
        ELSE 'MISMATCH - Check kurs handling'
    END as currency_integrity
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
GROUP BY
    tsales1.bukti_id,
    tsales1.tgl
HAVING COUNT(DISTINCT tsales1.curr_id) > 0
ORDER BY jml_currency DESC, tsales1.tgl DESC
'@

Execute-SQLQuery -Query $query5 -OutputFile "c:\BTV\debug\diag_currency_integrity.txt" -QueryName "GATE 5: Currency"

# ==================================================================
# QUERY 6: RECONCILIATION EXISTING REPORT - GATE 6
# ==================================================================

Write-Output ""
Write-Output "[GATE 6] RECONCILIATION: Existing vs New Report Total"
Write-Output "-" * 60

$query6 = @'
SELECT
    'Existing Report' as source,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_total,
    COUNT(*) as jumlah_line,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    MIN(tsales1.tgl) as tgl_awal,
    MAX(tsales1.tgl) as tgl_akhir
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
UNION ALL
SELECT
    'New Report (formula based)' as source,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_total,
    COUNT(*) as jumlah_line,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    MIN(tsales1.tgl) as tgl_awal,
    MAX(tsales1.tgl) as tgl_akhir
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
ORDER BY source
'@

Execute-SQLQuery -Query $query6 -OutputFile "c:\BTV\debug\diag_reconciliation_existing.txt" -QueryName "GATE 6: Reconciliation"

# ==================================================================
# QUERY 7: HISTORICAL REGRESSION TEST - GATE 7
# ==================================================================

Write-Output ""
Write-Output "[GATE 7] HISTORICAL: Regression test 3/6/12 bulan"
Write-Output "-" * 60

$query7 = @'
SELECT
    'Current Month' as period,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as revenue_total
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
  AND YEAR(tsales1.tgl) = YEAR(GETDATE())
  AND MONTH(tsales1.tgl) = MONTH(GETDATE())
UNION ALL
SELECT
    'Last 3 Months' as period,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as revenue_total
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
  AND tsales1.tgl >= DATEADD(MONTH, -3, GETDATE())
UNION ALL
SELECT
    'Last 6 Months' as period,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as revenue_total
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
  AND tsales1.tgl >= DATEADD(MONTH, -6, GETDATE())
UNION ALL
SELECT
    'Last 12 Months' as period,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as revenue_total
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
  AND tsales1.tgl >= DATEADD(MONTH, -12, GETDATE())
ORDER BY
    CASE period
        WHEN 'Current Month' THEN 1
        WHEN 'Last 3 Months' THEN 2
        WHEN 'Last 6 Months' THEN 3
        WHEN 'Last 12 Months' THEN 4
    END
'@

Execute-SQLQuery -Query $query7 -OutputFile "c:\BTV\debug\diag_historical_regression_test.txt" -QueryName "GATE 7: Historical"

# ==================================================================
# QUERY 8: NULL & DATA QUALITY AUDIT - GATE 8
# ==================================================================

Write-Output ""
Write-Output "[GATE 8] DATA QUALITY: NULL audit pada field kritis"
Write-Output "-" * 60

$query8 = @'
SELECT
    COUNT(*) as total_rows,
    COUNT(*) - COUNT(im_produk.group_product) as null_group_product,
    COUNT(*) - COUNT(im_product_group.penjualan) as null_penjualan,
    COUNT(*) - COUNT(tsales2.kotor) as null_kotor,
    COUNT(DISTINCT CASE WHEN im_produk.group_product IS NULL THEN tsales1.bukti_id END) as invoices_with_null_group,
    COUNT(DISTINCT CASE WHEN im_product_group.penjualan IS NULL THEN tsales1.bukti_id END) as invoices_with_null_penjualan,
    SUM(CASE WHEN im_produk.group_product IS NULL THEN tsales2.kotor ELSE 0 END) as amount_missing_group,
    SUM(CASE WHEN im_product_group.penjualan IS NULL THEN tsales2.kotor ELSE 0 END) as amount_missing_penjualan
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
LEFT JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tipe_trans <> '33'
'@

Execute-SQLQuery -Query $query8 -OutputFile "c:\BTV\debug\diag_null_data_quality.txt" -QueryName "GATE 8: Data Quality"

# ==================================================================
# SUMMARY & APPROVAL GATES
# ==================================================================

Write-Output ""
Write-Output "========================================================"
Write-Output "DIAGNOSTIC COMPLETE - 8 GATES"
Write-Output "========================================================"
Write-Output ""
Write-Output "Output files created:"
Write-Output "  [GATE 1] diag_penjualan_kombinasi.txt"
Write-Output "  [GATE 2] diag_group_product_agregasi.txt"
Write-Output "  [GATE 3] diag_orphan_category.txt"
Write-Output "  [GATE 4] diag_balance_not_ok.txt"
Write-Output "  [GATE 5] diag_currency_integrity.txt"
Write-Output "  [GATE 6] diag_reconciliation_existing.txt"
Write-Output "  [GATE 7] diag_historical_regression_test.txt"
Write-Output "  [GATE 8] diag_null_data_quality.txt"
Write-Output ""
Write-Output "Review dengan GATE_SIGNOFF_TEMPLATE_FINAL.md"
Write-Output "========================================================"
