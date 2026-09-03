# LAPORAN HASIL — Implementasi Business Rule Final Costing WIP-Out

Tanggal: 2026-08-11

## 1. File yang Berubah

| File | Status |
|---|---|
| `n_cst_closing_stock.sru` | ✅ Diubah (4 edit) |
| `w_refresh_transaksi_modern.srw` | ✅ Diubah (1 restrukturisasi) |
| `w_refresh_journal.srw` | Tidak diubah — diverifikasi saja (lihat §6) |
| `f_transfer_cons.srf` | Tidak diubah — diverifikasi saja, sudah sesuai |

## 2. Lokasi Backup

| File asli | Backup |
|---|---|
| `n_cst_closing_stock.sru` | `n_cst_closing_stock.sru.backup_before_costing_redesign` |
| `w_refresh_transaksi_modern.srw` | `w_refresh_transaksi_modern.srw.backup_before_costing_redesign` |

Kedua backup adalah salinan PERSIS sebelum edit apa pun disentuh (dibuat otomatis oleh skrip, diverifikasi ukuran byte sama dengan file asli sebelum proses berjalan).

## 3. Detail Perubahan

### 3.1 `n_cst_closing_stock.sru`

**EDIT1 — FREEZE '88' (baris ~150-162), hapus guard immutable-forever**
- Sebelum: `WHERE ... AND (TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2) AND (ISNULL(TSALES2.HPP,0) = 0) ;`
- Sesudah: `WHERE ... AND (TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2) ;`
- Efek: refresh bulan X sekarang membangun ulang SEMUA WIP-Out bulan X (rentang `:ldt_tgl1`-`:ldt_tgl2`), bukan hanya yang HPP-nya masih 0. Batas proteksi = rentang tanggal refresh, BUKAN status HPP.

**EDIT2 — step 4a "Update HPP Penjualan reguler" (baris ~502-513), hapus referensi `closing_avg` sirkular**
- Sebelum: `HRG = ISNULL(NULLIF(h.closing_avg,0), (opening+beli)/(qty))` — `closing_avg` dibaca dari SINV saldo PENUTUPAN bulan yang sedang dihitung (mengandung efek penjualan itu sendiri).
- Sesudah: `HRG = (ISNULL(h.opening_nilai,0)+ISNULL(h.beli_nilai,0)) / NULLIF(ISNULL(h.opening_qty,0)+ISNULL(h.beli_qty,0),0)` — murni dari sisi MASUK (opening+beli+ekspedisi+mutasi_masuk+retur_jual), tidak pernah bergantung pada HPP penjualan bulan yang sama.
- Efek: menutup bug compounding yang merusak TS.066-8344C/TS.102-1081.

**EDIT3 — step 4c "Update HPP Adjustment Stok" (baris ~559-568), fix identik EDIT2**

**EDIT4 — FREEZE '88' tier1 (baris ~150-157), baur average bulan berjalan**
- Sebelum: `HRG = SUM(SINV.HPP_AVG) WHERE PERIODE=:ldt_tgl1` — HANYA saldo AWAL bulan (penutupan bulan lalu), tidak memasukkan pembelian/koreksi bulan yang SEDANG direfresh.
- Sesudah: `HRG = (opening_nilai+beli_nilai)/(opening_qty+beli_qty)` dari `costing_helper_movavg` — membaur saldo awal DENGAN pembelian/ekspedisi/mutasi-masuk/retur-jual bulan yang direfresh.
- Efek: memenuhi skenario test case Bapak — "Koreksi Plus tanggal Juli" (tercatat via tipe_trans '09' Mutasi Masuk, sudah tercakup formula) sekarang IKUT membentuk average Juli, bukan diabaikan.

### 3.2 `w_refresh_transaksi_modern.srw`

**Restrukturisasi — pindahkan pemanggilan costing engine dari dalam `of_refresh_so()` (bergantung checkbox 'SO') ke level TOP, dijalankan SELALU sebelum dispatch modul apa pun.**
- Dihapus dari `of_refresh_so()` (bekas baris ~878-896): blok "Update HPP Average" + pemanggilan `n_cst_closing_stock.of_run()`.
- Disisipkan di level klik-refresh utama, tepat sebelum `if cb_so.checked then of_run_modul('SO')` dst (bekas baris ~3044-3046): blok costing yang SAMA (variabel diganti nama `lnv_close_top`/`li_closerc_top` agar tak bentrok scope, tanggal pakai `f_bom(datetime(ld1))` sesuai variabel level-atas), lengkap dengan penanganan gagal yang benar (reset `ib_running=false`, update `refresh_ledger` status='ERROR', reset teks tombol) — mengikuti pola cleanup yang SUDAH ada di akhir handler yang sama.
- Efek: costing engine (freeze WIP-Out + average) SEKARANG SELALU jalan begitu user klik Refresh, apa pun checkbox modul yang dicentang — menutup celah "user centang Cons OUT saja → costing tidak pernah jalan".

## 4. Bukti Encoding UTF-16LE Terjaga

Setiap skrip edit memverifikasi BOM (byte `FF FE`) SEBELUM dan SESUDAH penulisan:
```
n_cst_closing_stock.sru       : BOM sebelum=True, BOM sesudah=True (tiap dari 2 tahap edit)
w_refresh_transaksi_modern.srw: BOM sebelum=True, BOM sesudah=True
```
Semua penulisan memakai `UnicodeEncoding($false,$true)` (UTF-16LE, BOM eksplisit), line-ending dinormalisasi CRLF konsisten setelah setiap edit.

**Insiden dan mitigasi**: Pada percobaan pertama EDIT4, kesalahan anchor (`) HPP` dengan spasi, seharusnya `)HPP` tanpa spasi) menyebabkan penghapusan blok yang jauh lebih besar dari yang dimaksud (~13.900 karakter, meliputi TIER-3 fallback, loop penulisan SINV, dan lainnya). **Terdeteksi sebelum menyebabkan kerusakan permanen** karena backup sudah ada — file langsung di-restore dari backup, EDIT1/2/3 diterapkan ulang, dan EDIT4 diulang dengan anchor yang benar PLUS sanity-check keras (panjang blok wajib <250 karakter, selisih ukuran file wajib <400 byte, sebelum diizinkan menulis). Kondisi file SEKARANG sudah diverifikasi bersih dan sesuai rencana.

## 5. Hasil Test Scenario

**Catatan metodologi**: karena saya tidak punya akses compiler PowerBuilder/deploy ke server (write-blocked ke prod, tidak bisa build EXE), validasi berikut adalah **penelusuran logika SQL** terhadap formula yang SUDAH tertulis di source (bukan eksekusi live). Validasi live memerlukan Bapak build+deploy lalu jalankan skenario nyata.

**Skenario**: Juli WIP-Out 10 unit avg=2.000 → EVAP A001-A010 HPP=2.000. Juli jual 2 unit HPP=2.000, outstanding 8 unit HPP=2.000. Agustus: Koreksi Plus (tipe_trans '09') tanggal Juli menambah nilai stok Juli sehingga average SEHARUSNYA jadi 3.000. User jalankan **Refresh Juli**.

**Penelusuran dengan kode BARU**:
1. Refresh Juli diklik → blok costing baru (top-level, EDIT restrukturisasi §3.2) jalan SELALU, terlepas checkbox → `n_cst_closing_stock.of_run(f_bom(Juli), ...)`.
2. `costing_helper_movavg` diisi ulang (baris 84-111, TIDAK diubah): `opening_qty/nilai` = SINV di awal Juli; `beli_qty/nilai` = SEMUA tipe_trans '02'/'05'/'09'/retur-jual TANGGAL DI JULI — **koreksi plus (tipe '09') yang baru diinput di Agustus tapi TANGGAL Juli IKUT TERTANGKAP** di sini (filter `TSTOK1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2`, bukan tanggal INPUT).
3. FREEZE '88' (EDIT1+EDIT4) jalan: guard `HPP=0` sudah hilang → SEMUA 10 EVAP Juli (A001-A010, termasuk yang HPP-nya sudah 2.000) DIHITUNG ULANG dari `costing_helper_movavg` yang BARU (opening+beli TERMASUK koreksi plus) = **3.000**. HPP EVAP A001-A010 di-UPDATE dari 2.000 → **3.000**.
4. Step 4b (tidak diubah, sudah benar sejak awal — copy `MAX(HPP)` dari '88' ke penjualan EVAP yang sama, TANPA guard) jalan dalam rentang tanggal Juli yang sama → 2 unit penjualan Juli (EVAP-nya match) ikut ter-update ke **3.000**.
5. Outstanding 8 unit: nilainya melekat di baris '88' sendiri (langsung ter-update di langkah 3) = **3.000**.
6. `f_transfer_cons.srf` (tidak diubah, sudah benar): saat ConsOUT untuk voucher Juli di-retrieve ulang (butuh rentang refresh mencakup Juli), delete+insert GL_JOURNAL 102-020 memakai `TSALES2.HPP` TERKINI (sekarang 3.000) → ledger ikut konsisten.

**Kesimpulan penelusuran**: formula BARU secara logis menghasilkan **3.000** di semua titik (EVAP, penjualan Juli, outstanding), sesuai skenario wajib. **Syarat**: journal (GL 102-020) baru ikut konsisten JIKA modul ConsOUT/ConsIN untuk voucher Juli juga diproses ulang dalam refresh yang sama rentang tanggalnya (sesuai temuan audit sebelumnya — `f_transfer_cons` hanya delete+insert untuk voucher yang ikut ter-retrieve pada rentang tanggal yang dipilih).

## 6. Risiko yang Masih Tersisa

1. **`w_refresh_journal.srw` masih mesin costing terpisah** — tidak memanggil `n_cst_closing_stock` sama sekali, punya UPDATE HPP sendiri (tanpa freeze/tier1-2-3, tanpa fix EDIT2-4). Kalau window LAMA ini pernah dijalankan alih-alih versi modern, HPP hasil rebuild yang baru saja diperbaiki berisiko tertimpa lagi oleh formula lama yang lebih primitif. **Belum diperbaiki** (di luar scope eksplisit permintaan kali ini — hanya diminta verifikasi, bukan ubah).
2. **Belum ada test live** — semua di atas adalah penelusuran logika terhadap source, bukan hasil eksekusi nyata. Perlu build + deploy + uji di data test/staging sebelum dipercaya di prod.
3. **Kode "Koreksi Plus/Minus" tidak eksplisit di sistem ini** — investigasi menemukan tidak ada tipe_trans khusus utk itu; kemungkinan besar direkam via '09' (Mutasi Masuk, sudah tercakup). Perlu konfirmasi operasional dari tim Bapak bahwa ini memang cara pencatatan yang dipakai — kalau ternyata ada kode LAIN yang belum masuk `costing_helper_movavg`, perlu ditambahkan.
4. **Efek pada 63 baris (TR+NR) yang sudah dikoreksi manual sebelumnya** — begitu engine baru di-build dan Jan-Jun direfresh ulang, SEMUA WIP-Out (termasuk yang sudah saya koreksi manual via RUNBOOK) akan DIHITUNG ULANG dari nol memakai formula baru. Kemungkinan besar akan konvergen ke nilai yang SAMA (karena formula baru inilah yang seharusnya dipakai sejak awal), tapi ini WAJIB diverifikasi ulang setelah build — jangan asumsikan otomatis sama.
5. **Komentar di baris 146-149 (`n_cst_closing_stock.sru`) sekarang basi** — masih menjelaskan perilaku lama ("DIKUNCI... refresh berikutnya melewatinya"). Tidak memengaruhi fungsi (murni komentar), tapi sebaiknya diperbarui saat sempat agar tidak menyesatkan pembaca berikutnya.
