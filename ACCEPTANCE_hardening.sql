-- ============================================================
-- ACCEPTANCE TEST HARDENING Refresh Modern (T1-T4). Jalankan di COPY-DB, bukan prod.
-- ============================================================

-- ===== T1: Opening tahun = Closing tahun lalu (kontinuitas batas tahun; yang diperbaiki al_replace=1) =====
-- Opening 2026 (sinv 2026-01-01) HARUS = GL closing 2025 (gl_balance[2025] + movement 2025) per akun persediaan.
-- Anomali > Rp1 = putus kontinuitas (phantom opening). Setelah year-close al_replace=1 -> harus KOSONG.
SELECT g.acc,
  CAST(ISNULL(sv.sinv,0) AS NUMERIC(20,2))                     AS opening_2026_sinv,
  CAST(ISNULL(op.opn,0)+ISNULL(mv.mov,0) AS NUMERIC(20,2))     AS closing_2025_gl,
  CAST(ISNULL(sv.sinv,0)-(ISNULL(op.opn,0)+ISNULL(mv.mov,0)) AS NUMERIC(20,2)) AS selisih
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE ISNULL(persediaan,'')<>'') g
LEFT JOIN ( SELECT gr.persediaan acc, SUM(s.nilai) sinv
            FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id
                        JOIN im_product_group gr ON gr.kode_group=pr.group_product
            WHERE s.periode='2026-01-01' GROUP BY gr.persediaan ) sv ON sv.acc=g.acc
LEFT JOIN ( SELECT AccountCode acc, SUM(AmountDebet)-SUM(AmountCredit) opn
            FROM gl_balance WHERE Period='2025-01-01' GROUP BY AccountCode ) op ON op.acc=g.acc
LEFT JOIN ( SELECT account_id acc, SUM(debet)-SUM(kredit) mov
            FROM gl_journal WHERE tgl BETWEEN '2025-01-01' AND '2025-12-31' GROUP BY account_id ) mv ON mv.acc=g.acc
WHERE ABS(ISNULL(sv.sinv,0)-(ISNULL(op.opn,0)+ISNULL(mv.mov,0))) > 1
ORDER BY ABS(ISNULL(sv.sinv,0)-(ISNULL(op.opn,0)+ISNULL(mv.mov,0))) DESC;

-- ===== T2: Refresh bulan M, bulan LAIN tidak berubah (month isolation) =====
-- Langkah: sebelum refresh Juli, rekam checksum bulan Juni. Sesudah refresh Juli, rekam lagi. Bandingkan.
-- STEP A (sebelum refresh Juli):
CREATE TABLE _acc_snap (tag varchar(10), akun varchar(12), gl numeric(20,2), PRIMARY KEY(tag,akun));
DELETE FROM _acc_snap WHERE tag='JUN_BEF';
INSERT INTO _acc_snap SELECT 'JUN_BEF', account_id, cast(sum(debet)-sum(kredit) as numeric(20,2))
  FROM gl_journal WHERE tgl BETWEEN '2026-06-01' AND '2026-06-30' GROUP BY account_id;
COMMIT;
-- STEP B (sesudah refresh Juli): ulang dgn tag 'JUN_AFT', lalu:
-- SELECT * FROM _acc_snap a JOIN _acc_snap b ON a.akun=b.akun AND a.tag='JUN_BEF' AND b.tag='JUN_AFT'
--   WHERE ABS(a.gl-b.gl)>0.01;   --> HARUS KOSONG (Juni tak berubah oleh refresh Juli)

-- ===== T3: Idempotent — refresh Juli 10x, GL/stok/HPP sama =====
-- checksum sebelum/sesudah refresh ke-N (gunakan IDEMPOTENCY_metric.sql). Δ = 0.
SELECT 'T3 checksum Juli' t,
  (SELECT cast(sum(debet)-sum(kredit) as numeric(22,2)) FROM gl_journal WHERE tgl BETWEEN '2026-07-01' AND '2026-07-31') gl_jul,
  (SELECT cast(sum(nilai) as numeric(22,2)) FROM sinv WHERE periode='2026-08-01') sinv_agu,
  (SELECT cast(sum(hpp) as numeric(22,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tgl BETWEEN '2026-07-01' AND '2026-07-31') hpp_jul;
-- Jalankan query ini sebelum & sesudah tiap refresh ulang → ketiga angka HARUS identik.

-- ===== T4: Cross-module = GL =====
-- INV-01 (SINV=GL), INV-03 (WIP=102-020), INV-04 (CONS out=in): lihat INVARIANT_CHECKER.sql (semua kosong).
-- AR=GL / AP=GL: jalankan allrecon.ps1 / allrecon_julext.ps1 (opname vs ledger) → dalam toleransi.

-- bersih-bersih: DROP TABLE _acc_snap;
