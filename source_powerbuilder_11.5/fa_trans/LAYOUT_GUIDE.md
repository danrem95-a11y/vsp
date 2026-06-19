# Panduan Merapikan Layout DataWindow (PowerBuilder 11.5)

> Catatan: seluruh `.srd` di `fa_trans` & `fa_reports` sudah di-regenerate dengan layout
> rapi (label & kolom tidak lagi tumpang tindih). Panduan ini untuk tweak lanjutan di IDE.

## 0. Pilih Presentation Style yang tepat
- **Entry 1 record** (`dw_fa_*_entry`, `dw_fa_generate_param`) → **Freeform**.
- **List/laporan** (`dw_fa_*_list`, `dw_rpt_fa_*`, `dw_fa_generate_preview`) → **Grid** (atau Tabular).
  Grid mengunci kolom ke sel sehingga tidak mungkin tumpang tindih.

## 1. Alignment (label sejajar kolom)
1. Buka DataWindow → tab **Design**.
2. Sorot label + kolomnya (klik label, Ctrl+klik kolom).
3. **Format ▸ Align ▸ Top** (sejajar horizontal/baris yang sama).
4. Untuk meratakan SEMUA label dalam satu kolom vertikal: sorot semua label (`*_t`) → **Format ▸ Align ▸ Left**.
   Lakukan hal sama untuk semua kolom data → **Align ▸ Left**.
5. Aktifkan **Design ▸ Grid** (snap) + set spacing grid (mis. X=12, Y=12) agar objek "nempel" ke grid.

## 2. Spacing (jarak antar baris)
- Freeform yang disarankan: tinggi baris ± **100 PBU** (kontrol ± 76 PBU + jeda 24 PBU).
- Sorot ≥3 kontrol yang berurutan → **Format ▸ Space ▸ Down ▸ Equally** (samakan jarak vertikal),
  atau **Space ▸ Across ▸ Equally** untuk grid.
- Beri margin kiri ± 40 PBU; label `x=40`, kolom `x=560` (sudah diset di file).

## 3. Tab Order (urutan kursor)
1. **Format ▸ Tab Order** (atau Shift+Ctrl+T) → muncul angka kuning di tiap kolom.
2. Klik tiap kolom berurutan **atas→bawah** dan ketik nilai naik (10, 20, 30, …).
   Kolom read-only beri **0** (di-skip saat Tab).
3. Shift+Ctrl+T lagi untuk keluar. (File sudah memberi tabsequence 10,20,30… sesuai urutan field.)

## 4. Auto-arrange objek yang tumpang tindih
- **Format ▸ Align / Space / Size** = perataan otomatis (bukan drag manual).
- **Format ▸ Size ▸ Same Width / Same Height** untuk menyamakan ukuran kolom sejenis.
- Jika label ada di band salah: drag ke band benar (label kolom di band **header** untuk Grid,
  atau di band **detail** untuk Freeform). Cek via **View ▸ Control List** untuk melihat band tiap objek.
- **Cara tercepat bila masih kacau:** hapus DataWindow, **New ▸ DataWindow ▸ Grid/Freeform**,
  pilih tabel `FA_*`, PB akan menata otomatis; lalu sesuaikan judul kolom & format.

## 5. Format kolom (kerapian angka/tanggal)
- Angka uang: **format** `#,##0.00`; integer: `#,##0`; tanggal: `dd-mm-yyyy` (sudah diset).
- Right-align kolom angka: pilih kolom → Properties ▸ Alignment ▸ Right.

## 6. Setelah edit
Save → **Full Build** → jalankan window untuk cek visual.
