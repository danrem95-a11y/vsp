# REDESIGN v2 — Perbaiki DATA TURUNAN Opening 2026 (TANPA transaksi)
Prinsip Pak Wira: recovery memperbaiki **data turunan (persisted snapshot)**, BUKAN membuat transaksi. Yang boleh berubah HANYA representasi opening 2026. Dilarang: adjustment movement, mutasi/jurnal koreksi, stok adjustment 01-01-2026.

## 1. Realitas arsitektur (yang menentukan solusi)
- **SINV disimpan sebagai snapshot per periode** (`periode` = awal bulan). **`sinv[2026-01-01]` = SATU baris** yang berperan ganda: "saldo akhir 2025" **sekaligus** "saldo awal 2026" (kontinuitas closing=opening). **Tidak ada baris terpisah bertanggal 2025-12-31.**
- **Siapa yang MEMBACA `sinv[2026-01-01]`:**
  - Laporan Mutasi Stok **Januari 2026** → sebagai **AWAL** (opening). ← perlu jadi benar.
  - NVO peralihan tahun (yang menulisnya).
  - Rekonsiliasi Stok-vs-Ledger (alat, bukan laporan audit).
- **Siapa yang TIDAK membaca `sinv[2026-01-01]`:**
  - **Laporan Mutasi Stok Desember 2025**: menghitung AKHIR **dari transaksi** (`AKHIR FROM IM_PRODUK`), hanya baca `sinv[2025-12-01]` sebagai AWAL. → **tidak tersentuh** oleh koreksi opening.
  - **Neraca 2025 = GL** (`gl_balance`/`gl_journal`). → **tidak tersentuh**.

→ **Konsekuensi:** mengubah `sinv[2026-01-01]` **tidak mengubah** laporan/neraca/closing audit 2025. Yang berubah hanya AWAL laporan 2026.

## 2. Keterbatasan teknis (dijelaskan jujur)
Karena `sinv[2026-01-01]` adalah **satu baris** = closing-2025 = opening-2026, arsitektur ini **tidak menyimpan dua angka berbeda**. Maka ada 2 jalan:

### MEKANISME A — Koreksi snapshot opening langsung (REKOMENDASI)
**Perbaiki nilai turunan `sinv[2026-01-01]` = hasil engine** (12.999.133.239). BUKAN transaksi — hanya memperbaiki angka snapshot yang korup.
1. **Hitung target dari engine (READ-ONLY):** `dw_refresh_stok` closing Des-2025 → nilai benar per model. *Tidak menulis apa pun ke 2025.*
2. **UPDATE `sinv[2026-01-01]`** (qty & nilai per model) = nilai engine. **Tidak ada tstok/tsales/gl_journal dibuat.** Tidak ada "Koreksi Saldo Awal" karena bukan mutasi.
3. **Recompute snapshot 2026 berikutnya (sinv-only):** `n_cst_closing_stock.of_run(...,ab_sinv_only=TRUE)` untuk Jan lalu Feb → `sinv[2026-02-01]`, `sinv[2026-03-01]` dihitung ulang dari opening baru + transaksi asli. **GL tidak disentuh, transaksi tidak disentuh.**
- **Hasil:** Opening 2026 benar; Mutasi Januari **identik** (transaksi tak berubah, tak ada baris koreksi); Desember 2025 & neraca **byte-identik** (tak baca snapshot ini); WIP 102-020 & HPP-WIP tetap.
- **Sifat:** murni perbaikan **data turunan**, **nol transaksi/movement/jurnal**. Persis prinsip Bapak.
- **Catatan:** ini mengubah **nilai tersimpan** `sinv[2026-01-01]`. Karena tak ada output audit 2025 yang membacanya, tidak ada laporan 2025 yang berubah. TAPI bila Bapak menganggap angka tersimpan itu sendiri "milik 2025 dan haram diubah" → pakai Mekanisme B.

### MEKANISME B — Layer opening terpisah (bila snapshot 2025 wajib dibiarkan)
Simpan opening-2026 yang benar di **sumber terpisah**, `sinv[2026-01-01]` dibiarkan 23,11 M.
1. Buat **tabel/layer opening**: `sinv_opening_2026` (atau penanda site/flag khusus) berisi nilai engine per model (opening benar).
2. **Ubah sumber AWAL 2026**: `dw_refresh_stok` & laporan Januari membaca opening dari layer ini untuk periode 2026-01, bukan dari `sinv[2026-01-01]`.
3. Recompute sinv Feb/Mar dari opening layer.
- **Hasil:** `sinv[2026-01-01]` snapshot **utuh 23,11 M**; opening efektif 2026 = 12,99 M dari layer; 2025 & mutasi Jan identik.
- **Biaya:** perlu **modifikasi engine/laporan** (baca opening dari layer untuk 2026) + tabel baru. Lebih invasif, tapi menjaga snapshot 2025 secara harfiah.

## 3. Perbandingan
| Aspek | Mekanisme A (snapshot fix) | Mekanisme B (opening layer) |
|---|---|---|
| Transaksi/movement/jurnal | **NOL** | **NOL** |
| Ubah `sinv[2026-01-01]` tersimpan | Ya (jadi benar) | Tidak (dibiarkan) |
| Laporan/Neraca 2025 | Identik | Identik |
| Mutasi Januari | Identik | Identik |
| Perlu ubah engine/laporan | Tidak | **Ya** |
| Kompleksitas | Rendah | Sedang-tinggi |

## 4. Validasi (kedua mekanisme)
- **31-12-2025 identik:** laporan Mutasi Stok Des & neraca GL sebelum=sesudah (checksum/byte).
- **Opening 2026 benar:** opening = engine = GL (≤ Rp1 via NVO).
- **Mutasi Januari identik:** bandingkan mutasi Jan sebelum/sesudah → sama; **tidak ada baris "Koreksi Saldo Awal".**
- **Hanya Saldo Awal berubah, bukan mutasi.**
- **102-020 WIP tetap; HPP-WIP tetap.**
- **Idempotent:** ulangi recovery → identik.

## 5. Rekomendasi
**Mekanisme A** — paling sesuai prinsip "perbaiki data turunan, tanpa transaksi", dan terbukti (verifikasi arsitektur) tidak menyentuh output audit 2025. **Mekanisme B** hanya bila kebijakan mewajibkan angka snapshot 2025 tersimpan tidak boleh berubah sama sekali — dengan konsekuensi modifikasi engine.

> Keputusan Bapak: **A** (koreksi snapshot opening, snapshot berubah jadi benar) atau **B** (snapshot 2025 dibiarkan, opening dari layer terpisah)? Setelah itu saya susun langkah teknis + validasi (uji COPY-DB dulu, tanpa transaksi sintetis).
