# DIAGNOSTIC SCRIPT - All 8 Gates
# Database: vsp (via ODBC DSN)

$dbisql = "C:\Program Files (x86)\SQL Anywhere 11\Bin32\dbisql.exe"
$dsn = "vsp"
$outDir = "c:\BTV\debug"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTIC SCRIPT - PRODUCTION DATA GATHERING" -ForegroundColor Cyan
Write-Host "Database: $dsn | Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

function Run-Query {
    param([string]$name, [string]$sql, [string]$outfile)

    $sqlFile = "$env:TEMP\q_$name.sql"
    $sql | Out-File -FilePath $sqlFile -Encoding UTF8

    Write-Host "`n[$name] Running..." -ForegroundColor Yellow
    & $dbisql -d "DSN=$dsn" -batch -input $sqlFile | Tee-Object $outfile
    Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue
    Write-Host "[$name] Done -> $outfile" -ForegroundColor Green
}

# GATE 1
$q1 = "SELECT ISNULL(im_product_group.penjualan, 'NULL') as penjualan, ISNULL(im_produk.group_product, 'NULL') as group_product, COUNT(*) as jumlah, COUNT(DISTINCT tsales1.bukti_id) as invoices, SUM(tsales2.kotor) as total FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group WHERE tsales1.tipe_trans <> '33' GROUP BY im_product_group.penjualan, im_produk.group_product ORDER BY im_product_group.penjualan, im_produk.group_product"
Run-Query "GATE1" $q1 "$outDir\diag_penjualan_kombinasi.txt"

# GATE 2
$q2 = "SELECT ISNULL(im_produk.group_product, 'NULL') as group_product, COUNT(*) as count, SUM(tsales2.kotor) as total, ROUND(CAST(SUM(tsales2.kotor) AS FLOAT) / (SELECT SUM(tsales2.kotor) FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id WHERE tsales1.tipe_trans <> '33') * 100, 2) as pct FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id WHERE tsales1.tipe_trans <> '33' GROUP BY im_produk.group_product ORDER BY total DESC"
Run-Query "GATE2" $q2 "$outDir\diag_group_product_agregasi.txt"

# GATE 3
$q3 = "SELECT ISNULL(im_produk.group_product, 'NULL') as group_product, COUNT(*) as count, SUM(tsales2.kotor) as total FROM tsales2 JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id WHERE tsales1.tipe_trans <> '33' AND im_produk.group_product NOT IN ('JS', 'SP', 'UNIT') AND im_produk.group_product IS NOT NULL GROUP BY im_produk.group_product ORDER BY total DESC"
Run-Query "GATE3" $q3 "$outDir\diag_orphan_category.txt"

# GATE 4
$q4 = "SELECT TOP 50 tsales1.bukti_id, tsales1.tgl, mcust.cust_name, CAST(SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as unit_idr, CAST(SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as jasa_idr, CAST(SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as spare_idr, CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_idr, CAST(ABS((SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) - SUM(tsales2.kotor)) AS DECIMAL(18,2)) as variance FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id JOIN mcust ON tsales1.cust_id = mcust.cust_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group WHERE tsales1.tipe_trans <> '33' GROUP BY tsales1.bukti_id, tsales1.tgl, mcust.cust_name HAVING ABS((SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) + SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) - SUM(tsales2.kotor)) > 1 ORDER BY variance DESC"
Run-Query "GATE4" $q4 "$outDir\diag_balance_not_ok.txt"

# GATE 5
$q5 = "SELECT TOP 50 tsales1.bukti_id, tsales1.tgl, COUNT(DISTINCT tsales1.curr_id) as currency_count, STRING_AGG(DISTINCT tsales1.curr_id, ', ') as currencies, CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as total_asli, CAST(SUM(tsales2.kotor * ISNULL(tsales1.kurs, 1)) AS DECIMAL(18,2)) as correct, CAST((SUM(tsales2.kotor) * ISNULL(AVG(tsales1.kurs), 1)) AS DECIMAL(18,2)) as wrong, CASE WHEN ABS(SUM(tsales2.kotor * ISNULL(tsales1.kurs, 1)) - (SUM(tsales2.kotor) * ISNULL(AVG(tsales1.kurs), 1))) < 1 THEN 'OK' ELSE 'MISMATCH' END as status FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' GROUP BY tsales1.bukti_id, tsales1.tgl HAVING COUNT(DISTINCT tsales1.curr_id) > 0 ORDER BY currency_count DESC"
Run-Query "GATE5" $q5 "$outDir\diag_currency_integrity.txt"

# GATE 6
$q6 = "SELECT 'Existing' as source, CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as total, COUNT(DISTINCT tsales1.bukti_id) as invoices FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' UNION ALL SELECT 'New', CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)), COUNT(DISTINCT tsales1.bukti_id) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' ORDER BY source"
Run-Query "GATE6" $q6 "$outDir\diag_reconciliation_existing.txt"

# GATE 7
$q7 = "SELECT 'Current Month' as period, COUNT(DISTINCT tsales1.bukti_id) as invoices, SUM(tsales2.kotor) as revenue FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND YEAR(tsales1.tgl) = YEAR(GETDATE()) AND MONTH(tsales1.tgl) = MONTH(GETDATE()) UNION ALL SELECT 'Last 3M', COUNT(DISTINCT tsales1.bukti_id), SUM(tsales2.kotor) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -3, GETDATE()) UNION ALL SELECT 'Last 6M', COUNT(DISTINCT tsales1.bukti_id), SUM(tsales2.kotor) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -6, GETDATE()) UNION ALL SELECT 'Last 12M', COUNT(DISTINCT tsales1.bukti_id), SUM(tsales2.kotor) FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id WHERE tsales1.tipe_trans <> '33' AND tsales1.tgl >= DATEADD(MONTH, -12, GETDATE())"
Run-Query "GATE7" $q7 "$outDir\diag_historical_regression_test.txt"

# GATE 8
$q8 = "SELECT COUNT(*) as total, COUNT(*) - COUNT(im_produk.group_product) as null_gp, COUNT(*) - COUNT(im_product_group.penjualan) as null_pj, COUNT(DISTINCT CASE WHEN im_produk.group_product IS NULL THEN tsales1.bukti_id END) as inv_null_gp, COUNT(DISTINCT CASE WHEN im_product_group.penjualan IS NULL THEN tsales1.bukti_id END) as inv_null_pj, SUM(CASE WHEN im_produk.group_product IS NULL THEN tsales2.kotor ELSE 0 END) as amt_null_gp, SUM(CASE WHEN im_product_group.penjualan IS NULL THEN tsales2.kotor ELSE 0 END) as amt_null_pj FROM tsales1 JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id JOIN im_produk ON tsales2.stok_id = im_produk.produk_id LEFT JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group WHERE tsales1.tipe_trans <> '33'"
Run-Query "GATE8" $q8 "$outDir\diag_null_data_quality.txt"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "ALL 8 GATES COMPLETE" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated 8 diagnostic files in: $outDir" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT: Review files and complete GATE_SIGNOFF_TEMPLATE_FINAL.md" -ForegroundColor Yellow
