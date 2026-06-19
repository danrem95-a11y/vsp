# ==================================================================
# DIAGNOSTIC SCRIPT: Profiling Penjualan Revenue Categories
# ==================================================================
# Purpose: Get REAL data from database untuk validasi formula report
# Database: vsp (via ODBC DSN)
# ==================================================================

$dbisql = "C:\Program Files (x86)\SQL Anywhere 11\Bin32\dbisql.exe"
$dsn = "vsp"

Write-Output "========================================================"
Write-Output "DIAGNOSTIC SCRIPT - PRODUCTION DATA GATHERING"
Write-Output "Database: $dsn | Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "dbisql: $dbisql"
Write-Output "========================================================"

# Function to execute SQL query via ODBC DSN
function Execute-SQLQuery {
    param(
        [string]$Query,
        [string]$OutputFile,
        [string]$QueryName,
        [string]$dbisqlPath,
        [string]$dsnName
    )

    $tempFile = "$env:TEMP\query_$(Get-Random).sql"
    Set-Content -Path $tempFile -Value $Query -Encoding UTF8

    try {
        Write-Output "[$QueryName] Executing..."
        & $dbisqlPath -d "DSN=$dsnName" -batch -input $tempFile | Tee-Object $OutputFile
        Write-Output "[$QueryName] ✓ Completed"
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

        # Check if file has content
        $fileSize = (Get-Item $OutputFile -ErrorAction SilentlyContinue).Length
        if ($fileSize -gt 0) {
            Write-Output "[$QueryName] File size: $fileSize bytes"
        } else {
            Write-Output "[$QueryName] WARNING: Output file is empty"
        }
        return $true
    } catch {
        Write-Output "[$QueryName] ✗ Error: $_"
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# ==================================================================
# GATE 1: PROFILING KOMBINASI penjualan vs group_product
# ==================================================================

Write-Output ""
Write-Output "[GATE 1] Mapping: Kombinasi penjualan vs group_product"
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

Execute-SQLQuery -Query $query1 -OutputFile "c:\BTV\debug\diag_penjualan_kombinasi.txt" -QueryName "GATE 1" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 2: AGREGASI group_product
# ==================================================================

Write-Output ""
Write-Output "[GATE 2] Inventory: Agregasi group_product"
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

Execute-SQLQuery -Query $query2 -OutputFile "c:\BTV\debug\diag_group_product_agregasi.txt" -QueryName "GATE 2" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 3: ORPHAN CATEGORY AUDIT
# ==================================================================

Write-Output ""
Write-Output "[GATE 3] Audit: Orphan Categories (bukan JS/SP/UNIT)"
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

Execute-SQLQuery -Query $query3 -OutputFile "c:\BTV\debug\diag_orphan_category.txt" -QueryName "GATE 3" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 4: BALANCE VALIDATION - NOT BALANCE
# ==================================================================

Write-Output ""
Write-Output "[GATE 4] Balance: Invoice NOT BALANCE (target: 0 rows)"
Write-Output "-" * 60

$query4 = @'
SELECT TOP 50
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name,
    CAST(SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as unit_idr,
    CAST(SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as jasa_idr,
    CAST(SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as spare_idr,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_idr,
    CAST(ABS(
        (SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) +
         SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) +
         SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) -
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
    (SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) -
    SUM(tsales2.kotor)
) > 1
ORDER BY variance DESC
'@

Execute-SQLQuery -Query $query4 -OutputFile "c:\BTV\debug\diag_balance_not_ok.txt" -QueryName "GATE 4" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 5: CURRENCY INTEGRITY
# ==================================================================

Write-Output ""
Write-Output "[GATE 5] Currency: Validasi konversi kurs"
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
        THEN 'OK'
        ELSE 'MISMATCH'
    END as currency_status
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
GROUP BY
    tsales1.bukti_id,
    tsales1.tgl
HAVING COUNT(DISTINCT tsales1.curr_id) > 0
ORDER BY jml_currency DESC, tsales1.tgl DESC
'@

Execute-SQLQuery -Query $query5 -OutputFile "c:\BTV\debug\diag_currency_integrity.txt" -QueryName "GATE 5" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 6: RECONCILIATION
# ==================================================================

Write-Output ""
Write-Output "[GATE 6] Reconciliation: Existing vs New Report"
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
    'New Report' as source,
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

Execute-SQLQuery -Query $query6 -OutputFile "c:\BTV\debug\diag_reconciliation_existing.txt" -QueryName "GATE 6" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 7: HISTORICAL REGRESSION
# ==================================================================

Write-Output ""
Write-Output "[GATE 7] Historical: 3/6/12 month regression test"
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

Execute-SQLQuery -Query $query7 -OutputFile "c:\BTV\debug\diag_historical_regression_test.txt" -QueryName "GATE 7" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# GATE 8: DATA QUALITY - NULL AUDIT
# ==================================================================

Write-Output ""
Write-Output "[GATE 8] Data Quality: NULL audit"
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

Execute-SQLQuery -Query $query8 -OutputFile "c:\BTV\debug\diag_null_data_quality.txt" -QueryName "GATE 8" -dbisqlPath $dbisql -dsnName $dsn

# ==================================================================
# SUMMARY
# ==================================================================

Write-Output ""
Write-Output "========================================================"
Write-Output "DIAGNOSTIC EXECUTION COMPLETE"
Write-Output "========================================================"
Write-Output ""
Write-Output "Generated Files:"
Write-Output "  1. diag_penjualan_kombinasi.txt          (GATE 1: Mapping)"
Write-Output "  2. diag_group_product_agregasi.txt       (GATE 2: Inventory)"
Write-Output "  3. diag_orphan_category.txt              (GATE 3: Orphan Audit)"
Write-Output "  4. diag_balance_not_ok.txt               (GATE 4: Balance)"
Write-Output "  5. diag_currency_integrity.txt           (GATE 5: Currency)"
Write-Output "  6. diag_reconciliation_existing.txt      (GATE 6: Reconciliation)"
Write-Output "  7. diag_historical_regression_test.txt   (GATE 7: Historical)"
Write-Output "  8. diag_null_data_quality.txt            (GATE 8: Data Quality)"
Write-Output ""
Write-Output "Location: c:\BTV\debug\"
Write-Output ""
Write-Output "NEXT: Review results and fill GATE_SIGNOFF_TEMPLATE_FINAL.md"
Write-Output "========================================================"
