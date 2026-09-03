# IMPORT & DONE — Redesign Engine Refresh HPP WIP-Out (TANPA tabel baru)

Solusi final **tanpa objek DB baru** (tak ada CREATE TABLE, laporan existing aman). Cukup import 3 file PowerBuilder + build.

## Yang di-import ke PowerBuilder 11.5 (3 objek)
1. `n_cst_closing_stock.sru`  — NVO closing (freeze '88' by `hpp=0`, NON-WIP=avg, WIP=WIP-Out).
2. `w_refresh_transaksi_modern.srw` — refresh modern (penulis bersaing R6/R7 OFF via flag).
3. `w_refresh_journal.srw` — refresh lama (R6/R7 OFF juga → I8 single authority).

## Langkah
1. **Import** 3 objek di atas ke library (menggantikan yang lama).
2. **Full Build** aplikasi.
3. **Refresh Jan→Des via Refresh Modern** (seperti biasa). Selesai.

Tidak ada DDL. Tidak ada tabel. Tidak ada langkah SQL wajib.

## Apa yang berubah di engine (ringkas)
| Perilaku | Sebelum | Sesudah |
|---|---|---|
| HPP WIP-Out ('88') | dihitung ulang tiap refresh (goyang) | **dihitung SEKALI saat `hpp=0`, lalu beku** (guard `ISNULL(hpp,0)=0`) |
| Penjualan WIP (ber-evap) | bisa kena moving-average | **= HPP WIP-Out beku** (NVO S-E, MAX '88', lintas-bulan) |
| Penjualan NON-WIP (evap kosong) | average | **tetap average** (NVO S-D, dibatasi `evap=''`) |
| Penulis HPP bersaing (R6/R7) di Modern & Journal | aktif | **OFF** (flag `ib_nvo_sole_hpp_authority`) |
| Otoritas penulis HPP | banyak | **HANYA NVO** (I8) |

## Freeze tanpa tabel — bagaimana bisa immutable?
`hpp=0` guard: NVO hanya mengisi '88' yang masih 0; yang sudah terisi **dilewati** (beku). Karena penulis bersaing sudah OFF & NON-WIP/WIP-sale (S-D/S-E) tak menyentuh '88', **tak ada** yang bisa merusak '88' lagi → aman tanpa perlu ledger.

## (OPSIONAL) Mulai bersih — hanya bila ingin re-derive '88' dari nol
Nilai '88' yang sudah ada akan **dipertahankan** (dianggap beku). Bila Bapak ingin engine menghitung ULANG semua '88' dari basis SINV-awal (mis. ada nilai lama yang diragukan), jalankan **sekali** sebelum refresh:
```sql
-- Nol-kan '88' WIP-Out agar dihitung ulang oleh C1 saat refresh (evap<>'' saja).
UPDATE tsales2 SET hpp = 0
 WHERE bukti_id IN (SELECT bukti_id FROM tsales1 WHERE tipe_trans='88')
   AND ISNULL(evap,'') <> '';
COMMIT;
```
Lalu Refresh Jan→Des. C1 akan membekukan ulang dari SINV-awal tiap bulan. (Zero-opening tanpa basis akan pakai HPP WIP-In; bila keduanya 0, ter-flag G3 → koreksi manual.)

## (OPSIONAL) Verifikasi — kalau mau cek
`DETEKTOR_residu_hpp_bulanan.sql` (G1–G5, tanpa tabel). Semua kosong = sehat.
- G3 = integritas '88' (vs basis SINV-awal) — berperan sbagai tamper detector.
- G5 = penjualan WIP harus = WIP-Out.

## FASE 2 (nanti, setelah yakin stabil)
Hapus permanen blok R6/R7 + instance var `ib_nvo_sole_hpp_authority` di Modern & Journal (jangan sisakan flag verifikasi permanen).
