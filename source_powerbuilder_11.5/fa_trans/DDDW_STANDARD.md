# Standar DropDownDataWindow (DDDW) — Modul FA (acuan untuk seluruh ERP)

## Root cause tampilan terpotong
`dddw.percentwidth` = lebar dropdown sebagai **persen dari lebar kolom induk**, BUKAN absolut.
Nilai `0` (atau 100) → dropdown selebar kolom (~520 PBU) → kolom nama akun terpotong.

## Aturan baku (sudah diterapkan di FA)
1. **Lebar dropdown target ≈ 1850 PBU** (cukup kode + nama 50 karakter).
   `dddw.percentwidth = round(1850 / lebar_kolom_induk * 100)`  (clamp 150–600).
   - kolom 520 → percentwidth 356; kolom 360 → 514; kolom 420 → 440.
2. **Child DataWindow**: 2 kolom — `kode` (±380 PBU) + `nama/deskripsi` (±1450 PBU). Total ±1830.
3. `dddw.lines = 12` (baris terlihat), `dddw.vscrollbar = yes`, `dddw.allowedit = yes` (ketik utk filter).
4. Child DW di-`SELECT` ringkas (`kode, deskripsi`) + `ORDER BY kode`, filter `DetailYN='1'` utk COA.
5. displaycolumn = nama (informatif) atau kode (ringkas); datacolumn = kode (nilai disimpan).

## Override runtime (bila perlu, tanpa re-import) — taruh di `ue_postopen`/constructor
```powerscript
// 1) Perbesar lebar dropdown (relatif kolom)
dw_1.Modify("asset_account.dddw.percentwidth='356'")
dw_1.Modify("accum_dep_account.dddw.percentwidth='356'")
dw_1.Modify("dep_expense_account.dddw.percentwidth='356'")

// 2) Perbesar kolom di child DataWindow (lebar isi dropdown)
DataWindowChild ldwc
IF dw_1.GetChild("asset_account", ldwc) = 1 THEN
   ldwc.Object.accountcode.Width = 380
   ldwc.Object.accountdes.Width  = 1450
END IF
```
Catatan: `Width` dalam PB Unit (PBU), bukan pixel. 1 PBU ≈ 1/4 char rata-rata pada font Tahoma -10.
