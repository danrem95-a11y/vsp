# Status Deploy Produksi — Modul Fixed Asset

**Server:** SQL Anywhere 9.0.2 (Adaptive Server Anywhere), `ENG=vspnew`, host `103.233.89.43:2638`, DBN `vspnew`, site `101`
**Tanggal deploy:** 2026-06-20
**Catatan:** Produksi = data GL identik dengan `vspnew` lokal (saldo 31/12/2025 cocok persis); produksi SEBELUMNYA tanpa modul FA.

## ✅ SELESAI & TERVERIFIKASI di produksi (DB layer = production-ready)

| # | Komponen | Bukti |
|---|---|---|
| 1 | Schema FA (5 tabel) | FA_CATEGORY/ASSET/DEPRECIATION/PERIOD/ASSET_AUDIT |
| 2 | Kategori 5 + Aset 296 (279 + 6 BGN + 11 TNH) | tie ke GL |
| 3 | Subledger penyusutan 539 baris (posted) | total Jan–Jun 334.147.546 = WP |
| 4 | Paket A (6 Bangunan + 11 Tanah + 3 KDR fix) | 151-100 & 151-001 tie GL |
| 5 | Recon views v_fa_recon_asset / v_fa_recon_gl | memvalidasi vs gl_balance |
| 6 | **Rebase GL**: 4 MEMO → 6 voucher FA101202601–06 | balanced; Jan–Apr value-neutral; **Mei–Jun Rp109.963.645 di-book** |
| 7 | Engine procs SA9 (generate/post/regenerate) | compile OK; FOR-loop + COUNT-subquery (pengganti LATERAL/ROW_NUMBER) |
| 8 | GL-link FA_GL_LINK + sp_fa_build_gl_link | 1078 baris, 95 aset, 6 voucher (backfill Jan–Jun) |
| 9 | Backup pra-rebase gl_journal_fa_rebase_backup | 20 baris (4 MEMO) untuk rollback |

## Rekonsiliasi sub-ledger ↔ GL (v_fa_recon_gl, terverifikasi di produksi)
- Tanah, Bangunan, P.Bengkel: **delta 0** (tie).
- P.Kantor: selisih Rp8.735.000 = 2 aset perolehan Jan-2026 (post-cutoff, benar).
- Kendaraan: gap audit-listing vs book = **PAJE-pending** (terdokumentasi `MEMO_REKONSILIASI_FA_FINAL.md`).

## ✅ SELESAI — lapisan UI & navigasi (2026-06-20)
1. **UI PowerBuilder** — ✅ ter-deploy oleh tim (objek FA di aplikasi produksi).
2. **Menu FA** — ✅ aktif: `sysleftmenu(62)` **8 item** (05 Ringkasan, 10 Kategori, 20 Master, 30 Generate, 40 Daftar, 50 Kartu, 60 Rekap, 70 Umur), grant ke **8 usergroup GL** (64 baris: 6 item full + 2 laporan view/cetak). Via `fa_08_menu_SA9.sql` + `fa_08b_menu_summary_aging.sql`.
3. **Smoke-test engine** — ✅ `sp_fa_generate_sl('2026-07-31')` di produksi menghasilkan 84 baris draft tanpa error, lalu dibersihkan (tidak menyentuh GL). Engine bulanan go-forward terbukti jalan di SA9.

**STATUS: FULL PRODUCTION-READY (DB + jurnal + engine + GL-link + recon + UI PB + menu).**

## Operasi bulanan ke depan (Jul-2026+)
```
CALL sp_fa_generate_sl('2026-07-31','101');
CALL sp_fa_post_period ('2026-07-31','101');
CALL sp_fa_build_gl_link('2026-07-31','101');
-- ralat sebelum closing: CALL sp_fa_regenerate_period('2026-07-31','101');
```

## Rollback
`fa_99_rollback_PRODUKSI.sql` (keuangan: pulihkan 4 MEMO dari backup + hapus voucher FA; modul: drop tabel/proc/view).

## Perlu konfirmasi finance
Beban penyusutan **Mei–Jun Rp109.963.645** kini di GL produksi (voucher `posting='N'`, dapat diralat sebelum closing).
