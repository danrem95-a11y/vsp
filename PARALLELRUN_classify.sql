-- ============================================================
-- PARALLELRUN_classify.sql — bukti EC6 dengan klasifikasi PER-BARIS
--   UNCHANGED / EXPECTED CHANGE (WIP->WIP-Out) / UNEXPECTED CHANGE
-- Menjawab: "kalau hanya checksum berbeda, kita tak tahu perubahannya dari mana."
--
-- ALUR:
--   [MODE LAMA]  (build sekarang, R6/R7 aktif) -> jalankan STEP 1 (rekam snapshot)
--   [BUILD BARU + Refresh periode uji]         (C1-C4, R6/R7 flag OFF)
--   [MODE BARU]  -> jalankan STEP 2 (klasifikasi) & STEP 3 (drill UNEXPECTED)
-- Ganti rentang '2026-01-01'..'2026-12-31' ke periode uji bila perlu.
-- ============================================================

-- ---------- STEP 1 : SNAPSHOT MODE LAMA (sebelum build baru) ----------
-- (dijalankan sekali, di build lama)
CREATE TABLE _snap_tsales2_hpp (
   bukti_id varchar(15), urut integer, stok_id varchar(16),
   evap varchar(20), tipe_trans varchar(4), hpp double,
   PRIMARY KEY (bukti_id, urut) );

DELETE FROM _snap_tsales2_hpp; COMMIT;
INSERT INTO _snap_tsales2_hpp
SELECT s2.bukti_id, s2.urut, s2.stok_id, ISNULL(s2.evap,''), s1.tipe_trans, s2.hpp
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tgl BETWEEN '2026-01-01' AND '2026-12-31'
  AND s1.tipe_trans IN ('22','32','26','36','88');
COMMIT;
SELECT count(*) AS snapshot_rows FROM _snap_tsales2_hpp;

-- ---------- STEP 2 : KLASIFIKASI (setelah build baru + refresh mode baru) ----------
SELECT klas, count(*) AS jml,
       CAST(SUM(ABS(delta)) AS NUMERIC(30,2)) AS total_abs_delta
FROM (
  SELECT snap.bukti_id, snap.urut, snap.evap,
         (ISNULL(cur.hpp,0)-ISNULL(snap.hpp,0)) AS delta,
         (CASE
            WHEN ABS(ISNULL(cur.hpp,0)-ISNULL(snap.hpp,0)) <= 0.01 THEN '1_UNCHANGED'
            WHEN ISNULL(snap.evap,'')<>''
                 AND ABS(ISNULL(cur.hpp,0) - ISNULL(
                       (SELECT MAX(c2.hpp) FROM tsales1 c1 JOIN tsales2 c2 ON c1.bukti_id=c2.bukti_id
                        WHERE c1.tipe_trans='88' AND c2.stok_id=snap.stok_id AND c2.evap=snap.evap
                          AND ISNULL(c2.hpp,0)>0),0)) <= 0.01
              THEN '2_EXPECTED (WIP->WIP-Out)'
            ELSE '3_UNEXPECTED'
          END) AS klas
  FROM _snap_tsales2_hpp snap
  JOIN tsales2 cur ON cur.bukti_id=snap.bukti_id AND cur.urut=snap.urut
) x
GROUP BY klas ORDER BY klas;

-- Kriteria LULUS EC6:
--   * NON-WIP (evap='') : semua di '1_UNCHANGED' (0 baris pindah kelas lain).
--   * WIP (evap<>'')    : hanya '1_UNCHANGED' atau '2_EXPECTED'.
--   * '3_UNEXPECTED'    : HARUS 0. Bila >0 = ada dependensi tersembunyi -> R6/R7 BELUM boleh dihapus.

-- ---------- STEP 3 : DRILL-DOWN baris UNEXPECTED (harus kosong) ----------
SELECT snap.bukti_id, snap.urut, snap.stok_id, snap.evap, snap.tipe_trans,
       CAST(snap.hpp AS NUMERIC(18,2)) hpp_lama,
       CAST(cur.hpp  AS NUMERIC(18,2)) hpp_baru,
       CAST((SELECT MAX(c2.hpp) FROM tsales1 c1 JOIN tsales2 c2 ON c1.bukti_id=c2.bukti_id
             WHERE c1.tipe_trans='88' AND c2.stok_id=snap.stok_id AND c2.evap=snap.evap
               AND ISNULL(c2.hpp,0)>0) AS NUMERIC(18,2)) hpp_wipout_beku,
       (CASE WHEN ISNULL(snap.evap,'')='' THEN 'NON-WIP berubah (langgar EC6)'
             ELSE 'WIP tak ke nilai WIP-Out (selidiki)' END) AS catatan
FROM _snap_tsales2_hpp snap
JOIN tsales2 cur ON cur.bukti_id=snap.bukti_id AND cur.urut=snap.urut
WHERE ABS(ISNULL(cur.hpp,0)-ISNULL(snap.hpp,0)) > 0.01
  AND NOT ( ISNULL(snap.evap,'')<>''
            AND ABS(ISNULL(cur.hpp,0) - ISNULL(
                  (SELECT MAX(c2.hpp) FROM tsales1 c1 JOIN tsales2 c2 ON c1.bukti_id=c2.bukti_id
                   WHERE c1.tipe_trans='88' AND c2.stok_id=snap.stok_id AND c2.evap=snap.evap
                     AND ISNULL(c2.hpp,0)>0),0)) <= 0.01 )
ORDER BY catatan, snap.stok_id;

-- ---------- Bersih-bersih setelah selesai ----------
-- DROP TABLE _snap_tsales2_hpp;
