# DRAFT JURNAL PENYESUAIAN (AJE) & ANALISA — Akun 102-601 "Persediaan Dlm. Perjalanan - Invoice Principle"

> **Status: DRAFT untuk ditinjau & disetujui Akuntan/Manajemen. BELUM diposting.**
> Mencakup 2 hal yang perlu persetujuan: **(1)** koreksi saldo legacy migrasi, dan **(2)** kapitalisasi Bea Masuk impor yang terhapus akibat eksekusi perbaikan data April 2026.
> Mekanisme program (jurnal ekspedisi/impor) **sudah benar** — tidak ada perubahan kode.

| | |
|---|---|
| Database | `vspnew` (PRODUKSI, 103.233.89.43:2638, host SERVER-NEW, SQL Anywhere 11) |
| Akun utama | **102-601** — Persediaan Dlm. Perjalanan - Invoice Principle (Neraca) |
| Tanggal audit | 21-Jun-2026 |
| Saldo 102-601 saat ini | **(142.711.816)** — saldo KREDIT (abnormal untuk akun aset) |
| Sumber angka | `gl_journal` produksi (601.855 baris); skrip diag121–diag129 |

---

## 1. Ringkasan eksekutif

Saldo 102-601 = **(142.711.816)** terurai menjadi tiga komponen:

| Kode | Komponen | Nilai | Sifat | Tindakan |
|---|---|---:|---|---|
| **B** | Legacy "stuck" pra-2017 (migrasi 2015–2016) | **(261.216.836)** | Selisih saldo-awal tak pernah clear | **Tindakan 1 — AJE koreksi** |
| **A1** | Open in-transit 2026 — **macet** (BM impor tak terkapitalisasi akibat eksekusi Skenario B) | **39.636.000** | Seharusnya masuk persediaan; macet | **Tindakan 2 — kapitalisasi** |
| **A2** | Open in-transit 2026 — **sehat** (barang masih di perjalanan) | **78.869.020** | Akan clear sendiri | Biarkan |
| | **Saldo total** | **(142.711.816)** | = B + A1 + A2 | |

Setelah Tindakan 1 + 2 dieksekusi, saldo 102-601 akan menjadi **+78.869.020 (debet, normal)** = hanya barang impor yang benar-benar masih dalam perjalanan.

---

## 2. Temuan & Analisa

### 2.1 Mekanisme 102-601 sudah benar (bukan bug program)
102-601 adalah akun **clearing barang-dalam-perjalanan (landed cost impor)**:
- **Di-DEBET** oleh jurnal manual modul **CO** saat biaya impor timbul (Bea Masuk/PIB, freight, agency fee, LS).
- **Di-KREDIT** oleh modul **EX** (transfer ekspedisi) saat biaya dikapitalisasi ke persediaan (`Dr 102-101 / Cr 102-601`).

Verifikasi 2026: seluruh batch yang barangnya sudah datang sudah _matched_ sempurna debet↔kredit. **Tidak ada kesalahan logika program.**

### 2.2 Komponen B — Legacy migrasi 2015–2016 = (261.216.836)
Saldo akumulatif 102-601 **stabil di (261.216.836)** sejak akhir 2022 s/d akhir 2025 (lihat Lampiran A) = saldo yang tak pernah clear.

Penyebab (lihat Lampiran C): barang impor yang **sudah dalam perjalanan saat go-live sistem (akhir 2014)** tidak terbawa penuh sebagai **saldo awal debet** 102-601, sementara kredit kapitalisasinya tercatat penuh di 2015. Kasus terbesar **TK.107**: kredit kapitalisasi 318.957.000 vs debet yang masuk hanya 18.957.000 → kekurangan 300.000.000. Ini **murni isu saldo-awal/migrasi**, bukan transaksi berjalan.

### 2.3 Komponen A1 — Dampak eksekusi `eksekusi_perbaikan_data.txt` (Skenario B) = 39.636.000 macet
Pada **11-Jun-2026** dijalankan runbook `eksekusi_perbaikan_data.txt` jalur **Skenario B ("tagihan vendor tambahan DIBATALKAN")** untuk memperbaiki 2 dokumen ekspedisi April 2026. Bukti state produksi saat ini (Lampiran D):
- Jurnal EX dokumen freight **FR05001 & FR05002 = sudah DIHAPUS** (0 baris).
- `ap_trans` FR: `ttl_kotor`, `ttl_netto`, **`freight`** semuanya **0**.
- `tstok2` alokasi utama = 14.712.724 / 19.209.210 (**hanya ekspedisi LAKINDO; Bea Masuk dikeluарkan**).

**Akibat:** Bea Masuk (BM) impor untuk kedua batch **tidak ikut terkapitalisasi ke persediaan** dan **nyangkut sebagai debet di 102-601**:

| Dokumen barang | BM impor | Sumber |
|---|---:|---|
| 10126040500001 (TK.001-002) | 13.328.000 | PIB.000043 (12.149.000) + NOTUL (1.179.000) |
| 10126040500002 (TK.003-004) | 26.308.000 | PIB.000044 |
| **Total** | **39.636.000** | |

Konsekuensi akuntansi:
1. **Nilai persediaan / HPP barang impor TK.001-004 kurang (understated) sebesar 39.636.000** — BM adalah komponen sah _landed cost_ yang seharusnya menambah harga pokok barang.
2. Jumlah ini **tidak akan clear sendiri** lewat Refresh (karena `freight=0` & jurnal FR sudah dihapus) — berbeda dengan open in-transit sehat (A2).

**Catatan kontrol penting:** tabel backup `diag117_backup_tstok2 / _aptrans / _gl` **sudah tidak ada** di produksi, padahal runbook mensyaratkan tidak boleh di-drop sampai tutup buku. **Jaring pengaman rollback hilang** → sebelum eksekusi koreksi apa pun, WAJIB backup penuh database dahulu.

---

## 3. Tindakan yang diusulkan (perlu persetujuan akuntansi)

### TINDAKAN 1 — AJE koreksi saldo legacy 102-601 (261.216.836)
**Modul:** GJ (Jurnal Umum/Memorial) · **Tanggal:** `____` *(periode berjalan terbuka, mis. 30-Jun-2026)* · **Voucher:** otomatis `GJ<yymm><urut>`
**Keterangan:** `Koreksi saldo awal/migrasi Persediaan Dlm.Perjalanan (102-601) pra-2017 — selisih kapitalisasi impor 2014/2015 tanpa debet pasangan (dominan TK.107). Ref: audit 102-601 21-Jun-2026.`

| Urut | Account ID | Nama Akun | Debet | Kredit |
|---:|---|---|---:|---:|
| 1 | **102-601** | Persediaan Dlm. Perjalanan - Invoice Principle | **261.216.836** | — |
| 2 | **376-001** | Laba (Rugi) Ditahan Tahun-Tahun Lalu | — | **261.216.836** |
| | | **TOTAL** | **261.216.836** | **261.216.836** |

*Akun lawan (kredit): disarankan **376-001** (prior-period adjustment, karena legacy 2015–2016). Alternatif **376-101** Laba (Rugi) Tahun Berjalan bila manajemen ingin dampak di laba tahun berjalan. **Sisi Debet 102-601 261.216.836 bersifat tetap.***

### TINDAKAN 2 — Kapitalisasi Bea Masuk impor yang terhapus (39.636.000)
**Keputusan yang diminta:** BM impor 39.636.000 dikapitalisasi ke persediaan (perlakuan lazim landed cost) **[disarankan]**, atau dianggap batal.

**Bila disetujui dikapitalisasi**, tersedia 2 metode:

**Metode 2A (DISARANKAN — akurat sampai HPP per-item).** Dikerjakan IT via aplikasi: pulihkan nilai `freight` FR (13.328.000 / 26.308.000) **atau** rescale `tstok2` agar memuat BM (Skenario A: 28.040.724 / 45.517.210), lalu jalankan **Refresh Journal → EXP** periode April 2026. Aplikasi akan membentuk ulang jurnal `Dr 102-101 / Cr 102-601` dan HPP rata-rata ikut terkoreksi. *(= menerapkan Skenario A yang semestinya.)*

**Metode 2B (JE manual — hanya benar di GL, HPP per-item TIDAK terupdate):**

| Urut | Account ID | Nama Akun | Debet | Kredit | Ket |
|---:|---|---|---:|---:|---|
| 1 | 102-101 | Persediaan (barang impor TK.001-002) | 13.328.000 | — | Kapitalisasi BM PIB.000043+NOTUL |
| 2 | 102-601 | Persediaan Dlm. Perjalanan | — | 13.328.000 | |
| 3 | 102-101 | Persediaan (barang impor TK.003-004) | 26.308.000 | — | Kapitalisasi BM PIB.000044 |
| 4 | 102-601 | Persediaan Dlm. Perjalanan | — | 26.308.000 | |
| | | **TOTAL** | **39.636.000** | **39.636.000** | |

### TINDAKAN 3 (kontrol — wajib sebelum 1 & 2)
1. **Backup penuh database** (`dbbackup`) — karena backup `diag117_backup_*` sudah hilang.
2. Buat ulang backup baris yang akan disentuh (tstok2/ap_trans/gl_journal dokumen terkait) sebelum eksekusi.
3. Kebijakan ke depan: **jangan mengedit nilai faktur ekspedisi setelah dokumen tersimpan** (memicu mismatch); perbaikan window input agar edit memicu re-alokasi adalah _open item_ IT.

### Posisi 102-601 setelah seluruh tindakan
| Tahap | Saldo 102-601 |
|---|---:|
| Sekarang | (142.711.816) |
| Setelah Tindakan 1 (legacy) | 118.505.020 |
| Setelah Tindakan 2 (kapitalisasi BM) | **78.869.020** (= open in-transit sehat) |

---

## LAMPIRAN A — Timeline saldo akumulatif 102-601 per tahun

| Tahun | Debet | Kredit | Net tahun | **Saldo akumulatif akhir tahun** |
|---|---:|---:|---:|---:|
| 2015 | 3.050.037.309 | 3.240.711.417 | (190.674.108) | **(190.674.108)** |
| 2016 | 2.017.576.772 | 2.083.074.850 | (65.498.078) | **(256.172.186)** |
| 2017 | 1.835.252.015 | 1.837.618.265 | (2.366.250) | **(258.538.436)** |
| 2018 | 1.881.732.701 | 1.880.931.501 | 801.200 | **(257.737.236)** |
| 2019 | 1.462.803.138 | 1.440.636.208 | 22.166.930 | **(235.570.306)** |
| 2020 | 969.471.605 | 982.831.235 | (13.359.630) | **(248.929.936)** |
| 2021 | 653.229.000 | 662.612.300 | (9.383.300) | **(258.313.236)** |
| 2022 | 899.723.550 | 902.627.150 | (2.903.600) | **(261.216.836)** |
| 2023 | 586.105.125 | 586.105.125 | 0 | **(261.216.836)** |
| 2024 | 713.005.137 | 703.382.437 | 9.622.700 | **(251.594.136)** |
| 2025 | 500.545.302 | 510.168.002 | (9.622.700) | **(261.216.836)** |
| **2026** (s/d audit) | 308.518.894 | 190.013.874 | 118.505.020 | **(142.711.816)** |

→ Legacy (akhir 2025) = (261.216.836); + net 2026 +118.505.020 = saldo kini (142.711.816).

---

## LAMPIRAN B — Rincian open in-transit 2026 (+118.505.020)

| Batch | Komponen | Nilai | Status |
|---|---|---:|---|
| TK.001-002 | BM PIB.000043 (12.149.000) + NOTUL (1.179.000) | 13.328.000 | **MACET** — FR dihapus Skenario B (Tindakan 2) |
| TK.003-004 | BM PIB.000044 | 26.308.000 | **MACET** — FR dihapus Skenario B (Tindakan 2) |
| TK.006 | FREIGHT (42.866.020) + BM PIB.000046 (11.858.000) | 54.724.020 | Sehat — barang masih di perjalanan |
| SUM601D | LS | 24.145.000 | Sehat — barang masih di perjalanan |
| | **Total** | **118.505.020** | (39.636.000 macet + 78.869.020 sehat) |

*Semua batch 2026 yang barangnya sudah datang (TK.009, BN.507, TK.G504/G505, TK.A505/A601, SUM601A/B/C) sudah matched debet↔kredit secara penuh.*

---

## LAMPIRAN C — Bukti legacy & metodologi

### C.1 Kasus terbesar: TK.107 (≈ -300 jt)
| Tanggal | Modul | Debet | Kredit | Keterangan |
|---|---|---:|---:|---|
| 13-Feb-2015 | GJ | 18.957.000 | — | Persediaan Dlm.Perjalanan - Thermo King TK.107-241014 |
| 20-Feb-2015 | EX | — | 318.957.000 | (UNIT TRUCK THERMO KING) TK.107-241014, inv. 30006457 |

Barang dipesan 24-Okt-2014 (sebelum ledger dimulai 13-Feb-2015) → biaya in-transit ≈300 jt tidak terbawa sebagai saldo awal; hanya 18.957.000 yang masuk → kekurangan 300.000.000.

### C.2 Metodologi & keterbatasan
- **Andal:** saldo akumulatif per tahun (Lampiran A) + pencocokan manual aliran 2026 (Lampiran B). Angka AJE legacy **261.216.836** = floor akumulatif stabil akhir 2022–2025.
- **Tidak diandalkan:** pencocokan otomatis per-nilai antar baris, karena 1 kredit EX = penjumlahan beberapa komponen (BM+freight+LS+agency) lintas beberapa nomor TK.
- **Saran dokumentasi:** untuk audit, telusur manual saldo awal 102-601 ke dokumen PIB/impor 2014–awal 2015 (angka agregat sudah pasti; rincian per-item perlu dokumen fisik).

---

## LAMPIRAN D — Bukti state produksi pasca eksekusi Skenario B (per 21-Jun-2026)

| Cek | Hasil |
|---|---|
| Jurnal EX `1012604FR05001` & `1012604FR05002` | **0 baris (sudah dihapus)** |
| `ap_trans` FR05001 | ttl_kotor=0, ttl_netto=0, freight=0, kurs=6.407.300, kurs2=28.193.603 |
| `ap_trans` FR05002 | ttl_kotor=0, ttl_netto=0, freight=0, kurs=13.483.175, kurs2=59.327.578 |
| `ap_trans` MAIN 10126040500001/02 | ttl_kotor=14.712.724 / 19.209.210 (terkoreksi) |
| `tstok2` alokasi utama | 14.712.724 / 19.209.210 (LAKINDO saja, tanpa BM) |
| Tabel `diag117_backup_*` | **TIDAK ADA (hilang)** |

---

## LAMPIRAN E — Cara posting & verifikasi (read-only)

**Verifikasi saldo (PowerShell 32-bit):**
```sql
SELECT SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) saldo
FROM gl_journal WHERE account_id='102-601';
-- Sekarang                 : -142.711.816
-- Setelah Tindakan 1        :  118.505.020
-- Setelah Tindakan 1 + 2    :   78.869.020
```
Connection string produksi:
`DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta`

**Catatan:** mekanisme `f_transfer_freight` / `f_transfer_ekspedisi_new` **sudah benar dan tidak diubah**. Dokumen ini murni koreksi saldo akuntansi + pemulihan kapitalisasi BM yang terhapus saat perbaikan data April 2026.

---

### Lembar persetujuan

| Peran | Nama | Keputusan (Tindakan 1 / 2 / akun lawan) | Tanda tangan | Tanggal |
|---|---|---|---|---|
| Disusun (IT/Audit) | | | | |
| Diperiksa (Akuntansi) | | | | |
| Disetujui (Manajemen) | | | | |
