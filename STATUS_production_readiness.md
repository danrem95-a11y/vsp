# Modul Fixed Asset — Status Production Readiness

**Tanggal:** 2026-06-17 | **DB:** `vspnew` (DSN vsp) | **Site:** 101

## ✅ SELESAI & TERVALIDASI (live di DB)

| Komponen | Status | Bukti |
|---|---|---|
| Skema tabel (`FA_CATEGORY/FA_ASSET/FA_DEPRECIATION/FA_PERIOD/FA_ASSET_AUDIT`) | ✅ dibuat | `fa_01_schema.sql` |
| Seed kategori (5, parameter audited dari Excel) | ✅ 5 baris | BGN120/KDR96/PKT48/PBK96/TNH0, residu 0 |
| Master aktiva | ✅ 279 aset diimpor | `fa_02_assets.sql` |
| Penyusutan Jan–Jun 2026 (sub-ledger) | ✅ 539 baris | dari WP audited, `fa_04_depr.sql` |
| Validasi engine vs WP JURNAL §4 | ✅ cocok ±Rp0,05/bln | per kategori per bulan |
| **Jurnal GL Jan–Jun 2026** | ✅ **terposting modul FA** | 6 voucher `FA101202601–06`, 30 baris, semua Dr=Cr |
| Engine reusable (`sp_fa_generate_sl/post_period/regenerate_period`) | ✅ dibuat & diuji | `fa_07_procs.sql`; Jul 2026 = WP ±Rp0,03 |
| Audit trail | ✅ USER_LOG + tabel FA_ASSET_AUDIT | log FA-REBASE tercatat |

### Apa yang dilakukan pada GL (rebase, atas persetujuan)
- **Backup** 4 voucher manual Jan–Apr (`gl_journal_fa_rebase_backup`, 20 baris) — dapat dipulihkan.
- **Hapus** 4 voucher `GJ` MEMO (Jan–Apr, status `N`/belum posting).
- **Post** `FA101202601–06` (modul `FA`, rupiah penuh, `posting='N'`, Dr 412-066 / Cr 158-001/101/201/301).
- **Hasil value-neutral:** nilai Jan–Apr identik dengan entri lama; Mei–Jun baru ditambahkan. Gerakan akun = WP §4 persis.

## ✅ Lapisan UI PowerBuilder — SOURCE DIBUAT (perlu import-test di PB IDE)
- Dibuat 16 objek di `source_powerbuilder_11.5\fa_trans` & `fa_reports` (format export PB 11.5, UTF-16LE+BOM, meniru `w_gl_category`/`dw_journal_*`):
  - **fa_trans**: window `w_fa_category`, `w_fa_master`, `w_fa_generate` (panggil stored proc) + 7 DataWindow.
  - **fa_reports**: window `w_rpt_fa_register`, `w_rpt_fa_card`, `w_rpt_fa_rekap` + 3 DataWindow.
  - Panduan: `fa_trans\README_IMPORT.md`.
- ⚠️ **Belum diuji-import/compile** (lingkungan ini tidak menjalankan PowerBuilder). Import ke `fa_trans.pbl`/`fa_reports.pbl`, masukkan ke Library List (butuh ancestor `w_master`, `uo_dw`, global `gs_site`), lalu Full Build; perbaiki selisih minor bila ada.
- Generator (dapat dijalankan ulang): `gen_pb.py` (DataWindow), `gen_win.py` (Window).

## ⏳ MENUNGGU AKUNTAN (tidak memblok jurnal)
- **`FA_ASSET.acquisition_cost` per-aset belum reconciled** ke GL: kolom harga perolehan WP ber-anchor 2017/2018 + mutasi, dan memuat aset disposed. Total per **kategori** cocok GL (§3), tetapi angka **per aset** perlu cleanup untuk Daftar Aktiva/Kartu Aktiva. Jurnal & penyusutan TIDAK terpengaruh (engine pakai `book_value_beginning` + `remaining_life_begin` yang sudah tervalidasi).

## ▶️ Operasi bulanan ke depan (Jul 2026+)
```
CALL sp_fa_generate_sl('2026-07-31','101');   -- hitung draft
CALL sp_fa_post_period ('2026-07-31','101');   -- post ke gl_journal (modul FA)
-- ralat sebelum closing:
CALL sp_fa_regenerate_period('2026-07-31','101');
```
Catatan: akurasi auto-calc go-forward bergantung pada `book_value_beginning`/`remaining_life_begin` (tervalidasi utk basis 31/12/2025). Untuk aset baru/penambahan setelah 2025, isi master dengan benar.

## Rollback (bila perlu)
```sql
DELETE FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101%';
INSERT INTO gl_journal SELECT * FROM gl_journal_fa_rebase_backup;  -- kembalikan 4 MEMO
COMMIT;
```

## Artefak
`design_modul_fixed_asset.md`, `finalisasi_WP_aset_tetap.md`, `fa_01_schema.sql`, `fa_02_assets.sql`, `fa_04_depr.sql`, `fa_05_build_stage.sql`, `fa_06_rebase.sql`, `fa_07_procs.sql`, `extract_assets.py`, `STATUS_production_readiness.md`.
