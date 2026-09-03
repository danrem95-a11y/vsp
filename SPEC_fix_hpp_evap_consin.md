# Rancangan Fix-Kecil: HPP WIP-in EVAP dari cost WIP-out serial

> **STATUS 2026-07-23: SUDAH DITERAPKAN ke `f_insert_cons_in.srf` (2 overload) + TERUJI di prod (read-only).**
> Backup `.bak_evapcost`. Uji: 725 baris jual EVAP 2026 → 5 berubah (Jun 1 + Jul 4), **0 regresi**
> (tak ada baris hpp>0 yang berubah); statement INSERT-SELECT tstok2 utuh jalan tanpa error,
> NR.201A → netto=hpp=38.500.000. **SISA: import PB 11.5 + compile + Full Build + uji copy + deploy prod.**

## Masalah (terbukti — kasus NR.201A serial 645BDEAC002)
Unit EVAP (ber-nomor seri) keluar konsinyasi (WIP-out) satu bulan, lalu **terjual di bulan
berikutnya**. Saat itu saldo stok = 0 → moving-average = 0 → HPP jual = 0 → WIP-in kembali
bernilai 0. Akibat (bukti GL):
- **COGS (402-008) = 0** padahal seharusnya = HPP WIP-out (mis. 38.500.000) → **Laba Rugi over**.
- Cost nyangkut di **Titipan Konsinyasi 102-020** (Neraca over).
- Saldo akhir stok TIDAK terpengaruh (unit sudah keluar).

Frekuensi (prod, 2026): Jan–Mei 0, **Jun 1, Jul 4** — jarang tapi berulang.

## Prinsip fix
Cost yang benar **sudah ada** = HPP WIP-out (consout tsales88) untuk **nomor seri (evap) yang
sama**. Cukup: **kalau HPP jual = 0, pakai HPP WIP-out serial itu.** Bila HPP jual > 0
(kasus normal, mis. serial 174) → biarkan apa adanya → **nol regresi**.

## Lokasi
`f_insert_cons_in.srf` — fungsi yang membangun WIP-in (tstok1/2) dari faktur & meng-update
`tsales2.hpp` untuk produk EVAP. Sudah men-join `cons` (consout tsales88, **punya kolom hpp**)
dengan `jual` (tsales22) berdasarkan `stok_id + evap + cond`, TAPI memakai `jual.hpp` untuk
nilai. Terapkan pada **overload 1-argumen** `f_insert_cons_in(string arg_order)` (yang dipanggil
refresh di w_refresh_journal ~2177 & w_refresh_transaksi_modern), idealnya kedua overload.

## Perubahan (inti)
Definisikan **HPP efektif** = `jual.hpp` bila > 0, else HPP WIP-out serial:
```
isnull(jual.hpp,0)   -->   (case when isnull(jual.hpp,0) > 0 then jual.hpp
                                 else isnull(
                                   (select max(c2.hpp)
                                      from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id
                                     where c1.tipe_trans='88'
                                       and c2.stok_id = jual.stok_id
                                       and c2.evap    = jual.evap
                                       and isnull(c2.hpp,0) > 0
                                       and c1.tgl    <= jual.tgl), 0)
                            end)
```
Ganti di 3 titik dalam fungsi (semua yang sekarang `isnull(jual.hpp,0)`):
1. **INSERT tstok2**: kolom `kotor`, `netto`, `hpp`, `netto_hpp`, `hrg` (nilai WIP-in).
2. **UPDATE tstok1** `ttl_kotor/ttl_netto = sum(netto)` (otomatis ikut karena baca tstok2).
3. **UPDATE tsales2 SET hpp = ...** (HPP baris jual → dibaca f_transfer_hpp untuk COGS).

> Catatan: scalar-subquery dipakai (bukan kolom `cons.hpp` dari join) agar **kardinalitas join
> tidak berubah** bila 1 serial pernah beberapa kali konsinyasi. `<= jual.tgl` + `max(hpp>0)`
> memilih cost WIP-out yang relevan.

## Kenapa aman
- Hanya aktif saat `jual.hpp = 0` (kondisi rusak). Kasus normal (`hpp > 0`) tak tersentuh.
- **Menumpang jalur yang sudah terbukti benar** (serial 174 sukses end-to-end: WIP-in 38,5jt →
  `tsales2.hpp` 38,5jt → COGS 402-008 38,5jt → Titipan 102-020 lepas). Fix hanya **mengisi
  nilai** saat moving-average memberi 0 — plumbing-nya identik.
- **Self-healing & tahan refresh**: dihitung ulang tiap refresh dari cost WIP-out yang permanen,
  jadi tidak bisa diam-diam kembali 0 (beda dgn koreksi manual yang bisa tertimpa).
- Bila WIP-out pun 0 (cost benar-benar tak ada) → tetap 0 → dijaring detektor untuk ditinjau.

## Efek setelah fix (per refresh + re-close)
`tsales2.hpp` = 38,5jt → COGS 402-008 = 38,5jt (Laba Rugi benar) → WIP-in netto 38,5jt →
GL consin Dr 102-003 / Cr 102-020 (Titipan lepas) → Mutasi = Ledger = Laba Rugi.

## Uji sebelum produksi
1. Terapkan di DB COPY, jalankan detektor (harus tetap menemukan kasus SEBELUM refresh).
2. Refresh + re-close bulan berkaitan → detektor jadi 0 baris; cek COGS 402-008 & 102-020.
3. **Regresi**: pastikan kasus hpp>0 (mis. serial 174) nilainya TIDAK berubah.
4. Rekonsiliasi Mutasi vs Ledger 102-003 tetap ≤ pembulatan.

## Deploy
Edit `f_insert_cons_in.srf` (biner UTF-16LE+BOM+CRLF) → import PB 11.5 → compile bersih →
Full Build → uji di copy → deploy prod D:\Database. (Sepaket dengan patch WIP-IN & GL-consin
yatim yang masih menunggu import.)
