# SOP / RELEASE NOTE — Refresh Engine (redesign HPP WIP-Out) & Deprecation Journal

Tanggal: 2026-07-31. Berlaku setelah build FASE 1A+1B + ACC Produksi.

## 1. Kebijakan refresh (WAJIB)
- **Refresh HANYA melalui `w_refresh_transaksi_modern`** (Refresh Modern).
- **`w_refresh_journal` (Refresh Lama) DEPRECATED — tidak digunakan lagi.**
  - Di FASE 1B, penulis HPP independen journal (R6/R7-setara) **dinonaktifkan** via flag `ib_nvo_sole_hpp_authority`. Bila journal terlanjur dijalankan, HPP tetap dikelola **NVO** (aman), dan **G6 (Tamper Detector)** akan menangkap bila terjadi penyimpangan.
  - Di **FASE 2**, blok R6/R7 + flag dihapus permanen dari modern & journal.

## 2. System Boundary — siapa yang boleh menulis `tsales2.hpp`
```
  DI DALAM Refresh Engine (I8/I9 berlaku): penulis HPP = HANYA NVO n_cst_closing_stock
     - Modern Refresh, Journal Refresh (deprecated), CONSOUT, Ledger
  DI LUAR (Administrative Tools / EXTERNAL WRITERS):
     - Stock Opname (w_closing_stok), Posting HPP (w_posting_hpp), Recovery utility, script manual
```
- **I9:** SELAMA proses refresh berlangsung, **tidak boleh** ada writer lain terhadap `tsales2.hpp` selain NVO.
- External writer **tidak** dilarang total (administrator boleh recovery **di luar** refresh), tetapi:
  - **JANGAN** menjalankan Stock Opname / Posting HPP **bersamaan** dengan refresh.
  - **JANGAN** menjalankan Stock Opname / Posting HPP atas **unit WIP** setelah cutover (dapat menimpa nilai beku).
  - Bila terjadi, **G6 (Tamper Detector)** berbunyi → jalankan recovery resmi (lihat `RUNBOOK_cutover_freeze_wipout.sql` bagian recovery).

## 3. Prosedur operasi harian (operator)
1. Buka **Refresh Modern** (`w_refresh_transaksi_modern`).
2. Pilih periode, centang modul, jalankan. (Closing stok + HPP otomatis via NVO.)
3. **Jangan** buka Refresh Lama.
4. Setelah refresh, boleh jalankan `DETEKTOR_residu_hpp_bulanan.sql` (G1–G8) — semua harus kosong.

## 4. Recovery nilai beku (administrator, DI LUAR refresh)
- Ubah nilai beku hanya via: `UPDATE tsales2 SET hpp=0 WHERE bukti_id IN (SELECT bukti_id FROM tsales1 WHERE tipe_trans='88') AND ISNULL(evap,'')<>''` (batasi per serial/bulan bila perlu) lalu **refresh bulan ybs** → NVO membekukan ulang dari SINV-awal.
- Detail: `IMPORT_AND_DONE.md` (bagian opsional re-derive).

## 5. Catatan FASE 2
- Hapus permanen R6/R7 + `ib_nvo_sole_hpp_authority` di **modern & journal**.
- Opsional: beri **hard-deprecation** pada `w_refresh_journal` (mis. peringatan saat dibuka / redirect ke modern) bila ingin mencegah pemakaian keliru secara teknis, bukan hanya SOP.
