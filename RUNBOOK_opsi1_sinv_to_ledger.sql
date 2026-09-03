-- ============================================================
-- RUNBOOK Opsi 1: Mutasi Stok TR/NR/TB (sinv) = Ledger (GL)
-- Jalankan di dbisql (PROD). TIDAK menyentuh GL. Reversible via backup.
-- Metode: skala NILAI & HPP_AVG per item x (GL_akun_periode / sinv_akun_periode)
-- QTY TETAP (fisik). NR(102-003) faktor~1 -> di-skip. Dibuat 2026-07-28.
-- ============================================================

-- 1) BACKUP baris sinv terdampak
-- DROP TABLE sinv_bak_opsi1;   -- buka bila mengulang
SELECT sv.* INTO sinv_bak_opsi1 FROM sinv sv
  JOIN im_produk pr ON pr.produk_id=sv.stok_id
  JOIN im_product_group gr ON gr.kode_group=pr.group_product
  WHERE gr.persediaan IN ('102-001','102-006') AND sv.periode BETWEEN '2026-01-01' AND '2026-07-01';
COMMIT;

-- 2) UPDATE skala NILAI & HPP_AVG -> = GL (per akun per periode)
UPDATE sinv SET nilai=ROUND(nilai*0.5624818988,2), hpp_avg=ROUND(hpp_avg*0.5624818988,2)
  WHERE periode='2026-01-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.4729235330,2), hpp_avg=ROUND(hpp_avg*0.4729235330,2)
  WHERE periode='2026-02-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.5843687265,2), hpp_avg=ROUND(hpp_avg*0.5843687265,2)
  WHERE periode='2026-03-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.5010873558,2), hpp_avg=ROUND(hpp_avg*0.5010873558,2)
  WHERE periode='2026-04-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.4274911727,2), hpp_avg=ROUND(hpp_avg*0.4274911727,2)
  WHERE periode='2026-05-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.4817166570,2), hpp_avg=ROUND(hpp_avg*0.4817166570,2)
  WHERE periode='2026-06-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.6136825845,2), hpp_avg=ROUND(hpp_avg*0.6136825845,2)
  WHERE periode='2026-07-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-001');
UPDATE sinv SET nilai=ROUND(nilai*0.6799805028,2), hpp_avg=ROUND(hpp_avg*0.6799805028,2)
  WHERE periode='2026-01-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
UPDATE sinv SET nilai=ROUND(nilai*0.6799805028,2), hpp_avg=ROUND(hpp_avg*0.6799805028,2)
  WHERE periode='2026-02-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
UPDATE sinv SET nilai=ROUND(nilai*0.6799805028,2), hpp_avg=ROUND(hpp_avg*0.6799805028,2)
  WHERE periode='2026-03-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
UPDATE sinv SET nilai=ROUND(nilai*0.6799805028,2), hpp_avg=ROUND(hpp_avg*0.6799805028,2)
  WHERE periode='2026-04-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
UPDATE sinv SET nilai=ROUND(nilai*0.6619500750,2), hpp_avg=ROUND(hpp_avg*0.6619500750,2)
  WHERE periode='2026-05-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
UPDATE sinv SET nilai=ROUND(nilai*0.6619500750,2), hpp_avg=ROUND(hpp_avg*0.6619500750,2)
  WHERE periode='2026-06-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
UPDATE sinv SET nilai=ROUND(nilai*0.6619500750,2), hpp_avg=ROUND(hpp_avg*0.6619500750,2)
  WHERE periode='2026-07-01' AND stok_id IN (SELECT pr.produk_id FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-006');
COMMIT;

-- 3) VERIFIKASI: sinv vs GL per akun/periode (gap harus ~0)
SELECT gr.persediaan akun, sv.periode, CAST(SUM(sv.nilai) AS NUMERIC(18,2)) sinv_baru,
  CAST((SELECT SUM(amountdebet-amountcredit) FROM gl_balance WHERE site_id='101' AND period='2026-01-01' AND accountcode=gr.persediaan)
     + (SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal WHERE posting='P' AND account_id=gr.persediaan AND tgl>='2026-01-01' AND tgl<sv.periode) AS NUMERIC(18,2)) gl
FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE gr.persediaan IN ('102-001','102-006') AND sv.periode BETWEEN '2026-01-01' AND '2026-07-01'
GROUP BY gr.persediaan, sv.periode ORDER BY gr.persediaan, sv.periode;

-- ROLLBACK (bila perlu):
-- UPDATE sinv SET nilai=(SELECT b.nilai FROM sinv_bak_opsi1 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id),
--   hpp_avg=(SELECT b.hpp_avg FROM sinv_bak_opsi1 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id)
-- WHERE EXISTS(SELECT 1 FROM sinv_bak_opsi1 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id); COMMIT;
