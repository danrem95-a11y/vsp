# Modul Fixed Asset — Source PowerBuilder 11.5 (fa_trans / fa_reports)

Dihasilkan 2026-06-17. Format export PB 11.5 (UTF-16LE + BOM), meniru objek referensi
existing (`w_gl_category`, `dw_journal_entry`, `dw_journal_list`).

> ⚠️ **Belum diuji-import di PB IDE** (lingkungan generator tidak menjalankan PowerBuilder).
> Import di PB 11.5 lalu lakukan *Full Build*; perbaiki bila ada selisih minor. Lapisan
> database (tabel + stored procedure) SUDAH live & tervalidasi di DB `vspnew`.

## Isi
**fa_trans** (transaksi & master)
- Window: `w_fa_category` (master kategori), `w_fa_master` (master aktiva), `w_fa_generate` (generate+posting penyusutan)
- DataWindow: `dw_fa_category_list/entry`, `dw_fa_asset_list/entry`, `dw_fa_depr_list`, `dw_fa_generate_param`, `dw_fa_generate_preview`, `dw_fa_card_param`
- **DataWindow child dropdown (WAJIB di-import, dipakai DDDW):** `ddw_fa_category`, `ddw_gl_acc`, `ddw_gl_depart`, `ddw_fa_asset`. Jika tidak diimport, dropdown LOV tidak muncul.

**fa_reports** (laporan)
- Window: `w_rpt_fa_register` (Daftar Aktiva), `w_rpt_fa_card` (Kartu Aktiva), `w_rpt_fa_rekap` (Rekap Penyusutan)
- DataWindow: `dw_rpt_fa_register`, `dw_rpt_fa_card`, `dw_rpt_fa_rekap`

## Cara import
1. Buat 2 library: `C:\BTV\Apps\fa_trans.pbl` dan `C:\BTV\Apps\fa_reports.pbl`.
2. Tambahkan keduanya ke **Library List** target aplikasi (mis. di `frame`/aplikasi utama).
3. Import semua `.srw` & `.srd` (PB: klik-kanan PBL → *Import…*, pilih file di folder ini),
   atau pakai tool batch existing (`w_pbl_export_manager`).
4. **Full Build** aplikasi.

## Dependensi (harus ada di Library List saat build)
- Ancestor window **`w_master`** (maintenance: `w_fa_category`, `w_fa_master`).
- Ancestor window **`w_report`** (laporan + generate: `w_fa_generate`, `w_rpt_fa_register`, `w_rpt_fa_card`, `w_rpt_fa_rekap`) — pola sama `w_rpt_neraca`/`w_rpt_jual`. Menyediakan `dw_1` (kriteria/range) + `dw_2` (display) + tombol Preview/Print/Excel.
- User object **`uo_dw`**; global function `f_bom`, `f_eom`, `gurningsoft_xls`; window `w_prompt_print`.
- Global: `gs_site` (kode site aktif), `gdt_today`/`today()`.
- Criteria DW: **`d_range_fa_period`** (tgl1/tgl2, dipakai generate/register/rekap), **`d_range_fa_asset`** (pilih aset, dipakai kartu). (`dw_fa_generate_param`/`dw_fa_card_param` versi lama tidak dipakai lagi — boleh tidak di-import.)
- **Stored procedure di DB** (sudah dibuat): `sp_fa_generate_sl`, `sp_fa_post_period`,
  `sp_fa_regenerate_period` (dipanggil `w_fa_generate` via Embedded SQL `DECLARE … PROCEDURE FOR …`).
- Tabel: `FA_CATEGORY`, `FA_ASSET`, `FA_DEPRECIATION`, `FA_PERIOD`, `FA_ASSET_AUDIT` (sudah ada).

## Menu
Tambahkan item menu untuk membuka: `w_fa_category`, `w_fa_master`, `w_fa_generate`,
`w_rpt_fa_register`, `w_rpt_fa_card`, `w_rpt_fa_rekap` (pola sama seperti membuka `w_gl_category`).

## Alur pemakaian
1. **Master Kategori** (`w_fa_category`) — sudah ter-seed 5 kategori; cek mapping akun.
2. **Master Aktiva** (`w_fa_master`) — pilih kategori → akun & umur ekonomis default terisi otomatis.
3. **Generate Penyusutan** (`w_fa_generate`, pola `w_report`) — isi **Dari/Sampai Tanggal** di kriteria
   (default bulan berjalan), klik tombol **Proses** (cb_tampil) → konfirmasi → menjalankan `sp_fa_generate_sl` +
   `sp_fa_post_period` per bulan (voucher `FA<site><yyyymm>`, modul_id='FA') lalu menampilkan hasil di `dw_2`.
   Idempotent: jalankan ulang = regenerate periode itu.
4. **Laporan** (pola `w_report`): set kriteria di `dw_1` → klik tombol **Tampilkan** (cb_tampil) → data tampil di `dw_2`;
   tombol **Print**/**Excel** dari toolbar `w_report` juga aktif. Tombol refresh ancestor juga ikut memicu `cb_tampil`.
   - Tiap window punya tombol sendiri (`cb_tampil`) + `dw_2.SetTransObject(sqlca)` sebelum retrieve, jadi tidak bergantung wiring toolbar ancestor.
   - Posisi tombol: x=1198 (di sisi kanan strip kriteria). Geser di painter bila perlu.
   - Daftar Aktiva (`w_rpt_fa_register`): semua aset per site.
   - Rekap Penyusutan (`w_rpt_fa_rekap`): isi rentang tanggal (default bulan berjalan).
   - Kartu Aktiva (`w_rpt_fa_card`): pilih aset di dropdown lalu Preview.

## Catatan
- Penyusutan **Jan–Jun 2026 sudah diposting** (rebase ke modul FA) saat migrasi. Untuk Jul 2026+,
  gunakan `w_fa_generate`.
- `acquisition_cost` per-aset hasil impor WP perlu rekonsiliasi akuntan (lihat `STATUS_production_readiness.md`).
  Total per kategori sudah cocok GL; jurnal & penyusutan tidak terpengaruh.
