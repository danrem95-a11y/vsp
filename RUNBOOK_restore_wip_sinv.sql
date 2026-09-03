-- ============================================================
-- RUNBOOK PEMULIHAN: batalkan koreksi Opsi 1 pd unit WIP -> kembalikan nilai basis WIP-Out
-- Sebab: skala sinv ke GL (Opsi 1) SALAH utk unit WIP; nilai WIP-In hrs = HPP WIP-Out (beku), bukan average.
-- Sumber pemulihan: sinv_bak_opsi1 (nilai pra-koreksi = basis WIP-Out) + sinv_bak_mt102201.
-- Data-only, GL tak disentuh. Jalankan di dbisql. 2026-07-30.
-- CATATAN: ini memulihkan sinv. Nilai tsales '88' (WIP-Out) yg ikut berubah oleh refresh 29-Jul
--          TIDAK dipulihkan di sini (tak ada backup) -> lihat opsi restore DB penuh.
-- ============================================================

-- (opsional) cek dulu: berapa baris akan dipulihkan
SELECT 'sinv_bak_opsi1' src, COUNT(*) n FROM sinv_bak_opsi1
UNION ALL SELECT 'sinv_bak_mt102201', COUNT(*) FROM sinv_bak_mt102201;

-- 1) PULIHKAN 102-001 (TR) & 102-006 (TB) dari sinv_bak_opsi1
UPDATE sinv
   SET nilai   = (SELECT b.nilai   FROM sinv_bak_opsi1 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id),
       hpp_avg = (SELECT b.hpp_avg FROM sinv_bak_opsi1 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id)
 WHERE EXISTS (SELECT 1 FROM sinv_bak_opsi1 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id);
COMMIT;

-- 2) PULIHKAN 102-201 (MT) dari sinv_bak_mt102201
UPDATE sinv
   SET nilai   = (SELECT b.nilai   FROM sinv_bak_mt102201 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id),
       hpp_avg = (SELECT b.hpp_avg FROM sinv_bak_mt102201 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id)
 WHERE EXISTS (SELECT 1 FROM sinv_bak_mt102201 b WHERE b.stok_id=sinv.stok_id AND b.periode=sinv.periode AND b.site_id=sinv.site_id);
COMMIT;

-- 3) VERIFIKASI: TR.038A kembali ke basis WIP-Out (hpp_avg ~247-253 jt)
SELECT periode, CAST(qty AS NUMERIC(18,2)) qty, CAST(nilai AS NUMERIC(18,2)) nilai, CAST(hpp_avg AS NUMERIC(18,2)) hpp_avg
FROM sinv WHERE stok_id='TR.038A' AND periode BETWEEN '2026-01-01' AND '2026-07-01' ORDER BY periode;
