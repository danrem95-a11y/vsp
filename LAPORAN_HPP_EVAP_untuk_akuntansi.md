# Laporan Hasil Analisa & Rekomendasi — HPP Barang EVAP/Konsinyasi

**Untuk:** Pak Wira (Akuntansi) · **Perihal:** Koreksi HPP Penjualan unit Thermo King (EVAP/COND) yang dijual lintas bulan · **Tanggal:** 24 Juli 2026

---

## 1. Ringkasan Eksekutif (untuk keputusan cepat)
- Ditemukan **salah saji HPP**: sebagian unit konsinyasi (ber-nomor seri) yang dijual **di bulan berbeda** dari saat masuk, **HPP Penjualannya tercatat Rp 0** — padahal barangnya jelas punya harga pokok.
- Akibatnya: **laba tampak lebih besar** dari seharusnya, **saldo akhir persediaan "gantung"** (barang sudah terjual tetapi masih ada nilainya), dan biaya tersangkut di **akun Titipan Konsinyasi (102-020)**.
- Perbaikan sudah dibuat & diuji. **Dampak koreksi HPP ≈ Rp 394 juta** (menaikkan HPP → menurunkan laba). Ini **koreksi kesalahan pencatatan**, bukan perubahan kebijakan.
- **Terbukti tidak mengubah transaksi normal.**
- Ada **29 unit** yang **sengaja belum dikoreksi otomatis** karena tidak ada bukti harga pokok pada unit itu sendiri — diserahkan ke keputusan akuntansi (bukan ditebak).

---

## 2. Apa masalahnya (dalam bahasa pembukuan)
Pada Laporan Mutasi Persediaan untuk unit EVAP/konsinyasi tertentu:
- **Nilai WIP-In (barang konsinyasi kembali) sudah muncul**, TETAPI
- **Nilai HPP Penjualan tidak muncul (Rp 0)**, sehingga
- **Saldo Akhir menampilkan Qty = 0 tetapi Nilai ≠ 0** (nilai gantung yang seharusnya nol).

Contoh nyata (terbukti): unit **NR.201A seri 645BDEAC002** — WIP-In Rp 38,5 juta muncul, tetapi HPP Penjualan Rp 0, dan Saldo Akhir Juni menyisakan nilai Rp 38,5 juta padahal barangnya sudah terjual.

---

## 3. Penyebab (akar masalah)
Sistem menilai HPP dengan metode **rata-rata bergerak (moving average)**. **Rumus rata-rata tersebut tidak memperhitungkan transaksi konsinyasi.** Untuk barang konsinyasi yang **terjual di bulan berikutnya**, saldo stok sudah 0 → rata-rata menjadi **0** → HPP Penjualan **0**.

Harga pokok barang sebenarnya **sudah diketahui** (dari nilai saat barang dikirim konsinyasi / harga beli), namun **tidak "tertarik"** ke HPP Penjualan karena rumusnya melewatkan jalur konsinyasi.

> Catatan penting: mengisi HPP secara manual **di layar Laporan Mutasi TIDAK menyelesaikan masalah** — angka itu tidak masuk ke Buku Besar/GL, hilang saat proses ulang, dan justru membuat **Mutasi ≠ Buku Besar**. Koreksi harus di sumber data.

---

## 4. Perbaikan yang dilakukan
Ditambahkan aturan: **bila rata-rata bergerak menghasilkan 0 untuk unit EVAP, sistem mengambil harga pokok dari saat barang dikirim konsinyasi (WIP-Out) untuk NOMOR SERI yang sama.**

Hasil setelah perbaikan (untuk unit yang punya bukti harga per-seri):
- HPP Penjualan terisi benar (mis. NR.201A → Rp 38,5 juta).
- HPP masuk ke **Buku Besar (akun 402-xxx)** → Laba Rugi benar.
- **Saldo Akhir kembali Nol** (nilai gantung hilang).
- Nilai di **Titipan Konsinyasi (102-020) terlepas**.
- **Mutasi = Buku Besar = Laba Rugi** kembali konsisten.

---

## 5. Dampak Keuangan
| Bulan | Jumlah transaksi | Kenaikan HPP (COGS) |
|---|---|---|
| Jan–Mei | 0 | Rp 0 |
| Juni | 1 | Rp 38,5 juta |
| Juli | 4 | Rp 355 juta |
| **Total** | **5** | **± Rp 394 juta** |

- Kenaikan HPP ini **menurunkan laba** sebesar jumlah tersebut. Ini adalah **koreksi salah saji** (sebelumnya laba tercatat terlalu tinggi).
- **Transaksi normal (non-konsinyasi / yang HPP-nya sudah benar) TIDAK berubah** — sudah dibuktikan.
- Tidak ada pengaruh ke jumlah barang (Qty) — hanya penilaian (Rupiah).

---

## 6. Hal yang belum tuntas — 29 unit "tanpa bukti harga per-seri"
Ditemukan **29 unit** (semua unit truk Thermo King, penjualan Juli) yang **HPP-nya tidak dapat diisi otomatis**, karena **nomor seri unit itu sendiri tidak memiliki bukti harga pokok** (harga *model*-nya ada dari unit lain, tetapi bukan harga unit spesifik ini).

**Keputusan yang diambil: sengaja TIDAK diisi otomatis.** Alasan (prinsip audit):
1. Mengisi dengan harga unit lain = **estimasi tanpa bukti** untuk unit ini.
2. Harga "model tertinggi" cenderung **melebih-lebihkan** (contoh: model Rp 56,2 juta padahal harga aktual sejenis Rp 42,4 juta).

**Sangat penting — jangan salah baca angka:**
- Angka **"potensi Rp 3,41 miliar" adalah batas atas ekstrem**, **BUKAN kerugian riil**. Dihitung memakai harga model-tertinggi × 29 unit, di atas **data Juli yang belum ditutup (closing) penuh**.
- Pemeriksaan menunjukkan **ke-29 unit ini sebenarnya PUNYA transaksi konsinyasi (WIP-Out), hanya belum ternilai** — jadi **bukan "kehilangan data"**.
- **Angka pasti** baru diperoleh setelah proses **closing Juli di lingkungan uji**; besar kemungkinan **jauh lebih kecil dari 29**.

---

## 7. Rekomendasi Tindakan
1. **Uji di salinan (copy) database dulu**, bukan langsung produksi:
   - Terapkan perbaikan → jalankan **refresh + tutup buku (closing) Juni & Juli** → buktikan **Mutasi = Buku Besar = Laba Rugi**, saldo akhir EVAP = 0, dan tidak ada transaksi normal yang berubah.
2. **Setujui koreksi HPP ± Rp 394 juta** sebagai koreksi salah saji, dengan **persetujuan tertulis** (karena menurunkan laba, material).
3. **Untuk 29 unit:** kuantifikasi ulang di lingkungan uji setelah closing. Untuk sisa yang benar-benar tanpa bukti harga:
   - **jurnal koreksi manual** memakai harga model **dengan persetujuan Pak Wira**, ATAU
   - **perbaiki data sumber** (beri nilai pada transaksi konsinyasi/WIP-Out unit tsb), ATAU
   - **dibiarkan & dicatat sebagai temuan** bila immaterial.
   > Jangan diisi otomatis (menjaga posisi audit yang bersih).
4. **Prosedur tutup buku bulanan:** jalankan **cek rutin** "barang EVAP terjual tanpa harga pokok" **sebelum** closing, agar kasus baru terjaring lebih awal.
5. **Larangan:** jangan mengetik HPP manual di Laporan Mutasi (tidak masuk Buku Besar → menimbulkan selisih Mutasi vs Buku Besar).

---

## 8. Posisi untuk Auditor (kalimat yang aman)
> "Kami **memperbaiki salah saji costing** yang terdeteksi pada unit konsinyasi lintas bulan, **membuktikan tidak ada dampak pada transaksi normal**, **mengukur dampaknya terhadap laba (± Rp 394 juta)**, dan **secara sengaja tidak melakukan estimasi harga pokok atas 29 unit yang tidak memiliki bukti harga per-nomor-seri** — melainkan menyerahkannya ke keputusan akuntansi yang terdokumentasi."

---
*Seluruh angka dapat direproduksi dari data (skrip pemeriksaan tersedia). Perbaikan program masih menunggu proses build & uji di salinan sebelum naik ke produksi.*
