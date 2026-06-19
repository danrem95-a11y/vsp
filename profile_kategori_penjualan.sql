-- PROFILING: Kombinasi group_product dan penjualan
-- Tujuan: Mengidentifikasi SEMUA kombinasi yang ada di database
-- Sebelum membuat formula filtering

SELECT
    im_product_group.penjualan,
    im_produk.group_product,
    COUNT(*) as jumlah_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as total_kotor,
    MIN(tsales2.kotor) as min_kotor,
    MAX(tsales2.kotor) as max_kotor,
    AVG(tsales2.kotor) as avg_kotor,
    MIN(tsales1.tgl) as tgl_pertama,
    MAX(tsales1.tgl) as tgl_terakhir
FROM
    tsales2
    JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
    JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
    JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE
    tsales1.tgl >= DATE('2026-01-01')
    AND tsales1.tipe_trans <> '33'
    AND ISNULL(tsales2.qty, 0) <> 0
GROUP BY
    im_product_group.penjualan,
    im_produk.group_product
ORDER BY
    im_product_group.penjualan,
    im_produk.group_product;

-- ============================================
-- Secondary: Cek apakah ada penjualan code yang tidak mapping ke group_product
-- ============================================

SELECT
    im_product_group.penjualan,
    im_product_group.nama_group,
    COUNT(*) as jumlah_product,
    COUNT(DISTINCT im_product_group.kode_group) as jumlah_group_product
FROM
    im_product_group
WHERE
    im_product_group.penjualan IS NOT NULL
    AND im_product_group.penjualan <> ''
GROUP BY
    im_product_group.penjualan,
    im_product_group.nama_group
ORDER BY
    im_product_group.penjualan;

-- ============================================
-- Tertiary: Sample data untuk validasi manual
-- (Ambil 20 invoice terakhir)
-- ============================================

SELECT TOP 20
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_id,
    mcust.cust_name,
    COUNT(DISTINCT tsales2.seq) as jumlah_line,
    SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) as unit_total,
    SUM(CASE WHEN im_product_group.penjualan='03' AND im_produk.group_product='UNIT' THEN tsales2.kotor ELSE 0 END) as unit_verify,
    SUM(CASE WHEN im_product_group.penjualan='01' AND im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) as jasa_total,
    SUM(CASE WHEN (im_product_group.penjualan='01' OR im_product_group.penjualan='02') AND im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END) as spare_total,
    SUM(tsales2.kotor) as kotor_total,
    (SUM(CASE WHEN im_product_group.penjualan='03' THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_product_group.penjualan='01' AND im_produk.group_product='JS' THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN (im_product_group.penjualan='01' OR im_product_group.penjualan='02') AND im_produk.group_product='SP' THEN tsales2.kotor ELSE 0 END)) as sum_kategori
FROM
    tsales1
    JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
    JOIN mcust ON tsales1.cust_id = mcust.cust_id
    JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
    JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE
    tsales1.tgl >= DATE('2026-01-01')
    AND tsales1.tipe_trans <> '33'
    AND ISNULL(tsales2.qty, 0) <> 0
GROUP BY
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_id,
    mcust.cust_name
ORDER BY
    tsales1.bukti_id DESC;
