-- ============================================================
-- EVIDENCE #3 : IDEMPOTENCY  (Refresh Juli ke-2 = ke-1, tak ada duplicate/perubahan)
--   Jalankan di COPY-DB. PASS = STEP 4 KOSONG (semua metric delta 0).
-- ============================================================
CREATE TABLE _idem_snap (tag varchar(4), metric varchar(30), val numeric(26,2), PRIMARY KEY(tag,metric));

-- ===== STEP 1 : sesudah REFRESH JULI ke-1, rekam checksum =====
DELETE FROM _idem_snap WHERE tag='R1';
INSERT INTO _idem_snap VALUES ('R1','GL_JUL_DEBET',  (SELECT isnull(sum(debet),0)  FROM gl_journal WHERE tgl BETWEEN '2026-07-01' AND '2026-07-31'));
INSERT INTO _idem_snap VALUES ('R1','GL_JUL_KREDIT', (SELECT isnull(sum(kredit),0) FROM gl_journal WHERE tgl BETWEEN '2026-07-01' AND '2026-07-31'));
INSERT INTO _idem_snap VALUES ('R1','GL_JUL_VOUCHER',(SELECT count(DISTINCT voucher) FROM gl_journal WHERE tgl BETWEEN '2026-07-01' AND '2026-07-31'));
INSERT INTO _idem_snap VALUES ('R1','GL_JUL_ROWS',   (SELECT count(*) FROM gl_journal WHERE tgl BETWEEN '2026-07-01' AND '2026-07-31'));
INSERT INTO _idem_snap VALUES ('R1','SINV_AGU_NILAI',(SELECT isnull(sum(nilai),0) FROM sinv WHERE periode='2026-08-01'));
INSERT INTO _idem_snap VALUES ('R1','HPP_JUL',       (SELECT isnull(sum(s2.hpp*s2.qty),0) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'));
COMMIT;

-- ===== STEP 2 : jalankan REFRESH JULI 2026 LAGI (tanpa ubah data lain) =====

-- ===== STEP 3 : rekam lagi dgn tag 'R2' (ulangi 6 INSERT di atas, ganti 'R1' -> 'R2') =====

-- ===== STEP 4 : BANDINGKAN -> HARUS KOSONG =====
SELECT a.metric, a.val AS refresh_1, b.val AS refresh_2, (b.val-a.val) AS delta
FROM _idem_snap a JOIN _idem_snap b ON a.metric=b.metric AND a.tag='R1' AND b.tag='R2'
WHERE abs(b.val-a.val) > 0.01
ORDER BY a.metric;
-- KOSONG = IDEMPOTENT PASS. GL_JUL_VOUCHER & GL_JUL_ROWS delta 0 = tak ada duplicate journal.

-- bersih: DROP TABLE _idem_snap;
