# FINAL DIAGNOSTIC SCRIPT - All 8 Gates via 32-bit ODBC
# Production Data Gathering for Rekap Penjualan Report Fix

param([string]$OutputDir = "c:\BTV\debug")

$dsn = "vsp"
$uid = "dba"
$pwd = "jakarta"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC SCRIPT - ALL 8 GATES" -ForegroundColor Cyan
Write-Host "Database: $dsn | Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

function ExecuteQuery {
    param([string]$name, [string]$sql, [string]$outfile)

    Write-Host "`n[$name] Running..." -ForegroundColor Yellow

    try {
        $conn = New-Object System.Data.Odbc.OdbcConnection("Driver={Adaptive Server Anywhere 9.0};DSN=$dsn;UID=$uid;PWD=$pwd")
        $conn.Open()

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $reader = $cmd.ExecuteReader()

        $output = @()

        # Get column names
        $cols = @()
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $cols += $reader.GetName($i)
        }
        $output += ($cols -join "`t")

        # Get data
        while ($reader.Read()) {
            $row = @()
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $val = $reader[$i]
                if ($val -eq [DBNull]::Value) { $val = "NULL" }
                $row += $val
            }
            $output += ($row -join "`t")
        }

        $reader.Close()
        $conn.Close()

        # Write to file
        $output | Out-File -FilePath $outfile -Encoding UTF8
        $lines = $output.Count
        Write-Host "[$name] ✓ Complete - $lines rows" -ForegroundColor Green
        Write-Host "[$name] Output: $outfile" -ForegroundColor Gray

    } catch {
        Write-Host "[$name] ✗ Error: $_" -ForegroundColor Red
    }
}

# ==================================================================
# GATE 1: MAPPING penjualan vs group_product
# ==================================================================
$q1 = @'
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
GROUP BY im_product_group.penjualan, im_produk.group_product
ORDER BY im_product_group.penjualan, im_produk.group_product
"@
ExecuteQuery "GATE 1: Mapping" $q1 "$OutputDir\diag_penjualan_kombinasi.txt"

# ==================================================================
# GATE 2: INVENTORY group_product
# ==================================================================
$q2 = @'
SELECT
    ISNULL(im_produk.group_product, 'NULL') as group_product,
    COUNT(*) as jumlah_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as total_kotor,
    ROUND(CAST(SUM(tsales2.kotor) AS FLOAT) / (SELECT SUM(tsales2.kotor) FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id WHERE tsales1.tipe_trans <> '33') * 100, 2) as pct_dari_total
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
WHERE tsales1.tipe_trans <> '33'
GROUP BY im_produk.group_product
ORDER BY total_kotor DESC
"@
ExecuteQuery "GATE 2: Inventory" $q2 "$OutputDir\diag_group_product_agregasi.txt"

# ==================================================================
# GATE 3: ORPHAN CATEGORIES
# ==================================================================
$q3 = @"
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
"@
ExecuteQuery "GATE 3: Orphan Audit" $q3 "$OutputDir\diag_orphan_category.txt"

# ==================================================================
# GATE 4: BALANCE NOT OK
# ==================================================================
$q4 = @"
SELECT TOP 50
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name,
    CAST(SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as unit_idr,
    CAST(SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as jasa_idr,
    CAST(SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as spare_idr,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_idr,
    CAST(ABS((SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) - SUM(tsales2.kotor)) AS DECIMAL(18,2)) as variance
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tipe_trans <> '33'
GROUP BY tsales1.bukti_id, tsales1.tgl, mcust.cust_name
HAVING ABS((SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) - SUM(tsales2.kotor)) > 1
ORDER BY variance DESC
"@
ExecuteQuery "GATE 4: Balance" $q4 "$OutputDir\diag_balance_not_ok.txt"

# ==================================================================
# GATE 5: CURRENCY INTEGRITY
# ==================================================================
$q5 = @"
SELECT TOP 50
    tsales1.bukti_id,
    tsales1.tgl,
    COUNT(DISTINCT tsales1.curr_id) as jml_currency,
    STRING_AGG(DISTINCT tsales1.curr_id, ', ') as currencies,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as total_asli,
    CAST(SUM(tsales2.kotor * ISNULL(tsales1.kurs, 1)) AS DECIMAL(18,2)) as total_idr_correct,
    CAST((SUM(tsales2.kotor) * ISNULL(AVG(tsales1.kurs), 1)) AS DECIMAL(18,2)) as total_idr_wrong,
    CASE WHEN ABS(SUM(tsales2.kotor * ISNULL(tsales1.kurs, 1)) - (SUM(tsales2.kotor) * ISNULL(AVG(tsales1.kurs), 1))) < 1 THEN 'OK' ELSE 'MISMATCH' END as currency_status
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33'
GROUP BY tsales1.bukti_id, tsales1.tgl
HAVING COUNT(DISTINCT tsales1.curr_id) > 0
ORDER BY jml_currency DESC, tsales1.tgl DESC
"@
ExecuteQuery "GATE 5: Currency" $q5 "$OutputDir\diag_currency_integrity.txt"

# ==================================================================
# GATE 6: RECONCILIATION
# ==================================================================
$q6 = @"
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
"@
ExecuteQuery "GATE 6: Reconciliation" $q6 "$OutputDir\diag_reconciliation_existing.txt"

# ==================================================================
# GATE 7: HISTORICAL REGRESSION
# ==================================================================
$q7 = @"
SELECT
    'Current Month' as period,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as revenue_total
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33' AND YEAR(tsales1.tgl) = YEAR(GETDATE()) AND MONTH(tsales1.tgl) = MONTH(GETDATE())
UNION ALL
SELECT 'Last 3 Months', COUNT(DISTINCT tsales1.bukti_id), SUM(tsales2.kotor)
FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -3, GETDATE())
UNION ALL
SELECT 'Last 6 Months', COUNT(DISTINCT tsales1.bukti_id), SUM(tsales2.kotor)
FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -6, GETDATE())
UNION ALL
SELECT 'Last 12 Months', COUNT(DISTINCT tsales1.bukti_id), SUM(tsales2.kotor)
FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -12, GETDATE())
"@
ExecuteQuery "GATE 7: Historical" $q7 "$OutputDir\diag_historical_regression_test.txt"

# ==================================================================
# GATE 8: DATA QUALITY NULL AUDIT
# ==================================================================
$q8 = @"
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
"@
ExecuteQuery "GATE 8: Data Quality" $q8 "$OutputDir\diag_null_data_quality.txt"

# ==================================================================
# SUMMARY
# ==================================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "✓ ALL 8 GATES COMPLETE" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated 8 diagnostic files in: $OutputDir" -ForegroundColor Green
Write-Host ""
Write-Host "Files:" -ForegroundColor Yellow
Get-ChildItem -Path "$OutputDir\diag_*.txt" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } |
    Select-Object Name, @{Name="Size";Expression={"{0:N0}" -f $_.Length}} |
    ForEach-Object { Write-Host "  - $($_.Name) ($($_.Size) bytes)" -ForegroundColor Gray }

Write-Host ""
Write-Host "NEXT: Review files and complete GATE_SIGNOFF_TEMPLATE_FINAL.md" -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan
