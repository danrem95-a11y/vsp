# SPEC — Opsi A Permanen: Barang Konsinyasi '88' Tidak Dinilai di Stok

## 1. Akar (dikonfirmasi dari kode)
- **Cons-in '88'** masuk `tstok2.NETTO = 0` (tak ada biaya beli — bukan milik).
- **Closing step 4d** (`n_cst_closing_stock.sru`, "UPDATE TSTOK2 Konsinyasi IN BY EVAP") **MENILAI** '88':
  set `NETTO/HPP/HRG/KOTOR/NETTO_HPP = moving-avg × qty` (mis. 247 jt/unit).
- Retrieve `dw_refresh_stok` menghitung nilai konsinyasi dari `TSTOK2.NETTO`:
  - derived **CONSIN** (baris 208–227): `SUM(qty × NETTO)`
  - derived **CONSIN_BY_EVAP** (baris 228–249): `SUM(qty × NETTO)`
  → masuk `akhir_rpxx` → `sinv.NILAI`.
- Akibat: **sinv NILAI ikut memuat nilai konsinyasi** (Rp10,99 M di 102-001+006) padahal GL persediaan (milik) tidak.

## 2. Perubahan (Opsi A)
Ganti **step 4d** agar '88' konsinyasi **di-set NILAI = 0** (qty tetap):

```sql
-- STEP 4d (BARU) — Konsinyasi IN: qty tampil, NILAI = 0 (bukan aset milik)
UPDATE TSTOK2
   SET HPP = 0, NETTO = 0, KOTOR = 0, HRG = 0, NETTO_HPP = 0
  FROM TSTOK2, TSTOK1
 WHERE TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID
   AND TSTOK1.TIPE_TRANS IN ('88')
   AND TSTOK1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2;
```
(Menggantikan blok UPDATE lama yang memakai subquery moving-avg. Idempoten: berapa kali pun dijalankan, '88' tetap 0.)

## 3. Kenapa ini benar & aman (dari analisis kode + GL)
- CONSIN & CONSIN_BY_EVAP di retrieve berasal dari `TSTOK2.NETTO` → jadi 0 → **sinv NILAI = nilai MILIK = GL**. ✅
- **QTY** '88' tetap dihitung (AKHIR qty pakai CONSIN.QTY) → **stok fisik utuh**. ✅
- **HPP Penjualan EVAP (step 4b)** memakai `AVG(tsales '88'.hpp)` — **independen** dari `tstok.NETTO` → **tidak terpengaruh** (kasus NR.201A tetap jalan). ✅
- Penjualan unit konsinyasi ('22') **tak mem-posting COGS/persediaan** (terbukti di GL: 102-001 & 402-001 = 0) → dilusi hpp_avg **tak berdampak** ke COGS unit reefer. ✅

## 4. Risiko yang WAJIB diuji
- **Item campuran** (satu stok_id ada beli '02' milik DAN '88' konsinyasi): hpp_avg bisa ter-dilusi (nilai milik / qty total). Perlu cek apakah ada item begini & apakah COGS-nya terpengaruh.
- **Laporan** yang menampilkan nilai konsinyasi → kini 0 (memang sesuai Opsi A).

## 5. Dua bagian solusi
1. **Permanen (going-forward):** perubahan step 4d di atas → closing bulan depan tak menilai konsinyasi lagi.
2. **Koreksi saldo awal existing:** nilai konsinyasi 10,99 M sudah terlanjur di saldo awal 2026. Perlu **re-close Desember 2025 → forward** (dengan step 4d baru) supaya saldo awal 2026 + seluruh periode dihitung ulang tanpa nilai konsinyasi → sinv = GL. (ATAU jurnal/koreksi saldo-awal satu-kali bila re-close Des tak diinginkan.)

## 6. Rencana UJI di LOKAL (wajib sebelum prod)
1. Backup `n_cst_closing_stock.sru` (mis. `.bak_opsiA`).
2. Terapkan perubahan step 4d, import + Full Build di lokal.
3. Re-close **Desember 2025** di DB lokal.
4. Verifikasi:
   - (a) `sinv.NILAI` 102-001/006 saldo awal 2026 = GL (gap → ~0).
   - (b) `sinv.QTY` 102-001/006 **tak berubah** (fisik utuh).
   - (c) HPP Penjualan EVAP (NR.201A / serial) tetap benar.
   - (d) Item milik murni (nilai & COGS) **tak berubah**.
   - (e) Akun persediaan lain (102-101/110/102 dst) tetap cocok.
5. Bila semua OK → deploy prod (import + Full Build) → re-close Des'25 forward.

## 7. Rollback
Restore `n_cst_closing_stock.sru.bak_opsiA` + Full Build; re-close.

## Catatan terpisah
- **102-006** ikut tertangani oleh fix ini (mekanisme sama).
- **102-201 MT (−23,96 jt)** BUKAN konsinyasi — jurnal penyesuaian saldo awal terpisah.
