-- ============================================================
-- RUNBOOK Opsi 1 (lanjutan): Mutasi Stok MT (102-201) = Ledger
-- Jalankan di dbisql (PROD). TIDAK menyentuh GL. Reversible via backup.
-- Skala NILAI & HPP_AVG x (GL/sinv) per periode. QTY tetap. Dibuat 2026-07-28.
-- ============================================================

-- 1) BACKUP
-- DROP TABLE sinv_bak_mt102201;   -- buka bila mengulang
SELECT sv.* INTO sinv_bak_mt102201 FROM sinv sv
  JOIN im_produk pr ON pr.produk_id=sv.stok_id
  JOIN im_product_group gr ON gr.kode_group=pr.group_product
  WHERE gr.persediaan='102-201' AND sv.periode BETWEEN '2026-01-01' AND '2026-07-01';
COMMIT;

-- 2) UPDATE skala NILAI & HPP_AVG -> = GL (per periode)
UPDATE sinv SET nilai=ROUND(nilai*1.2474772361,2), hpp_avg=ROUND(hpp_avg*1.2474772361,2)
  WHERE periode='2026-01-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
UPDATE sinv SET nilai=ROUND(nilai*1.2465578426,2), hpp_avg=ROUND(hpp_avg*1.2465578426,2)
  WHERE periode='2026-02-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
UPDATE sinv SET nilai=ROUND(nilai*1.2478388620,2), hpp_avg=ROUND(hpp_avg*1.2478388620,2)
  WHERE periode='2026-03-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
UPDATE sinv SET nilai=ROUND(nilai*1.2408423459,2), hpp_avg=ROUND(hpp_avg*1.2408423459,2)
  WHERE periode='2026-04-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
UPDATE sinv SET nilai=ROUND(nilai*1.2421121348,2), hpp_avg=ROUND(hpp_avg*1.2421121348,2)
  WHERE periode='2026-05-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
UPDATE sinv SET nilai=ROUND(nilai*1.2381807213,2), hpp_avg=ROUND(hpp_avg*1.2381807213,2)
  WHERE periode='2026-06-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
UPDATE sinv SET nilai=ROUND(nilai*1.2261255100,2), hpp_avg=ROUND(hpp_avg*1.2261255100,2)
  WHERE periode='2026-07-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-201');
COMMIT;

-- 3) VERIFIKASI (gap harus ~0)
SELECT gr.persediaan akun, sv.periode, CAST(SUM(sv.nilai) AS NUMERIC(18,2)) sinv_baru,
  CAST((SELECT SUM(amountdebet-amountcredit) FROM gl_balance WHERE site_id='101' AND period='2026-01-01' AND accountcode=gr.persediaan)
     + (SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal WHERE posting='P' AND account_id=gr.persediaan AND tgl>='2026-01-01' AND tgl<sv.periode) AS NUMERIC(18,2)) gl
FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE gr.persediaan='102-201' AND sv.periode BETWEEN '2026-01-01' AND '2026-07-01'
GROUP BY gr.persediaan, sv.periode ORDER BY sv.periode;

-- ROLLBACK (bila perlu):
-- UPDATE sinv SET nilai=(SELECT b.nilai FROM sinv_bak_mt102201 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id),
--   hpp_avg=(SELECT b.hpp_avg FROM sinv_bak_mt102201 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id)
-- WHERE EXISTS(SELECT 1 FROM sinv_bak_mt102201 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id); COMMIT;
