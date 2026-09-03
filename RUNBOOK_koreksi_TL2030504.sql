/* ============================================================================
   RUNBOOK: KOREKSI DATA BELI TL.203.0504 (qty salah input 4 -> 20.000 CC)
   DB: vspnew (prod 103.233.89.43)
   Item: OIL COMPRESSOR R-404A RL-68 (grup TL / 102-102 Spare Parts TL)
   Bukti penerimaan: 10126010200006 (02 Jan 2026), faktur AIR926010388 (AMARI).

   MASALAH: baris TL.203.0504 di-input qty=4 CC padahal netto 8.600.000
     (= 2.150.000/CC) -> harusnya 20.000 CC (= 430/CC, sama spt semua beli lain).
     Akibat: moving-average kacau/NEGATIF (Apr -613, Mei -174, Jun -105) ->
     selisih Stok vs Ledger 102-102 Juni = 105.161,32.

   >>> PRASYARAT WAJIB (cek SEBELUM jalan) <<<
     1. Konfirmasi ke PEMBELIAN: fisik penerimaan 02 Jan = 20.000 CC (bukan 4).
        (faktur AIR926010388 total 16.539.000 = identik faktur 09 Jun yg 20.000 CC).
     2. Setelah koreksi + re-close, stok akhir TL.203.0504 akan NAIK ~19.996 CC.
        Pastikan itu cocok STOCK-OPNAME FISIK. Kalau fisik jauh lebih kecil,
        berarti ada isu lain (jangan jalankan; lapor dulu).

   SIFAT: koreksi 1 baris tstok2 (qty,qty1,hrg). netto/kotor TIDAK diubah ->
     GL pembelian (nilai 8.600.000) TIDAK berubah. Reversible (Bagian 5).
     Setelah ini WAJIB re-close/refresh Jan->Jun (Bagian 4).
   ============================================================================ */

-- ===== 1. PRE-CHECK (catat nilai lama utk rollback) =====
select bukti_id, stok_id, cast(qty as numeric(18,2)) qty, cast(qty1 as numeric(18,2)) qty1,
       cast(hrg as numeric(18,4)) hrg, cast(netto as numeric(18,2)) netto, cast(kotor as numeric(18,2)) kotor
from tstok2 where bukti_id='10126010200006' and stok_id='TL.203.0504';
-- HARUS tampil: qty=4  qty1=4  hrg=2150000  netto=8600000  (nilai LAMA)

-- ===== 2. KOREKSI (update HANYA baris TL.203.0504) =====
update tstok2
   set qty = 20000,
       qty1 = 20000,
       hrg  = 430          -- 8.600.000 / 20.000
 where bukti_id='10126010200006'
   and stok_id='TL.203.0504';
-- pastikan @@rowcount = 1 baris
commit;

-- ===== 3. POST-CHECK (harus sama persis dgn record beli yg benar) =====
select bukti_id, stok_id, cast(qty as numeric(18,2)) qty_hrs_20000, cast(hrg as numeric(18,4)) hrg_hrs_430, cast(netto as numeric(18,2)) netto_tetap_8600000
from tstok2 where bukti_id='10126010200006' and stok_id='TL.203.0504';

-- ===== 4. LANGKAH LANJUTAN (di aplikasi, SETELAH koreksi di atas) =====
--   a. Re-close / refresh STOK dari JANUARI s/d JUNI 2026 (moving-average dihitung ulang).
--      -> nilai negatif Apr-Jun hilang, sinv.hpp_avg jadi ~430 (positif).
--   b. INGAT: patch cross-month-delete belum di-deploy -> setelah refresh,
--      minta verifikasi ulang integritas 2025 (cmp_forensic/cmp_gl).
--   Verifikasi hasil (jalankan setelah re-close):
--   select periode, cast(qty as numeric(18,2)) qty, cast(hpp_avg as numeric(18,4)) hpp_avg
--     from sinv where stok_id='TL.203.0504' and periode>='2026-01-01' order by periode;
--     -> hpp_avg semua POSITIF (~430), tak ada negatif.
--   (lalu cek Stok vs Ledger 102-102 Juni -> gap 105.161,32 harus hilang)

-- ===== 5. ROLLBACK (bila fisik ternyata BUKAN 20.000) =====
-- update tstok2 set qty=4, qty1=4, hrg=2150000
--  where bukti_id='10126010200006' and stok_id='TL.203.0504';
-- commit;
