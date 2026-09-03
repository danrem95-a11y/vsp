-- ============================================================
-- EVIDENCE #1 : PERIOD ISOLATION  (refresh bulan M tak mengubah bulan lain)
-- Jalankan di COPY-DB. Target contoh: Juli 2026 (bulan='2026-07', opening berikut='2026-08-01').
-- PASS = STEP 4 KOSONG.
-- ============================================================
CREATE TABLE _iso_snap (tag varchar(4), scope varchar(12), k varchar(90), amt numeric(24,2), PRIMARY KEY(tag,scope,k));

-- ===== STEP 1 : snapshot SEBELUM refresh (semua bulan KECUALI target) =====
DELETE FROM _iso_snap WHERE tag='BEF';
INSERT INTO _iso_snap   -- GL per (akun, bulan) untuk semua bulan != Juli 2026
 SELECT 'BEF','GL', account_id + '|' + convert(varchar(7),tgl,120), sum(debet)-sum(kredit)
 FROM gl_journal WHERE convert(varchar(7),tgl,120) <> '2026-07'
 GROUP BY account_id, convert(varchar(7),tgl,120);
INSERT INTO _iso_snap   -- SINV per periode KECUALI opening Agustus (=closing Juli, memang boleh berubah)
 SELECT 'BEF','SINV', convert(varchar(10),periode,120), sum(nilai)
 FROM sinv WHERE periode <> '2026-08-01' GROUP BY periode;
COMMIT;

-- ===== STEP 2 : jalankan REFRESH JULI 2026 di aplikasi (Refresh Modern) =====

-- ===== STEP 3 : snapshot SESUDAH refresh (jalankan blok ini sesudah refresh) =====
--   DELETE FROM _iso_snap WHERE tag='AFT';
--   INSERT INTO _iso_snap
--    SELECT 'AFT','GL', account_id + '|' + convert(varchar(7),tgl,120), sum(debet)-sum(kredit)
--    FROM gl_journal WHERE convert(varchar(7),tgl,120) <> '2026-07'
--    GROUP BY account_id, convert(varchar(7),tgl,120);
--   INSERT INTO _iso_snap
--    SELECT 'AFT','SINV', convert(varchar(10),periode,120), sum(nilai)
--    FROM sinv WHERE periode <> '2026-08-01' GROUP BY periode;
--   COMMIT;

-- ===== STEP 4 : BANDINGKAN  ->  HARUS KOSONG =====
SELECT b.scope, b.k AS tabel_akun_bulan, b.amt AS sebelum, a.amt AS sesudah, (a.amt-b.amt) AS delta
FROM _iso_snap b JOIN _iso_snap a ON a.scope=b.scope AND a.k=b.k
WHERE b.tag='BEF' AND a.tag='AFT' AND abs(a.amt-b.amt) > 0.01
ORDER BY abs(a.amt-b.amt) DESC;
-- KOSONG = ISOLATION PASS. Ada baris = FAIL (detail: scope, akun|bulan, sebelum, sesudah, delta).

-- bersih: DROP TABLE _iso_snap;
