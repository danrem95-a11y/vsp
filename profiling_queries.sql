-- ===========================================================
-- QUERY 1: PROFILING KOMBINASI penjualan vs group_product
-- ===========================================================

SELECT
    im_product_group.penjualan,
    im_produk.group_product,
    COUNT(*) as jumlah_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as total_kotor
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

-- ===========================================================
-- QUERY 2: DETAIL KODE 01 (Top 100)
-- ===========================================================

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

-- ===========================================================
-- QUERY 3: DISTINCT group_product values
-- ===========================================================

SELECT DISTINCT group_product
FROM im_produk
ORDER BY group_product;

-- ===========================================================
-- QUERY 4: DISTINCT penjualan codes
-- ===========================================================

SELECT DISTINCT penjualan
FROM im_product_group
ORDER BY penjualan;

-- ===========================================================
-- QUERY 5: BALANCE VALIDATION (40 invoices)
-- ===========================================================

SELECT TOP 40
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name,
    SUM(CASE WHEN im_product_group.penjualan='03' 
            THEN tsales2.kotor ELSE 0 END) as unit_idr,
    SUM(CASE WHEN im_produk.group_product='JS' 
            THEN tsales2.kotor ELSE 0 END) as jasa_idr,
    SUM(CASE WHEN im_produk.group_product='SP' 
            THEN tsales2.kotor ELSE 0 END) as spare_idr,
    SUM(tsales2.kotor) as kotor_idr,
    (SUM(CASE WHEN im_product_group.penjualan='03' 
             THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product='JS' 
             THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product='SP' 
             THEN tsales2.kotor ELSE 0 END)) as sum_kategori,
    CASE 
        WHEN (SUM(CASE WHEN im_product_group.penjualan='03' 
                       THEN tsales2.kotor ELSE 0 END) +
              SUM(CASE WHEN im_produk.group_product='JS' 
                       THEN tsales2.kotor ELSE 0 END) +
              SUM(CASE WHEN im_produk.group_product='SP' 
                       THEN tsales2.kotor ELSE 0 END)) = SUM(tsales2.kotor)
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
