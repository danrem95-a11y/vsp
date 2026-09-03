# UI SPEC — Dropdown Bulan + Tahun (opsional, dikerjakan di PB IDE visual)

## Status kebutuhan (PENTING)
Jaminan **fungsional** period-isolation SUDAH terpenuhi tanpa dropdown:
- **Default sysdate:** `w_refresh_transaksi_modern` event `open` (L2265-2266) mengisi
  `dt_from = f_bom(gdt_today)`, `dt_to = f_eom(gdt_today)` = **bulan berjalan penuh**.
- **Single-month / no cross-month:** blok P1 (event MULAI REFRESH) memaksa 1 bulan penuh
  via `f_bom`/`f_eom` apa pun yang diketik user.
- **All-period:** checkbox `cb_all_period`.

Jadi dropdown ini **kosmetik** (UX lebih jelas). Dikerjakan di **PB IDE** agar layout & instansiasi
window bisa diverifikasi visual — JANGAN hand-edit control array via teks (risiko window gagal load).

## Langkah di PowerBuilder IDE (w_refresh_transaksi_modern)
1. Di groupbox `gb_period`, tambah 2 **DropDownListBox**:
   - `ddlb_bulan` — items: `Januari`..`Desember` (12), allowedit=false.
   - `ddlb_tahun` — items: tahun relevan, mis `2024`,`2025`,`2026`,`2027`,`2028`.
   - `AllowEdit = false`, `VScrollBar = true`.
2. Event `open` (tambahkan setelah baris default sysdate):
   ```
   ddlb_bulan.text = string(month(date(gdt_today)))   // atau SelectItem sesuai indeks bulan
   ddlb_tahun.text = string(year(date(gdt_today)))
   ```
   (Set default ke bulan & tahun sysdate — sinkron dengan dt_from/dt_to.)
3. Fungsi kecil (atau langsung di kedua event) untuk sinkronkan ke date pickers:
   ```
   integer li_b, li_y
   date ld_b
   li_b = ddlb_bulan.index            // 1..12
   li_y = integer(ddlb_tahun.text)
   if li_b < 1 or isnull(li_y) then return
   ld_b = date(li_y, li_b, 1)
   dt_from.text = string(f_bom(datetime(ld_b)),'dd-mm-yyyy')
   dt_to.text   = string(f_eom(datetime(ld_b)),'dd-mm-yyyy')
   ```
4. Panggil fungsi itu di `ddlb_bulan.selectionchanged` dan `ddlb_tahun.selectionchanged`.
5. (Opsional) Sembunyikan/disable `dt_from`/`dt_to` agar user hanya lewat dropdown; TETAPI biarkan
   keduanya sebagai sumber nilai (P1 normalisasi tetap jaring pengaman).

## Kenapa aman
- Tidak mengubah logika refresh — hanya mengisi `dt_from`/`dt_to` yang sudah ada.
- P1 normalization tetap menormalkan ke 1 bulan penuh, jadi walau dropdown salah pun isolasi terjaga.
- Semua verifikasi correctness (INV-01..05, opening=closing, idempotent) tak bergantung pada widget ini.
