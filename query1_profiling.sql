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
