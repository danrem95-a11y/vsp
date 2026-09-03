-- ============================================================
-- IDEMPOTENCY_metric.sql — metrik numerik: "Rows Updated per kelas", pass #1 vs #2.
--   Metrik = jumlah baris yang NILAI hpp-nya BERUBAH (bukan sekadar disentuh SQL).
--   Bukti terkuat idempotensi: pass #2 -> semua kelas = 0.
--
-- CATATAN idempotensi teknis vs bisnis (untuk poin #4 Pak Wira):
--   Beberapa proses menulis-ulang nilai SAMA tiap pass (S-D/S-E set hpp=nilai identik;
--   sinv ditulis ulang; WIP-In di-delete+reinsert). Itu "pembaruan teknis" yg TIDAK
--   mengubah NILAI. Metrik di sini mengukur PERUBAHAN NILAI -> 0 = idempotent secara bisnis.
-- ============================================================

-- Tabel snapshot berlabel (sekali buat)
CREATE TABLE _snap_idem (
   label varchar(4), bukti_id varchar(15), urut integer,
   kelas varchar(10), hpp double,
   PRIMARY KEY (label, bukti_id, urut) );

-- Prosedur perekaman (ulang untuk tiap label): ganti :LBL = 'PRE' | 'P1' | 'P2'
--   PRE = sebelum cutover (opsional, utk angka pass #1)
--   P1  = sesudah Refresh Jan->Des #1
--   P2  = sesudah Refresh Jan->Des #2
DELETE FROM _snap_idem WHERE label='P2';   -- <<< ganti label sesuai tahap
INSERT INTO _snap_idem
SELECT 'P2',                                -- <<< ganti label sesuai tahap
       s2.bukti_id, s2.urut,
       (CASE WHEN s1.tipe_trans='88' AND ISNULL(s2.evap,'')<>'' THEN 'WIP_OUT'
             WHEN s1.tipe_trans IN ('22','32','26','36') AND ISNULL(s2.evap,'')<>'' THEN 'WIP_SALE'
             WHEN s1.tipe_trans IN ('22','32','26','36') AND ISNULL(s2.evap,'')='' THEN 'NON_WIP'
             ELSE 'LAIN' END),
       s2.hpp
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tgl BETWEEN '2026-01-01' AND '2026-12-31'
  AND s1.tipe_trans IN ('22','32','26','36','88');
COMMIT;

-- ---------- LAPORAN A : churn pass #1  (PRE -> P1) ----------
SELECT 'PASS #1 (PRE->P1)' fase, a.kelas,
       SUM(CASE WHEN ABS(ISNULL(b.hpp,0)-ISNULL(a.hpp,0))>0.01 THEN 1 ELSE 0 END) AS rows_nilai_berubah
FROM _snap_idem a JOIN _snap_idem b ON b.label='P1' AND b.bukti_id=a.bukti_id AND b.urut=a.urut
WHERE a.label='PRE' AND a.kelas IN ('WIP_OUT','WIP_SALE','NON_WIP')
GROUP BY a.kelas ORDER BY a.kelas;

-- ---------- LAPORAN B : IDEMPOTENSI pass #2  (P1 -> P2)  => HARUS 0 semua ----------
SELECT 'PASS #2 (P1->P2)' fase, a.kelas,
       SUM(CASE WHEN ABS(ISNULL(b.hpp,0)-ISNULL(a.hpp,0))>0.01 THEN 1 ELSE 0 END) AS rows_nilai_berubah
FROM _snap_idem a JOIN _snap_idem b ON b.label='P2' AND b.bukti_id=a.bukti_id AND b.urut=a.urut
WHERE a.label='P1' AND a.kelas IN ('WIP_OUT','WIP_SALE','NON_WIP')
GROUP BY a.kelas ORDER BY a.kelas;
-- Kriteria idempotent: LAPORAN B => WIP_OUT=0, WIP_SALE=0, NON_WIP=0.

-- ---------- LAPORAN C : drill baris yg berubah di pass #2 (harus kosong) ----------
SELECT a.kelas, a.bukti_id, a.urut,
       CAST(a.hpp AS NUMERIC(18,2)) hpp_p1, CAST(b.hpp AS NUMERIC(18,2)) hpp_p2
FROM _snap_idem a JOIN _snap_idem b ON b.label='P2' AND b.bukti_id=a.bukti_id AND b.urut=a.urut
WHERE a.label='P1' AND ABS(ISNULL(b.hpp,0)-ISNULL(a.hpp,0))>0.01
ORDER BY a.kelas, a.bukti_id;

-- DROP TABLE _snap_idem;
