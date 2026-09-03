/* ============================================================================
   RUNBOOK: PERBAIKI INDEX SINV (percepat closing stok di refresh)
   DB: vspnew (prod 103.233.89.43)

   MASALAH: index 'idx_sinv_periode' saat ini kolomnya (STOK_ID, PERIODE) = SALAH
     urutan (duplikat idx_sinv_per_stok). Semua index sinv diawali STOK_ID ->
     query closing 'WHERE PERIODE=.. GROUP BY stok_id' (retrieve dw_refresh_stok +
     step 4a + 4c) TAK BISA seek -> scan 940rb baris tiap kali -> closing lama.

   FIX: drop yg salah, buat ulang dgn PERIODE di depan -> WHERE periode= bisa
     seek ke ~6.500 baris -> closing dari MENIT ke DETIK. Sekalian mempercepat
     Laporan Mutasi Stok (akar sama).

   SIFAT: DDL murni, tak mengubah data/nilai apa pun. Non-destruktif & reversible.
     Butuh lock eksklusif sinv -> JALANKAN SAAT APLIKASI IDLE / user logout
     (kalau ada SHARE-lock dari app, DDL akan antre/terblokir).
     Waktu buat index di 940rb baris: beberapa detik.

   >>> Idealnya jalankan SEBELUM refresh Jan-Jun (utk koreksi TL.203.0504),
       supaya refresh itu jauh lebih cepat. <<<
   ============================================================================ */

-- ===== 1. PRE-CHECK (lihat index sinv sekarang) =====
select tname, iname, colnames from SYS.SYSINDEXES where tname='sinv' order by iname;
-- idx_sinv_periode harus tampak (STOK_ID ASC, PERIODE ASC) = salah urutan

-- ===== 2. DROP index yg salah urutan (duplikat) =====
drop index sinv.idx_sinv_periode;

-- ===== 3. BUAT ULANG dgn urutan BENAR (PERIODE dulu) =====
create index idx_sinv_periode on sinv (PERIODE, STOK_ID);

-- ===== 4. POST-CHECK (harus: PERIODE ASC, STOK_ID ASC) =====
select tname, iname, colnames from SYS.SYSINDEXES where tname='sinv' and iname='idx_sinv_periode';

-- ===== 5. (opsional) uji cepat: query pola closing harus cepat sekarang =====
-- select stok_id, sum(qty), sum(nilai), avg(hpp_avg) from sinv where periode='2026-07-01' group by stok_id;

-- ===== ROLLBACK (bila perlu kembalikan seperti semula) =====
-- drop index sinv.idx_sinv_periode;
-- create index idx_sinv_periode on sinv (STOK_ID, PERIODE);
