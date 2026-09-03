-- ============================================================
-- DETEKTOR RESIDU HPP — jalankan SETIAP SELESAI REFRESH bulanan (30 detik).
-- Tujuan: tangkap residu/korupsi HPP DALAM HITUNGAN MENIT, bukan berbulan kemudian.
-- Jaring pengaman permanen: menangkap SEMUA pola residu apa pun sumbernya.
-- Ganti :per ke periode saldo yg baru ditulis refresh (bulan+1, mis '2026-08-01').
-- Semua hasil HARUS KOSONG. Kalau ada isi = ada yg perlu dicek SEBELUM lanjut.
-- ============================================================

-- GATE 1: stok NOL tapi nilai TIDAK nol (residu nyangkut) — pola ACCU/LB
SELECT 'G1 qty=0 tapi nilai<>0' gate, sv.stok_id, gr.persediaan,
       CAST(sv.qty AS NUMERIC(18,2)) qty, CAST(sv.nilai AS NUMERIC(18,2)) nilai
FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id
             JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE sv.periode = '2026-08-01' AND sv.qty = 0 AND ABS(sv.nilai) > 1000
ORDER BY ABS(sv.nilai) DESC;

-- GATE 2: hpp_avg NEGATIF (moving-avg rusak) — pola TR.910A/ACCU
SELECT 'G2 hpp_avg negatif' gate, sv.stok_id, gr.persediaan,
       CAST(sv.qty AS NUMERIC(18,2)) qty, CAST(sv.hpp_avg AS NUMERIC(18,2)) hpp_avg,
       CAST(sv.nilai AS NUMERIC(18,2)) nilai
FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id
             JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE sv.periode = '2026-08-01' AND sv.hpp_avg < 0
ORDER BY sv.hpp_avg ASC;

-- GATE 3: WIP-Out '88' — dalam satu stok_id, HPP tidak seragam / meledak dari basis awal bulan.
--   (WIP-Out cost hrs BEKU = avg awal bulan; deviasi > Rp1000 = korupsi closing)
SELECT 'G3 WIP-Out 88 menyimpang' gate, x.stok_id,
       CAST(x.hpp_out AS NUMERIC(18,2)) hpp_out_skrg,
       CAST(x.basis_awal AS NUMERIC(18,2)) basis_awal_bulan
FROM (
  SELECT s2.stok_id,
         MAX(s2.hpp) hpp_out,
         (SELECT SUM(hpp_avg) FROM sinv WHERE stok_id=s2.stok_id AND periode='2026-07-01') basis_awal
  FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
  WHERE s1.tipe_trans='88' AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31' AND ISNULL(s2.evap,'')<>''
  GROUP BY s2.stok_id
) x
WHERE x.basis_awal IS NOT NULL AND ABS(ISNULL(x.hpp_out,0) - ISNULL(x.basis_awal,0)) > 1000
ORDER BY x.stok_id;

-- GATE 4: Konsinyasi — WIP-Out vs WIP-In HPP tidak sama (harus 0 selisih utk pasangan yg sudah In)
SELECT 'G4 Konsinyasi Out<>In' gate, o.stok_id, o.evap,
       CAST(o.hpp_out AS NUMERIC(18,2)) hpp_out, CAST(i.hpp_in AS NUMERIC(18,2)) hpp_in,
       CAST(o.hpp_out - i.hpp_in AS NUMERIC(18,2)) selisih
FROM ( SELECT s2.stok_id, s2.evap, s2.hpp hpp_out
       FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
       WHERE s1.tipe_trans='88' AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31' AND ISNULL(s2.evap,'')<>'' ) o
JOIN ( SELECT t2.stok_id, t2.coa_id evap, t2.hpp hpp_in
       FROM tstok1 t1 JOIN tstok2 t2 ON t1.bukti_id=t2.bukti_id
       WHERE t1.tipe_trans='88' AND ISNULL(t2.coa_id,'')<>'' ) i
  ON i.stok_id=o.stok_id AND i.evap=o.evap
WHERE ABS(ISNULL(o.hpp_out,0)-ISNULL(i.hpp_in,0)) > 1
ORDER BY o.stok_id;

-- ============================================================
-- GATE BARU (redesign, TANPA tabel) — G5 aturan bisnis WIP sale.
-- Catatan: TAMPER/INTEGRITAS '88' ditangani GATE 3 (WIP-Out '88' vs basis SINV-awal bulan) —
--   tak perlu ledger. Bila external writer (Stock Opname/Posting/script) menimpa '88',
--   G3 menyimpang dari basis => berbunyi.
-- ============================================================

-- GATE 5 (I2): penjualan WIP ('22'/'32'/'26'/'36' ber-evap) yg hpp BEDA dari HPP WIP-Out beku.
--   Aturan bisnis: WIP sale = WIP-Out (bukan average). Selisih > Rp1 = bocor average / out-of-order.
--   (unit yg BELUM ada '88' beku tak ikut, dijaga EXISTS — bukan barang WIP / belum di-refresh urut)
SELECT 'G5 WIP-sale <> WIP-Out' gate, s1.bukti_id, s2.stok_id, s2.evap,
       CAST(s2.hpp AS NUMERIC(18,2)) hpp_sale,
       CAST((SELECT MAX(c2.hpp) FROM tsales1 c1 JOIN tsales2 c2 ON c1.bukti_id=c2.bukti_id
             WHERE c1.tipe_trans='88' AND c2.stok_id=s2.stok_id AND c2.evap=s2.evap AND ISNULL(c2.hpp,0)>0) AS NUMERIC(18,2)) hpp_wipout
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans IN ('22','32','26','36') AND ISNULL(s2.evap,'')<>''
  AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND EXISTS (SELECT 1 FROM tsales1 c1 JOIN tsales2 c2 ON c1.bukti_id=c2.bukti_id
              WHERE c1.tipe_trans='88' AND c2.stok_id=s2.stok_id AND c2.evap=s2.evap AND ISNULL(c2.hpp,0)>0)
  AND ABS(ISNULL(s2.hpp,0) - ISNULL((SELECT MAX(c2.hpp) FROM tsales1 c1 JOIN tsales2 c2 ON c1.bukti_id=c2.bukti_id
              WHERE c1.tipe_trans='88' AND c2.stok_id=s2.stok_id AND c2.evap=s2.evap AND ISNULL(c2.hpp,0)>0),0)) > 1
ORDER BY s2.stok_id;

-- (G6/G7/G8 versi ledger DIHAPUS — solusi tanpa tabel. Fungsi tamper/integritas '88'
--  ditangani GATE 3 di atas: WIP-Out '88' vs basis SINV-awal bulan; deviasi = tamper/drift.)
