-- ============================================================
-- BUKTI ENGINE DETERMINISTIK / IDEMPOTEN (jalankan di COPY-DB)
-- Membuktikan: regenerasi SINV dari engine, dijalankan berkali-kali, hasil IDENTIK & = GL.
-- ============================================================
-- Catatan: dw_refresh_stok = pure SELECT (deterministik by design). Yang diuji = penulisan SINV
--          oleh n_cst_closing_stock. Uji dgn re-close berulang lalu checksum.

CREATE TABLE _idem_sinv (tag varchar(6), akun varchar(12), qty numeric(22,2), nilai numeric(22,2), PRIMARY KEY(tag,akun));

-- ====== RUN #1 : setelah recovery closing pertama ======
-- (jalankan blok ini SESUDAH re-close Des-2025 + re-refresh Jan-Feb yang pertama)
DELETE FROM _idem_sinv WHERE tag='RUN1';
INSERT INTO _idem_sinv
 SELECT 'RUN1', gr.persediaan, sum(s.qty), sum(s.nilai)
 FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
 WHERE s.periode='2026-01-01' GROUP BY gr.persediaan;
COMMIT;

-- ====== RUN #2 : ulangi recovery closing (tanpa ubah transaksi), lalu rekam ======
--   ulangi INSERT dgn tag 'RUN2'  (blok sama, ganti 'RUN1'->'RUN2')

-- ====== BUKTI A: IDEMPOTEN (RUN1 == RUN2) → HARUS KOSONG ======
SELECT a.akun, a.nilai run1, b.nilai run2, (b.nilai-a.nilai) delta
FROM _idem_sinv a JOIN _idem_sinv b ON a.akun=b.akun AND a.tag='RUN1' AND b.tag='RUN2'
WHERE abs(b.nilai-a.nilai) > 0.01 OR abs(b.qty-a.qty) > 0.01;
-- KOSONG = engine idempoten (2x run hasil identik).

-- ====== BUKTI B: SINV baru == GL (≤ Rp1) → hanya baris > Rp1 yang muncul ======
SELECT r.akun, cast(r.nilai as numeric(20,2)) sinv_regen,
  cast(isnull(g.opn,0) as numeric(20,2)) gl,
  cast(r.nilai-isnull(g.opn,0) as numeric(20,2)) gap
FROM _idem_sinv r
LEFT JOIN (SELECT AccountCode acc, sum(AmountDebet-AmountCredit) opn FROM gl_balance WHERE Period='2026-01-01' GROUP BY AccountCode) g ON g.acc=r.akun
WHERE r.tag='RUN1' AND abs(r.nilai-isnull(g.opn,0)) > 1
ORDER BY abs(r.nilai-isnull(g.opn,0)) DESC;
-- Target: hanya 102-201 tersisa (isu GL saldo-awal terpisah). Sisanya ≤ Rp1.

-- bersih: DROP TABLE _idem_sinv;
