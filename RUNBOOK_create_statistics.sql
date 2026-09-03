/* ============================================================================
   RUNBOOK: CREATE STATISTICS (percepat RETRIEVE closing dw_refresh_stok)
   DB: vspnew (prod 103.233.89.43)

   MASALAH: PLAN retrieve menunjukkan optimizer SALAH TAKSIR selektivitas tgl
     (TSTOK1.TGL 1 bulan diestimasi 53,96% dari tabel -> harusnya ~8%) + banyak
     '100% Guess'. Akibatnya optimizer pilih HASH JOIN = full TableScan TSTOK2
     (138rb) + TSALES2 (80rb) + MCUST berkali-kali -> retrieve lambat.
     (Bagian sinv sudah cepat via idx_sinv_periode; ini masalah TERPISAH = statistik.)

   FIX: perbarui statistik kolom -> optimizer taksir benar -> pilih index-seek
     (bukan full-scan) -> retrieve cepat. NON-DESTRUKTIF (cuma stats, bukan data).
     Tiap perintah scan 1 tabel: beberapa detik (tstok2/tsales2 paling lama ~detik).

   TIMING: paling baik saat refresh TIDAK sedang meng-scan (di antara bulan, atau
     setelah Feb selesai). Boleh saat sepi. Setelah ini, refresh Mar-Jun lebih cepat.
   ============================================================================ */

create statistics tstok1;
create statistics tstok2;
create statistics tsales1;
create statistics tsales2;
create statistics sinv;
create statistics mcust;
create statistics im_produk;
create statistics im_product_group;

-- Verifikasi sesudah (opsional): estimasi tgl 1 bulan harusnya turun jauh dari 54%
-- (jalankan lagi PLAN retrieve; TableScan TSTOK2/TSALES2 semestinya jadi IndexScan)
