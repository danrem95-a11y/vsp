-- ============================================================
-- ACCEPTANCE_journal_authority.sql — bukti I8 (Single HPP Authority se-sistem)
--   Membuktikan: menjalankan REFRESH LAMA (w_refresh_journal) TIDAK menjadikannya
--   penulis HPP kedua. Journal memanggil NVO yang sama + penulis bersainnya (R6/R7)
--   OFF via flag -> HPP journal = HPP NVO (idempoten) -> tak ada perubahan.
--
-- Perilaku eksplisit yang diuji: JOURNAL == MODERN (redirect ke otoritas tunggal NVO).
-- ============================================================

-- ---------- STEP 1 : SNAPSHOT HPP baseline (setelah refresh via MODERN) ----------
CREATE TABLE _snap_journal_hpp (
   bukti_id varchar(15), urut integer, stok_id varchar(16),
   evap varchar(20), tipe_trans varchar(4), hpp double,
   PRIMARY KEY (bukti_id, urut) );
DELETE FROM _snap_journal_hpp; COMMIT;
INSERT INTO _snap_journal_hpp
SELECT s2.bukti_id, s2.urut, s2.stok_id, ISNULL(s2.evap,''), s1.tipe_trans, s2.hpp
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND s1.tipe_trans IN ('22','32','26','36','88');
COMMIT;
SELECT count(*) AS baseline_rows FROM _snap_journal_hpp;

-- ---------- STEP 2 : (APLIKASI) REFRESH periode SAMA via w_refresh_journal (window LAMA) ----------
--   (flag ib_nvo_sole_hpp_authority = true -> R6/R7 journal OFF)

-- ---------- STEP 3 : VERIFIKASI journal BUKAN otoritas kedua ----------
-- 3a: berapa baris HPP berubah akibat journal? (harapan = 0)
SELECT 'I8 journal!=authority' uji, count(*) AS baris_hpp_berubah,
       (CASE WHEN count(*)=0 THEN 'LULUS' ELSE 'GAGAL' END) status
FROM _snap_journal_hpp sn JOIN tsales2 cur ON cur.bukti_id=sn.bukti_id AND cur.urut=sn.urut
WHERE ABS(ISNULL(cur.hpp,0)-ISNULL(sn.hpp,0)) > 0.01;

-- 3b: drill-down bila ada yg berubah (harus kosong)
SELECT sn.bukti_id, sn.urut, sn.stok_id, sn.evap, sn.tipe_trans,
       CAST(sn.hpp AS NUMERIC(18,2)) hpp_sebelum_journal,
       CAST(cur.hpp AS NUMERIC(18,2)) hpp_sesudah_journal
FROM _snap_journal_hpp sn JOIN tsales2 cur ON cur.bukti_id=sn.bukti_id AND cur.urut=sn.urut
WHERE ABS(ISNULL(cur.hpp,0)-ISNULL(sn.hpp,0)) > 0.01
ORDER BY sn.stok_id;

-- 3c: setelah refresh journal, DETEKTOR G3 (integritas '88' vs SINV-awal) & G5 (WIP sale=WIP-Out) HARUS 0.
--     (bukti journal tak menimpa nilai beku / tak jadi penulis independen)

-- ---------- Kesimpulan LULUS I8 ----------
--   * 3a = 0 baris berubah  DAN
--   * G3 = 0  DAN  G5 = 0
--   => journal tidak menulis HPP independen; NVO otoritas tunggal se-sistem.

-- DROP TABLE _snap_journal_hpp;
