# PB 11.5 Rekon Dashboard — Paket Import (POLA LEGACY w_report)

Objek disesuaikan dengan pola legacy `fa_reports`: **window turun dari ancestor `w_report`**, memakai `dw_1` (filter) + `dw_2` (report) bawaan, event `ue_retrieve`/`ue_print`/`ue_xls`, tombol `cb_tampil`, drill `doubleclicked` + `openwithparm(var, parm, "classname")`, parameter antar-window delimiter **`|`**.

## Prasyarat library (WAJIB)
Target PBL (mis. `dashboard.pbl`) harus punya di **library list**-nya:
- ancestor **`w_report`** (dari `lib.pbl`), plus global yang dipakainya:
  `sqlca`, `gdt_today`, `f_bom`, `gurningsoft_xls`, `w_prompt_print`, `MenuID`.
  (Sama seperti yang dipakai window `fa_reports` — jika FA report jalan, prasyarat ini sudah ada.)

## Prasyarat DB
Deploy objek rekon dulu (lihat `DEPLOY_RUNBOOK_rekon.md`): `rekon_account_map`, `v_rekon_*`,
`v_rekon_gl_bridge`, `rekon_snapshot_v2`, `sp_rekon_anomali`, `sp_rekon_snapshot_build`,
lalu `CALL sp_rekon_snapshot_build(2026,4);`. Sebelum itu retrieve = 0 baris (normal).

## Urutan IMPORT (DataWindow dulu → Window)
**9 DataWindow (.srd):**
1. `d_rekon_periode` (filter `dw_1` — WAJIB, dipakai semua window)
2. `dw_rekon_summary`, `dw_rekon_ap_final`, `dw_rekon_ar_final`, `dw_rekon_stok_final`,
   `dw_rekon_gl_bridge`, `dw_rekon_detail_voucher`, `dw_rekon_anomali`, `dw_rekon_snapshot_v2`

**8 Window (.srw)** (semua `from w_report`):
`w_rekon_dashboard`, `w_rekon_ap`, `w_rekon_ar`, `w_rekon_stok`,
`w_rekon_voucher_detail`, `w_rekon_gl_bridge`, `w_rekon_anomali`, `w_rekon_snapshot`

Lalu **Full Build**. Menu → `Open(w_rekon_dashboard)`.

## Alur navigasi (pola legacy)
```
w_rekon_dashboard  (dw_2=dw_rekon_summary; filter dw_1=periode; tombol Tampilkan/Anomali/Snapshot)
  doubleclick domain →  openwithparm("AP|<periode>", "w_rekon_ap")  (dst AR/STOK)
w_rekon_ap / w_rekon_ar  (per vendor/customer)
  doubleclick →  "AP|<entity>|<periode>" → w_rekon_voucher_detail
w_rekon_stok  doubleclick →  "STOK|<akun>|<periode>|" → w_rekon_gl_bridge
w_rekon_voucher_detail  doubleclick voucher →  "<dom>||<periode>|<voucher>" → w_rekon_gl_bridge
w_rekon_gl_bridge  (baris gl_journal = titik audit)
w_rekon_anomali  (dw_2 external diisi sp_rekon_anomali via DECLARE PROCEDURE; doubleclick = root voucher)
w_rekon_snapshot (dw_2=dw_rekon_snapshot_v2; tombol Build → sp_rekon_snapshot_build)
```
Parameter di-`open;call super::open;` baca `Message.StringParm`, di-`pos/mid` split by `|`,
isi `dw_1` periode, lalu `cb_tampil.triggerevent(clicked!)`. Retrieve di `cb_tampil::clicked`
(ambil periode dari `dw_1.object.periode[1]` → derive thn/bln). Ekspor Excel/print
otomatis dari `w_report` (`ue_xls`/`ue_print` → `dw_2`).

## Struktur tiap window (identik FA)
```
global type w_xxx from w_report ...  cb_tampil ...
event open;call super::open; <parse param + trigger tampil>
on create: call super::create + create cb_tampil (+ tombol ekstra)
on destroy: call super::destroy + if IsValid(MenuID) then destroy(MenuID)
event ue_print / ue_xls  (dw_2)
type dw_1 from w_report`dw_1  → dataobject "d_rekon_periode"; constructor set periode default
type dw_2 from w_report`dw_2  → dataobject "<grid DW>"; ue_retrieve→cb_tampil; doubleclicked→drill
type cb_tampil ... event cb_tampil::clicked; dw_2.SetTransObject(sqlca); dw_2.retrieve(...)
```

## Catatan
- Encoding semua file = **UTF-16LE + BOM** (sama seperti export PB asli).
- Nama vendor/customer/COA: DataWindow menampilkan `vendor_id`/`cust_id`/`account_id`;
  join nama master (MCSTSUPP/MCUST/GL_ACC) opsional — verifikasi kolom ke skema dulu.
- `w_rekon_anomali.dw_2` = DataWindow **external** (tanpa retrieve SQL) — diisi script SP;
  jangan panggil `dw_2.Retrieve()` langsung padanya (sudah lewat `cb_tampil`).
- Layout/warna rapikan di painter bila perlu; struktur & SQL sudah final.
