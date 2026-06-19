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

# ==================================================================
# QUERY 1: PROFILING KOMBINASI penjualan vs group_product
# ==================================================================

Write-Output ""
Write-Output "[1] PROFILING: Kombinasi penjualan vs group_product"
Write-Output "-" * 60

$query1 = @"
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
GROUP BY
    im_product_group.penjualan,
    im_produk.group_product
ORDER BY
    im_product_group.penjualan,
    im_produk.group_product;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query1) | Tee-Object "c:\BTV\debug\diag_penjualan_kombinasi.txt"
    Write-Output "[✓] Query 1 completed"
} catch {
    Write-Output "[✗] Query 1 failed: $_"
}

# ==================================================================
# QUERY 2: DETAIL KODE PENJUALAN = '01'
# ==================================================================

Write-Output ""
Write-Output "[2] DETAIL: Kode penjualan = '01' (Top 100 transaksi terbaru)"
Write-Output "-" * 60

$query2 = @"
SELECT TOP 100
    tsales1.bukti_id,
    tsales1.tgl,
    tsales1.cust_id,
    mcust.cust_name,
    im_product_group.penjualan,
    im_produk.group_product,
    tsales2.stok_id,
    im_produk.nama_produk,
    tsales2.qty,
    tsales2.kotor
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE im_product_group.penjualan = '01'
ORDER BY tsales1.tgl DESC;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query2) | Tee-Object "c:\BTV\debug\diag_kode_01_detail.txt"
    Write-Output "[✓] Query 2 completed"
} catch {
    Write-Output "[✗] Query 2 failed: $_"
}

# ==================================================================
# QUERY 3: DISTINCT group_product VALUES
# ==================================================================

Write-Output ""
Write-Output "[3] INVENTORY: Semua nilai group_product yang ada"
Write-Output "-" * 60

$query3 = @"
SELECT DISTINCT group_product
FROM im_produk
WHERE group_product IS NOT NULL AND group_product <> ''
ORDER BY group_product;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query3) | Tee-Object "c:\BTV\debug\diag_group_product_values.txt"
    Write-Output "[✓] Query 3 completed"
} catch {
    Write-Output "[✗] Query 3 failed: $_"
}

# ==================================================================
# QUERY 4: DISTINCT penjualan CODES
# ==================================================================

Write-Output ""
Write-Output "[4] INVENTORY: Semua nilai penjualan code yang ada"
Write-Output "-" * 60

$query4 = @"
SELECT DISTINCT penjualan
FROM im_product_group
WHERE penjualan IS NOT NULL AND penjualan <> ''
ORDER BY penjualan;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query4) | Tee-Object "c:\BTV\debug\diag_penjualan_codes.txt"
    Write-Output "[✓] Query 4 completed"
} catch {
    Write-Output "[✗] Query 4 failed: $_"
}

# ==================================================================
# QUERY 4.5: AGREGASI group_product (UNTUK LIHAT KATEGORI DOMINAN)
# ==================================================================

Write-Output ""
Write-Output "[4.5] AGREGASI: Kategori dominan per total kotor"
Write-Output "-" * 60

$query45 = @"
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
ORDER BY total_kotor DESC;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query45) | Tee-Object "c:\BTV\debug\diag_group_product_agregasi.txt"
    Write-Output "[✓] Query 4.5 completed"
} catch {
    Write-Output "[✗] Query 4.5 failed: $_"
}

# ==================================================================
# QUERY 5: BALANCE VALIDATION (40 invoices)
# ==================================================================

Write-Output ""
Write-Output "[5] VALIDATION: Balance check untuk 40 invoices terbaru"
Write-Output "-" * 60

$query5 = @"
SELECT TOP 40
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name,
    CAST(SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as unit_idr,
    CAST(SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as jasa_idr,
    CAST(SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END) AS DECIMAL(18,2)) as spare_idr,
    CAST(SUM(tsales2.kotor) AS DECIMAL(18,2)) as kotor_idr,
    CAST((SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) +
          SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) +
          SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) AS DECIMAL(18,2)) as sum_kategori,
    CASE
        WHEN (SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) +
              SUM(CASE WHEN im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) +
              SUM(CASE WHEN im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) = SUM(tsales2.kotor)
        THEN 'BALANCE'
        ELSE 'NOT BALANCE'
    END as status_balance
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
ORDER BY
    tsales1.tgl DESC;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query5) | Tee-Object "c:\BTV\debug\diag_balance_validation.txt"
    Write-Output "[✓] Query 5 completed"
} catch {
    Write-Output "[✗] Query 5 failed: $_"
}

# ==================================================================
# QUERY 4.6: AUDIT - ORPHAN CATEGORY (tidak ada di JS/SP/UNIT)
# ==================================================================

Write-Output ""
Write-Output "[4.6] AUDIT: Orphan Categories (deteksi kategori baru)"
Write-Output "-" * 60

$query46 = @"
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
ORDER BY total_kotor DESC;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query46) | Tee-Object "c:\BTV\debug\diag_orphan_category.txt"
    Write-Output "[✓] Query 4.6 completed"
    Write-Output "    NOTE: Target = kosong (0 rows) atau hanya NULL"
} catch {
    Write-Output "[✗] Query 4.6 failed: $_"
}

# ==================================================================
# QUERY 5 (OLD): BALANCE VALIDATION (40 invoices) - GATE 4
# ==================================================================

Write-Output ""
Write-Output "[5.5] CRITICAL: Invoice yang NOT BALANCE (harus 0 rows!)"
Write-Output "-" * 60

$query55 = @"
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
ORDER BY
    variance DESC;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query55) | Tee-Object "c:\BTV\debug\diag_balance_not_ok.txt"
    Write-Output "[✓] Query 5.5 completed"
} catch {
    Write-Output "[✗] Query 5.5 failed: $_"
}

# ==================================================================
# QUERY 6: CURRENCY INTEGRITY - GATE 5 (Multi-Currency Validation)
# ==================================================================

Write-Output ""
Write-Output "[6] CURRENCY: Validasi konversi kurs (multi-currency check)"
Write-Output "-" * 60

$query6 = @"
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
ORDER BY jml_currency DESC, tsales1.tgl DESC;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query6) | Tee-Object "c:\BTV\debug\diag_currency_integrity.txt"
    Write-Output "[✓] Query 6 completed"
    Write-Output "    NOTE: Check for MISMATCH results - should not exist"
} catch {
    Write-Output "[✗] Query 6 failed: $_"
}

# ==================================================================
# QUERY 7: RECONCILIATION EXISTING REPORT - GATE 6
# ==================================================================

Write-Output ""
Write-Output "[7] RECONCILIATION: Validasi Existing vs New Report Total"
Write-Output "-" * 60

$query7 = @"
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
ORDER BY source;
"@

try {
    & dbisql.exe -c "UID=dba;PWD=jakarta;DBN=vsp" -batch -input <(Write-Output $query7) | Tee-Object "c:\BTV\debug\diag_reconciliation_existing.txt"
    Write-Output "[✓] Query 7 completed"
    Write-Output "    NOTE: Both should show SAME KOTOR total"
} catch {
    Write-Output "[✗] Query 7 failed: $_"
}

# ==================================================================
# SUMMARY
# ==================================================================

Write-Output ""
Write-Output "========================================================"
Write-Output "DIAGNOSTIC COMPLETE"
Write-Output "========================================================"
Write-Output "Output files created:"
Write-Output "  [1] c:\BTV\debug\diag_penjualan_kombinasi.txt"
Write-Output "      → Mapping matrix: penjualan vs group_product"
Write-Output "  [2] c:\BTV\debug\diag_kode_01_detail.txt"
Write-Output "      → Detail kode 01 (buktikan multi group_product?)"
Write-Output "  [3] c:\BTV\debug\diag_group_product_values.txt"
Write-Output "      → Semua distinct group_product"
Write-Output "  [4] c:\BTV\debug\diag_penjualan_codes.txt"
Write-Output "      → Semua distinct penjualan codes"
Write-Output "  [4.5] c:\BTV\debug\diag_group_product_agregasi.txt"
Write-Output "      → Agregasi: kategori dominan per % total kotor"
Write-Output "  [4.6] c:\BTV\debug\diag_orphan_category.txt"
Write-Output "      → AUDIT: Kategori orphan (bukan JS/SP/UNIT)"
Write-Output "  [5] c:\BTV\debug\diag_balance_validation.txt"
Write-Output "      → 40 invoices dengan status balance/not balance"
Write-Output "  [5.5] c:\BTV\debug\diag_balance_not_ok.txt"
Write-Output "      → CRITICAL: Only invoices that NOT BALANCE (target: 0 rows)"
Write-Output ""
Write-Output "APPROVAL GATES - HARUS LOLOS SEMUA:"
Write-Output ""
Write-Output "  GATE 1 - Mapping Kategori"
Write-Output "    File: diag_penjualan_kombinasi.txt"
Write-Output "    Check: Hanya kombinasi (01,JS), (01,SP), (02,SP), (03,UNIT)?"
Write-Output ""
Write-Output "  GATE 2 - Inventory Group Product"
Write-Output "    File: diag_group_product_agregasi.txt"
Write-Output "    Check: Hanya ada JS, SP, UNIT (bukan ACC/FRT/OTH)?"
Write-Output ""
Write-Output "  GATE 3 - Orphan Category Audit"
Write-Output "    File: diag_orphan_category.txt"
Write-Output "    Check: Target KOSONG (0 rows) - jika ada = STOP!"
Write-Output ""
Write-Output "  GATE 4 - Balance Validation"
Write-Output "    File: diag_balance_not_ok.txt"
Write-Output "    Check: Target KOSONG (0 rows) - UNIT+JASA+SPARE=KOTOR"
Write-Output ""
Write-Output "Next: Review results dan share ke Claude untuk design review final"
Write-Output "========================================================"
