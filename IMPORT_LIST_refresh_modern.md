# IMPORT LIST — Refresh Modern (hardening + dropdown Bulan-Tahun) — READY PRODUCTION

Semua source di `C:\BTV\debug`, backup di sampingnya. 2026-07-31.

## URUTAN WAJIB

### Langkah 0 — DDL dulu (SEBELUM build)
Jalankan di dbisql pada **database build/dev** (dan nanti prod):
- **`RUNBOOK_refresh_ledger.sql`** → membuat tabel `refresh_ledger`.
> PENTING: PB 11.5 memvalidasi embedded-SQL saat **Full Build** ke DB yang terhubung.
> `w_refresh_transaksi_modern.srw` kini punya INSERT/SELECT ke `refresh_ledger`, jadi tabel HARUS
> sudah ada di DB build, kalau tidak build gagal compile.

### Langkah 1 — Import 9 objek source (PB: Import PBL/ImportFile)
| # | File | Perubahan | Backup |
|---|---|---|---|
| 1 | **w_refresh_transaksi_modern.srw** | P1 normalisasi bulan penuh, P2 al_replace=1/al_minus=0, B6 guard+audit ledger, **dropdown Bulan+Tahun**, flag redesign R6/R7 OFF | .bak_hardening/.bak_b6/.bak_ddlb |
| 2 | **n_cst_closing_stock.sru** | Engine closing: freeze WIP-Out HPP (hpp=0 guard C1), C2/C3/C4, konsumsi al_replace/al_minus. **Pasangan wajib** modern (flag R6/R7 OFF mengandalkan NVO ini) | .bak_redesign |
| 3 | f_transfer_cons.srf | B1 scope delete GL per bulan (CONS) | .bak_hardening |
| 4 | f_transfer_ap.srf | B1 scope (f_transfer_ar + f_transfer_ap) | .bak_hardening |
| 5 | f_transfer_po_new.srf | B1 scope (PO) | .bak_hardening |
| 6 | f_transfer_ekspedisi_new.srf | B1 scope (EXP) | .bak_hardening |
| 7 | f_transfer_dpkomisi.srf | B1 scope (5 delete DP/komisi) | .bak_hardening |
| 8 | f_transfer_so.srf | B1 else-branch → no-op guard | .bak_b1else |
| 9 | f_transfer_adjustment.srf | B1 else-branch → no-op guard | .bak_b1else |

### Langkah 2 — Full Build (PBL) → EXE/DLL.
### Langkah 3 — Uji di COPY-DB (restore dari backup Bapak):
- Buka refresh modern → cek **dropdown Bulan/Tahun** default = bulan berjalan, ganti bulan → tanggal ikut.
- Refresh 1 bulan → `INVARIANT_CHECKER.sql` + `ACCEPTANCE_hardening.sql` bersih.
### Langkah 4 — Deploy prod (setelah copy-DB lulus).

## CATATAN
- **Dependensi #1↔#2:** modern (R6/R7 OFF) mengandalkan NVO redesign (#2) sebagai satu-satunya penulis HPP. Import **berpasangan**. Ini juga membawa perbaikan **WIP-Out HPP beku** (fix bug cost-loss EVAP).
- **TIDAK perlu:** `w_refresh_journal.srw` (journal lama = DEPRECATED, refresh cukup via modern).
- **Bukan objek PB (SQL/analisa, tak di-import):** `INVARIANT_CHECKER.sql`, `ACCEPTANCE_hardening.sql`, `RUNBOOK_event_hpp_tstok2.md`, `DETEKTOR_residu_hpp_bulanan.sql`, worksheet TR.
- **Event `UPDATE HPP_TSTOK2`:** biarkan **enabled** (lihat `RUNBOOK_event_hpp_tstok2.md`) — tidak diubah.
- **Rollback:** restore backup 9 file + `DROP TABLE refresh_ledger`.

## Isu terpisah (jangan campur dengan build ini)
- **Reklas WIP TR → 102-020** (unit fisik keluar, ~10,1 M): menunggu worksheet fisik Bapak. Ini pembukuan data, bukan bagian import refresh modern.
