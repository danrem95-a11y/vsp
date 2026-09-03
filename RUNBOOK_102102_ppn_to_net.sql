-- RUNBOOK: koreksi 102-102 S.Parts - buang PPN dari nilai sinv (movement Juni)
-- Pak Wira: nilai benar = net (trans_mut). GL sudah benar (PPN di 104-111). Data-only, 2026-07-01. 2026-07-29
-- DROP TABLE sinv_bak_102102;
SELECT * INTO sinv_bak_102102 FROM sinv WHERE periode='2026-07-01' AND stok_id IN ('TL.011-9671','TL.030-0275','TL.011-9649','TL.011-9648');
COMMIT;

UPDATE sinv SET nilai=3513513.54, hpp_avg=1171171.18 WHERE periode='2026-07-01' AND stok_id='TL.011-9671';
UPDATE sinv SET nilai=4637162.17, hpp_avg=2318581.08 WHERE periode='2026-07-01' AND stok_id='TL.030-0275';
UPDATE sinv SET nilai=601351.32, hpp_avg=200450.44 WHERE periode='2026-07-01' AND stok_id='TL.011-9649';
UPDATE sinv SET nilai=601351.35, hpp_avg=200450.45 WHERE periode='2026-07-01' AND stok_id='TL.011-9648';
COMMIT;

-- VERIFIKASI (gap ~0)
SELECT CAST(SUM(sv.nilai) AS NUMERIC(18,2)) sinv_baru, CAST((SELECT SUM(amountdebet-amountcredit) FROM gl_balance WHERE site_id='101' AND period='2026-01-01' AND accountcode='102-102')+(SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal WHERE posting='P' AND account_id='102-102' AND tgl>='2026-01-01' AND tgl<'2026-07-01') AS NUMERIC(18,2)) gl FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE gr.persediaan='102-102' AND sv.periode='2026-07-01';
