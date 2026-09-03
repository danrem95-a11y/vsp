-- ============================================================
-- RUNBOOK: fix tsales2.hpp = 0 pada 3 WIP-Out zero-opening (TR.911A re-konsinyasi)
-- Sebab: precompute pakai sinv avg awal bulan yg = 0 (unit tak ada stok reguler,
--   berada di WIP). Akibat: tsales2.hpp '88' = 0 → Laporan Konsinyasi tampil 0.
-- CATATAN PENTING: GL 102-020/102-001 utk unit ini SUDAH BENAR (54,08/26,5 jt) &
--   TERLINDUNGI (f_transfer_cons return sebelum delete bila hpp=0). Runbook ini
--   HANYA membetulkan tsales2.hpp (tampilan laporan + konsistensi), TAK sentuh GL.
-- Nilai benar = HPP WIP-In (tstok88) = nilai GL.
-- Data-only. Jalankan di dbisql. 2026-07-31.
--
-- >>> PERINGATAN DURABILITAS <<<
-- Fix ini SATU KALI. Bila Mar/Mei di-FULL REFRESH ulang, precompute akan
-- me-nol-kan lagi (sinv awal msh 0). Solusi permanen = perbaiki precompute agar
-- fallback ke HPP WIP-In saat sinv awal=0 (sub-tugas engine terpisah), ATAU beri
-- unit ini basis sinv. Untuk sekarang: JANGAN full-refresh Mar/Mei setelah runbook;
-- kalau perlu koreksi GL cukup CONSOUT-only (yg kini sudah membaca hpp benar).
-- ============================================================

-- (opsional) cek dulu kondisi sekarang
SELECT s2.evap, s2.stok_id, cast(s2.hpp as numeric(18,2)) hpp_sekarang
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans='88' AND s2.evap IN ('CIM1083368','CIM1096205','CIM1096206');

-- ============================================================
-- 1) CIM1083368 (TR.911A, Mar) = 26.549.048 (WIP-In terkonfirmasi)
-- ============================================================
UPDATE tsales2 SET hpp = 26549048.00
 WHERE evap='CIM1083368'
   AND bukti_id IN (SELECT bukti_id FROM tsales1 WHERE tipe_trans='88');
COMMIT;

-- ============================================================
-- 2) CIM1096205 (TR.911A, Mei) = 54.082.153,36 (WIP-In terkonfirmasi)
-- ============================================================
UPDATE tsales2 SET hpp = 54082153.36
 WHERE evap='CIM1096205'
   AND bukti_id IN (SELECT bukti_id FROM tsales1 WHERE tipe_trans='88');
COMMIT;

-- ============================================================
-- 3) CIM1096206 (TR.911A, Mei) = 54.082.153,36
--    >>> BELUM ADA WIP-In; nilai ikut pasangan/GL. Nilai 54,08jt = PERSIS 2x norma
--    TR.911A (~27,04jt) => MENCURIGAKAN (mungkin input ganda).
--    KONFIRMASI FISIK/ENTRY DULU. Kalau ragu, JANGAN jalankan blok ini (biarkan
--    comment) sampai Pak Wira pastikan nilai benarnya.
-- ============================================================
-- UPDATE tsales2 SET hpp = 54082153.36
--  WHERE evap='CIM1096206'
--    AND bukti_id IN (SELECT bukti_id FROM tsales1 WHERE tipe_trans='88');
-- COMMIT;

-- ============================================================
-- 4) VERIFIKASI: hpp harus terisi (tak 0 lagi) utk yg dikoreksi
-- ============================================================
SELECT s2.evap, s2.stok_id, cast(s2.hpp as numeric(18,2)) hpp_sesudah
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans='88' AND s2.evap IN ('CIM1083368','CIM1096205','CIM1096206')
ORDER BY s2.evap;
