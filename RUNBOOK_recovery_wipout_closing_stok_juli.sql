-- ============================================================
-- RUNBOOK PEMULIHAN: HPP WIP-Out Juli 2026 yang rusak akibat bug w_closing_stok.srw
-- Akar masalah: Statement 1 (UPDATE TSALES2, baris ~841) menimpa HPP record '88'
--   (WIP-Out) dengan rata-rata polos SEBELUM Statement 2 ("BY EVAP") sempat
--   membacanya sebagai basis pembetulan -> rantai rusak, semua transaksi Juli per
--   stok_id jadi nilai seragam yang salah. Fix kode SUDAH terpasang (baris 854,
--   backup w_closing_stok.srw.bak_wipexclude) - runbook ini HANYA memulihkan DATA
--   yang sudah terlanjur rusak sebelum fix terpasang.
-- Basis pemulihan: nilai HPP WIP-Out yang TERVERIFIKASI BENAR hari ini (Fase 1,
--   sebelum korupsi terjadi) - nilai ini KONSTAN/beku sejak awal 2026 utk 8 stok ini.
-- Scope: 8 stok_id (TR.040A DIKECUALIKAN - nilainya bergerak/tidak beku, perlu
--   perhitungan terpisah, lihat catatan di akhir file).
-- Data-only. GL TIDAK disentuh. Jalankan di dbisql. 2026-07-30.
-- ============================================================

-- (opsional) cek dulu: berapa baris akan terdampak per stok, SEBELUM update
SELECT s2.stok_id, s1.tipe_trans, COUNT(*) n, CAST(MAX(s2.hpp) AS NUMERIC(18,2)) hpp_skrg
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans IN ('88','22') AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND s2.stok_id IN ('TR.038A','TR.039A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A')
GROUP BY s2.stok_id, s1.tipe_trans ORDER BY s2.stok_id, s1.tipe_trans;

-- ============================================================
-- 1) PULIHKAN tsales2.hpp (WIP-Out '88' + Penjualan '22') Juli 2026
-- ============================================================
UPDATE tsales2
   SET hpp = CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
   END
 WHERE bukti_id IN (
       SELECT bukti_id FROM tsales1
        WHERE tipe_trans IN ('88','22') AND tgl BETWEEN '2026-07-01' AND '2026-07-31'
       )
   AND isnull(evap,'') <> ''
   AND stok_id IN ('TR.038A','TR.039A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A');
COMMIT;

-- ============================================================
-- 2) PULIHKAN tstok2 (WIP-In '88') Juli 2026 - hpp, hrg, netto, kotor, netto_hpp
-- ============================================================
UPDATE tstok2
   SET hpp = CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END,
       hrg = CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END,
       netto = ROUND((CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END) * qty, 2),
       kotor = ROUND((CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END) * qty, 2),
       netto_hpp = ROUND((CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END) * qty, 2)
 WHERE bukti_id IN (
       SELECT bukti_id FROM tstok1
        WHERE tipe_trans = '88' AND tgl BETWEEN '2026-07-01' AND '2026-07-31'
       )
   AND stok_id IN ('TR.038A','TR.039A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A');
COMMIT;

-- ============================================================
-- 3) PULIHKAN sinv periode Agustus (2026-08-01) = saldo akhir Juli
--    nilai = qty (TIDAK berubah, sudah benar) x hpp_avg (dipulihkan)
-- ============================================================
UPDATE sinv
   SET hpp_avg = CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END,
       nilai = ROUND(qty * (CASE stok_id
       WHEN 'TR.038A'  THEN 253369782.78
       WHEN 'TR.039A'  THEN 219945169.85
       WHEN 'TR.1002A' THEN 34649470.03
       WHEN 'TR.1003A' THEN 38464452.49
       WHEN 'TR.1004A' THEN 35850732.21
       WHEN 'TR.1006A' THEN 42446589.02
       WHEN 'TR.1007A' THEN 51675088.47
       WHEN 'TR.910A'  THEN 27251352.25
       END), 2)
 WHERE periode = '2026-08-01'
   AND stok_id IN ('TR.038A','TR.039A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A');
COMMIT;

-- ============================================================
-- 4) VERIFIKASI: semua baris Juli per stok harus SATU nilai (baseline) saja
-- ============================================================
SELECT s2.stok_id, s1.tipe_trans, COUNT(*) n,
       CAST(MIN(s2.hpp) AS NUMERIC(18,2)) hpp_min, CAST(MAX(s2.hpp) AS NUMERIC(18,2)) hpp_max
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans IN ('88','22') AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND s2.stok_id IN ('TR.038A','TR.039A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A')
GROUP BY s2.stok_id, s1.tipe_trans ORDER BY s2.stok_id, s1.tipe_trans;

SELECT stok_id, CAST(qty AS NUMERIC(18,2)) qty, CAST(hpp_avg AS NUMERIC(18,2)) hpp_avg, CAST(nilai AS NUMERIC(18,2)) nilai
FROM sinv WHERE periode='2026-08-01'
  AND stok_id IN ('TR.038A','TR.039A','TR.1002A','TR.1003A','TR.1004A','TR.1006A','TR.1007A','TR.910A')
ORDER BY stok_id;

-- ============================================================
-- CATATAN: TR.040A SENGAJA DIKECUALIKAN dari runbook ini.
-- Beda dari 8 stok di atas, TR.040A nilai HPP-nya TIDAK beku permanen (bergerak
-- 201.915.420 Jan -> 199.621.793 Feb-Mei -> 213.433.165 basis Jul-01 stlh
-- pembelian Juni qty=2@220.692.975 + qty=6@211.416.090). 3 event WIP-Out baru
-- Juli (CIM1090978/CIM1102870/CIM1090976) butuh rata-rata TERTIMBANG yang benar
-- dari basis Juli, bukan sekadar angka lama - perlu konfirmasi Pak Wira dulu
-- sebelum dikoreksi, supaya tidak salah tebak seperti kasus Opsi 1.
-- ============================================================
