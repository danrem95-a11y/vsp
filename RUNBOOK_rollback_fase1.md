# RUNBOOK ROLLBACK — Redesign Engine Refresh (varian TANPA tabel)

Reversibel penuh. **Tidak ada objek DB baru** (tak ada tabel untuk di-DROP). Yang berubah:
1. **Source** 3 objek PB (di-backup `.bak_redesign`).
2. **Data** `tsales2.hpp` (bila refresh sudah dijalankan pasca-build) → untuk itu wajib ada **snapshot DB sebelum refresh**.

## Alur MAJU
| Step | Aksi | Reversibel dengan |
|---|---|---|
| S0 | **Backup DB penuh** (salin file .db/.log atau `dbbackup`) | restore file DB |
| S1 | **Import + Build** 3 objek PB (NVO + modern + journal) | restore `.bak_redesign` + build lama |
| S2 | **Refresh Jan→Des via Modern** (`tsales2.hpp` beku/dihitung) | restore DB S0 **atau** refresh ulang engine lama |

## Skenario ROLLBACK

### R-A. Gagal SEBELUM refresh (di S1; data belum berubah)
```
1. Restore source: copy *.bak_redesign -> file asli
     n_cst_closing_stock.sru.bak_redesign        -> n_cst_closing_stock.sru
     w_refresh_transaksi_modern.srw.bak_redesign  -> w_refresh_transaksi_modern.srw
     w_refresh_journal.srw.bak_redesign           -> w_refresh_journal.srw
2. Import + Build PB LAMA.
   (data tsales2 tak tersentuh -> selesai)
```

### R-B. Gagal SESUDAH refresh (S2; tsales2.hpp sudah berubah)
```
1. Restore DB dari snapshot S0 (mengembalikan tsales2/tstok2/sinv/gl_journal persis
   sebelum refresh baru).
2. Restore source .bak_redesign -> file asli (3 objek).
3. Import + Build PB LAMA.
4. Verifikasi rekon = seperti sebelum.
```

### R-C. Rollback CEPAT tanpa restore DB (mitigasi sementara)
Kembalikan perilaku penulis lama tanpa restore data:
```
1. Di source Modern & Journal, set: ib_nvo_sole_hpp_authority = false  (R6/R7 HIDUP lagi)
2. Build.
   -- Perubahan NVO (C1-C4) tetap aktif. Ini mode campuran (lama+baru) utk investigasi,
   --  BUKAN kondisi final. Untuk rollback PENUH gunakan R-A / R-B.
```

## Catatan
- Tidak ada tabel/ledger → tak ada `DROP TABLE`.
- **Recovery nilai '88'** (bukan rollback): `UPDATE tsales2 SET hpp=0 WHERE bukti_id IN (SELECT bukti_id FROM tsales1 WHERE tipe_trans='88') AND ISNULL(evap,'')<>''` (opsional, per bulan/serial) lalu refresh → C1 membekukan ulang dari SINV-awal.
- Simpan `.bak_redesign` sampai ACC final + observasi selesai.
- **Uji rollback R-A/R-B di NON-PRODUKSI (copy DB) dulu.**
