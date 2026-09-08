# Catatan Perubahan — `w_refresh_journal.srw`

**File:** `w_refresh_journal.srw` (Window "Refresh Transaksi", PowerBuilder 11.5 / Sybase SQL Anywhere 9)
**Encoding:** UTF-16LE + BOM, CRLF (dipertahankan, kompatibel import PB 11.5)
**Ukuran akhir:** 167.124 bytes / 2.708 baris
**Backup tersedia:**
- `w_refresh_journal.srw.bak` — kondisi asli (sebelum semua patch)
- `w_refresh_journal.srw.bak2` — setelah PATCH A+B (sebelum PATCH C)
- `w_refresh_journal.srw.bak_wipin` — sebelum PATCH WIP-In

---

## Ringkasan singkat

Ada **3 kelompok perbaikan** untuk masalah "data nyangkut yang tak bisa dihapus dari menu",
semuanya mengikuti prinsip yang sama: **bersihkan record 'yatim' secara otomatis saat Refresh**.

| Grup | Masalah | Tombol | Status |
|---|---|---|---|
| Pembayaran (TBYR) | Baris pelunasan yatim & dobel | AR (`cb_5`), AP (`cb_7`) | Terpasang |
| WIP / Konsinyasi (TSTOK) | WIP In nyangkut di bulan lama | Cons IN (`cb_14`) | Terpasang |

---

## Detail perubahan

### 1. PATCH A — Bersihkan baris pembayaran YATIM (TBYR)
**Lokasi:** tombol **AR** (`cb_5`, ~baris 1416) dan tombol **AP** (`cb_7`, ~baris 1853)
**Titik sisip:** sebelum blok `//Delete old data`

**Masalah yang diperbaiki:**
Saat voucher pembayaran dihapus (mis. lewat menu "Hapus Data GL"), jurnal GL-nya hilang
tetapi baris pelunasan di `TBYR1`/`TBYR2` tertinggal ("yatim"). Refresh lama menghapus
berbasis voucher yang masih ada di GL, sehingga baris yatim tidak pernah tersentuh dan
terus muncul di Opname Faktur. (Kasus: United Dico, LIKIANG.)

**Yang dilakukan patch:**
Sebelum membentuk ulang data, hapus baris `TBYR1`/`TBYR2` dengan `kas_id = 0`
(baris hasil-refresh) yang **`voucher_manual`-nya sudah tidak ada di `gl_journal`**.
Baris kas asli (`kas_id <> 0`) TIDAK tersentuh.

---

### 2. FIX B — Perbaiki bug DELETE ganda tbyr1
**Lokasi:** tombol **AR** (`cb_5`, ~baris 1462)

**Masalah yang diperbaiki:**
Ada dua statement `DELETE FROM tbyr1` berturut-turut; yang pertama **tanpa `using sqlca;`**
sehingga tidak ter-terminate dengan benar (perilaku tak menentu).

**Yang dilakukan patch:**
Digabung menjadi SATU statement `DELETE` dengan `using sqlca;` + guard error
(`if sqlca.sqlcode < 0 then rollback ...`).

---

### 3. PATCH C — Peringatan dini pembayaran DOBEL
**Lokasi:** tombol **AR** (`cb_5`, ~baris 1496) dan tombol **AP** (`cb_7`, ~baris 1925)
**Titik sisip:** setelah refresh sukses, sebelum `close(w_wait)`

**Masalah yang diperbaiki:**
Satu pembayaran bisa tercatat 2x di subledger (baris kas + baris-R kembar dengan
`voucher_manual` & nilai sama), sehingga Opname menghitung ganda. (Kasus: United Dico.)

**Yang dilakukan patch:**
Setelah refresh, deteksi faktur yang punya pola dobel PRESISI
(`voucher_manual` sama + `nilai_bayar` sama + ada baris kas DAN baris-R) pada periode
refresh. Bila ada, tampilkan **kotak peringatan** ("cek di Opname sebelum tutup buku").
- Hanya PERINGATAN, tidak menghapus.
- Dilewati saat proses `ib_silent` (batch).
- Logika presisi (bukan sekadar "voucher muncul >1x") agar tidak false-alarm untuk
  cicilan sah.

---

### 4. PATCH WIP-IN YATIM — Perbaiki WIP In lintas-bulan (TSTOK)
**Lokasi:** tombol **Cons IN** (`cb_14`, ~baris 2457)
**Titik sisip:** sebelum blok `//1. Re-transfer Konsinyasi IN`

**Masalah yang diperbaiki:**
Ketika faktur diperbaiki tanggalnya lintas bulan (mis. Juni -> Juli) setelah sudah
di-refresh, record WIP In turunannya (`TSTOK1` tipe 88) tetap bertanggal di bulan lama
(Juni). Refresh lama memproses order per-periode, sehingga order yang "lepas periode"
tidak dipanggil ulang -> WIP In nyangkut di bulan salah. (Kasus: CIM1096224 / faktur 03.2607002.)

**Yang dilakukan patch:**
Cursor mendeteksi WIP In yang jatuh di **BULAN berbeda** dari faktur induknya
(`tstok1` t88 vs `tsales1` t22, relasi `bukti_id = '101'+substr(w.bukti_id,4)`), lalu
memanggil `f_insert_cons_in(faktur)` untuk **menghapus record lama by BUKTI_ID +
membentuk ulang dari tanggal faktur terbaru**.

**Kenapa kriteria BEDA BULAN (bukan beda tanggal):**
Saldo stok (SINV) dihitung per BULAN. WIP In yang beda-hari tapi sama-bulan tetap jatuh
di periode SINV yang benar (stok tidak salah) = sah. Hanya yang beda-BULAN jatuh di
periode SINV yang salah -> itulah "turunan tidak sesuai" yang wajib dibentuk ulang.
Ini perbaikan akar (deteksi periode-stok-salah), bukan tambal.
Terverifikasi: menyasar tepat 1 record (CIM1096224); 6 record sah 2022 (beda hari,
sama bulan) TIDAK tersentuh.

---

## Cara kerja perbaikan (prinsip umum)

Ketiga grup patch mengatasi pola bug yang sama: **record turunan menjadi "yatim"**
ketika dokumen induk berubah (dihapus / diperbaiki tanggal) tetapi proses refresh lama
hanya membersihkan berdasarkan periode/kondisi terkini. Perbaikannya: refresh sekarang
**secara aktif mendeteksi & membereskan record yatim** — dihapus (TBYR) atau
dihapus+dibentuk-ulang (WIP) — sehingga tidak lagi perlu perbaikan manual per kasus.

---

## Kompatibilitas & pengujian

- File tetap UTF-16LE + BOM + CRLF (0 lone-LF) — valid untuk import PB 11.5.
- Struktur `type ... end type` tidak tersentuh; hanya kode di dalam event.
- Semua guard `if sqlca.sqlcode < 0` berpasangan `end if`.

**WAJIB sebelum produksi:**
1. Import ke PowerBuilder 11.5 dan pastikan **compile bersih** (compile PB sungguhan
   belum diuji di luar PB).
2. Uji di DATABASE COPY: buat record yatim buatan, jalankan Refresh, pastikan
   yatim hilang/terbentuk-ulang dan record sah TIDAK tersentuh.
3. Backup `tbyr1`/`tbyr2`/`tstok1`/`tstok2` sebelum Refresh pertama di prod.

**Catatan batasan:**
- PATCH A memakai `kas_id = 0` sebagai penanda baris hasil-refresh. Bila ada modul lain
  yang membuat baris `kas_id=0` sah tanpa pasangan `gl_journal` (mis. DP/jaminan
  tertentu), perlu ditambah pengecualian. Pada data saat ini tidak ada masalah.
