-- ============================================================
-- RUNBOOK PEMULIHAN residu HPP WIP-Out Juli 2026 (unit reefer 102-001)
-- Akar: saat closing (n_cst_closing_stock via refresh modern), CONSOUT_RP di
--   dw_refresh_stok = 0 utk WIP-Out '88' BARU (hpp msh 0 saat closing jalan)
--   -> hppx meledak -> sinv.hpp_avg rusak -> menular ke tsales2/tstok2 Juli.
-- Fix ENGINE sudah dipasang: n_cst_closing_stock.sru pre-compute '88' (.bak_88precompute).
--   Fix itu MENCEGAH residu baru; runbook ini MEMULIHKAN yg terlanjur rusak.
-- Basis pemulihan = avg-cost AWAL Juli (sinv periode 2026-07-01) = HPP WIP-Out BEKU
--   yg TERVERIFIKASI benar (cocok 100% dgn baseline Fase 1 hari ini, per rupiah).
-- Data-only. GL TIDAK disentuh. Jalankan di dbisql. 2026-07-30.
-- ============================================================

-- daftar 9 unit reefer yg korup Juli (Jul-01 avg = frozen cost yg benar)
-- TR.038A TR.039A TR.040A TR.1002A TR.1003A TR.1004A TR.1006A TR.1007A TR.910A

-- (opsional) CEK dulu: basis Jul-01 vs nilai Juli skrg (harus beda utk yg korup)
SELECT s2.stok_id, s1.tipe_trans, COUNT(*) n, CAST(MAX(s2.hpp) AS NUMERIC(18,2)) hpp_juli_skrg,
   CAST((SELECT SUM(hpp_avg) FROM sinv WHERE stok_id=s2.stok_id AND periode='2026-07-01') AS NUMERIC(18,2)) basis_benar
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans IN ('88','22') AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND s2.stok_id IN ('TR.038A','TR.039A','TR.040A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A')
GROUP BY s2.stok_id, s1.tipe_trans ORDER BY s2.stok_id, s1.tipe_trans;

-- ============================================================
-- 1) tsales2.hpp (WIP-Out '88' + Penjualan '22') Juli = avg-cost awal Juli
-- ============================================================
UPDATE tsales2
   SET hpp = ISNULL(BASE.HRG,0.00)
  FROM tsales2, tsales1,
       ( SELECT STOK_ID, SUM(HPP_AVG) AS HRG FROM SINV WHERE PERIODE='2026-07-01' GROUP BY STOK_ID ) BASE
 WHERE tsales2.stok_id = BASE.STOK_ID AND
       tsales2.bukti_id = tsales1.bukti_id AND
       tsales1.tipe_trans IN ('88','22') AND
       ISNULL(tsales2.evap,'') <> '' AND
       tsales1.tgl BETWEEN '2026-07-01' AND '2026-07-31' AND
       tsales2.stok_id IN ('TR.038A','TR.039A','TR.040A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A');
COMMIT;

-- ============================================================
-- 2) tstok2 (WIP-In '88') Juli = avg-cost awal Juli (hpp/hrg/netto/kotor/netto_hpp)
-- ============================================================
UPDATE tstok2
   SET hpp   = ISNULL(BASE.HRG,0.00),
       hrg   = ISNULL(BASE.HRG,0.00),
       netto = ROUND(ISNULL(BASE.HRG,0.00) * qty, 2),
       kotor = ROUND(ISNULL(BASE.HRG,0.00) * qty, 2),
       netto_hpp = ROUND(ISNULL(BASE.HRG,0.00) * qty, 2)
  FROM tstok2, tstok1,
       ( SELECT STOK_ID, SUM(HPP_AVG) AS HRG FROM SINV WHERE PERIODE='2026-07-01' GROUP BY STOK_ID ) BASE
 WHERE tstok2.stok_id = BASE.STOK_ID AND
       tstok2.bukti_id = tstok1.bukti_id AND
       tstok1.tipe_trans = '88' AND
       tstok1.tgl BETWEEN '2026-07-01' AND '2026-07-31' AND
       tstok2.stok_id IN ('TR.038A','TR.039A','TR.040A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A');
COMMIT;

-- ============================================================
-- 3) sinv periode Agustus (2026-08-01) = saldo akhir Juli: hpp_avg = basis, nilai = qty x basis
--    (qty TIDAK diubah - sudah benar)
-- ============================================================
UPDATE sinv
   SET hpp_avg = ISNULL((SELECT SUM(HPP_AVG) FROM sinv b WHERE b.stok_id=sinv.stok_id AND b.periode='2026-07-01'),0),
       nilai   = ROUND(sinv.qty * ISNULL((SELECT SUM(HPP_AVG) FROM sinv b WHERE b.stok_id=sinv.stok_id AND b.periode='2026-07-01'),0), 2)
 WHERE sinv.periode='2026-08-01'
   AND sinv.stok_id IN ('TR.038A','TR.039A','TR.040A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A');
COMMIT;

-- ============================================================
-- 4) VERIFIKASI: semua baris Juli per stok = SATU nilai (basis), tak ada lagi yg meledak/negatif
-- ============================================================
SELECT s2.stok_id, s1.tipe_trans, COUNT(*) n,
       CAST(MIN(s2.hpp) AS NUMERIC(18,2)) hpp_min, CAST(MAX(s2.hpp) AS NUMERIC(18,2)) hpp_max
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans IN ('88','22') AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND s2.stok_id IN ('TR.038A','TR.039A','TR.040A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A')
GROUP BY s2.stok_id, s1.tipe_trans ORDER BY s2.stok_id, s1.tipe_trans;

SELECT stok_id, CAST(qty AS NUMERIC(18,2)) qty, CAST(hpp_avg AS NUMERIC(18,2)) hpp_avg, CAST(nilai AS NUMERIC(18,2)) nilai
FROM sinv WHERE periode='2026-08-01'
  AND stok_id IN ('TR.038A','TR.039A','TR.040A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A')
ORDER BY stok_id;
