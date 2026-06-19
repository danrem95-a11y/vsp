# Memo Rekonsiliasi Final — Modul Fixed Asset vs WP_Aset tetap_TAM 2026 vs GL

**Tanggal:** 2026-06-20
**DB:** `vspnew` (DSN vsp, site 101) | **Sumber:** `WP_Aset tetap_TAM 2026-rekonsiliasi.xlsx`
**Cutoff saldo awal:** 31/12/2025 | **Source of truth saldo:** `gl_balance` Period `2026-01-01`

---

## 1. Ringkasan Eksekutif

Modul penyusutan (perhitungan + jurnal 2026) **valid dan tidak bermasalah**. Seluruh selisih yang sempat dicurigai sebagai "master aset rusak total" **terjelaskan** dan sebagian besar **gugur** setelah arbitrase saldo GL:

- **Tidak ada bug perhitungan.** Engine, FA_DEPRECIATION, dan jurnal GL Jan–Jun 2026 cocok dengan WP (±pembulatan).
- **Tab JURNAL summary di WP maju 1 tahun** untuk akumulasi penyusutan (mencatat saldo *setelah* penyusutan 2026 sebagai "saldo awal"). Cutoff 31/12/2025 yang benar ada di **tab detail WP = basis DB = GL**. Ini sumber kebingungan awal.
- **Yang benar-benar tersisa = kelengkapan migrasi master aset** (bukan kesalahan logika): Tanah & 6 bangunan habis-susut belum dimuat; Kendaraan dimuat dari audit-listing sedangkan GL memakai basis per-book.

---

## 2. Arbitrase GL (penentu source of truth)

Saldo GL per 31/12/2025 (`gl_balance` Period 2026-01-01, rupiah bulat):

| Akun | Nama | GL 31/12/2025 | = Detail WP? | = JURNAL summary? |
|---|---|---:|:--:|:--:|
| 158-001 | Akum. Bangunan | 1.469.198.392 | ✅ (1.469.198.390) | ❌ (1.617.241.158) |
| 158-101 | Akum. P.Kantor | 845.637.756 | ✅ (=DB 845.637.757) | ❌ (891.750.125) |
| 158-201 | Akum. P.Bengkel | 130.925.053 | ✅ (=DB 130.925.057) | ❌ (154.479.765) |
| 158-301 | Akum. Kendaraan | 2.638.959.761 | ✅ (book 2.638.959.753) | ❌ (3.078.050.010) |

**Putusan:** GL = **Detail WP / basis DB / cutoff 31/12/2025**. Tab JURNAL summary maju 1 tahun → **bukan acuan saldo awal**. Tidak ada isu cutoff sistemik.

---

## 3. Status Modul (Perhitungan & Jurnal) — VALID

| Area | Status | Bukti |
|---|:--:|---|
| Engine penyusutan (straight-line, NBV÷sisa umur) | ✅ | per kategori per bulan = WP §4 ±Rp0,03 |
| FA_DEPRECIATION Jan–Jun 2026 (539 baris) | ✅ | total = WP |
| Jurnal GL FA101202601–06 (6 voucher) | ✅ | Dr 412-066 = Σ Cr 158-xxx, balanced, rupiah bulat |
| Replikasi WP & voucher | ✅ | selisih kumulatif Jan–Jun Rp1,64 (pembulatan) |

> Catatan minor: voucher FA Jan–Jun masih `posting='N'` (open). Keputusan set ke `'P'` ditunda sampai dipastikan tidak ada proses posting/closing finance yang menunggu (lihat §6).

---

## 4. Status Master Aset (rekonsiliasi ke GL 31/12/2025)

### Akun aset (cost)
| Akun | GL | DB FA | Selisih | Status |
|---|---:|---:|---:|---|
| 151-001 Tanah | 17.934.062.500 | 0 | −17.934.062.500 | ⚠️ belum dimuat (11 bidang) |
| 151-100 Bangunan | 3.712.136.932 | 3.317.636.932 | −394.500.000 | ⚠️ 6 aset habis-susut belum dimuat |
| 153-001 P.Kantor | 950.446.516 | 959.181.516 | +8.735.000 | ✅ benar (2 aset perolehan Jan-2026, pasca-cutoff) |
| 154-001 P.Bengkel | 221.324.363 | 221.324.363 | 0 | ✅ cocok persis |
| 155-001 Kendaraan | 5.223.064.476 | 6.974.040.958 | +1.750.976.482 | ⚠️ DB=audit-listing, GL=book |

### Akun akumulasi
| Akun | GL | DB FA | Selisih | Status |
|---|---:|---:|---:|---|
| 158-001 Bangunan | 1.469.198.392 | 1.074.698.390 | −394.500.002 | ⚠️ = 6 aset hilang (akum=cost) |
| 158-101 P.Kantor | 845.637.756 | 845.637.757 | +1 | ✅ |
| 158-201 P.Bengkel | 130.925.053 | 130.925.057 | +4 | ✅ |
| 158-301 Kendaraan | 2.638.959.761 | 2.731.459.753 | +92.499.992 | ⚠️ basis audit-listing |

### Per kategori
| Kategori | Status |
|---|---|
| **Peralatan Bengkel** | ✅ Cocok persis (cost & akum = GL) |
| **Peralatan Kantor** | ✅ Benar — selisih Rp8.735.000 = 2 aset perolehan Jan-2026 (PKT-0177 AC GREE 7.950.000 + PKT-0178 Monitor 785.000), benar belum di GL 31/12/2025 |
| **Bangunan** | ⚠️ 32 aset cocok persis; 6 aset 2014 habis-susut (Rp394,5 jt) belum dimigrasi (GL sudah memuatnya) |
| **Tanah** | ⚠️ 11 bidang (Rp17,93 M) belum dimigrasi (GL sudah memuatnya) |
| **Kendaraan** | ⚠️ 8 aset cacat migrasi (akum=0) + DB pakai audit-listing (6,974 M) sedangkan GL pakai book (5,223 M) → beda Rp1,751 M |

---

## 5. Detail Temuan Kendaraan (untuk audit trail)

**8 aset cacat migrasi** (semua habis-susut per WP, tapi akum/NBV salah di DB):

| Asset | Cost | DB akum/NBV | Target (per WP) | Tipe |
|---|---:|---|---|---|
| KDR-0002 | 193.897.458 | 0 / 0 | akum=cost, NBV=0 | A: akum & NBV kosong |
| KDR-0003 | 176.885.845 | 0 / 0 | akum=cost, NBV=0 | A |
| KDR-0004 | 175.911.139 | 0 / 0 | akum=cost, NBV=0 | A |
| KDR-0026 | 245.194.040 | 0 / cost | akum=cost, NBV=0 | B (ASET TA) |
| KDR-0028 | 180.150.000 | 0 / cost | akum=cost, NBV=0 | B (ASET TA) |
| KDR-0029 | 180.150.000 | 0 / cost | akum=cost, NBV=0 | B (ASET TA) |
| KDR-0030 | 180.150.000 | 0 / cost | akum=cost, NBV=0 | B (ASET TA) |
| KDR-0031 | 178.638.000 | 0 / cost | akum=cost, NBV=0 | B (ASET TA) |

Tipe A (Rp546.694.442) = inkonsistensi internal (cost≠akum+NBV). Tipe B (Rp964.282.040) = ASET TA habis-susut, internal-konsisten tapi NBV salah penuh.

**Basis audit-listing vs book** (terdokumentasi di WP sheet Kendaraan baris 64–92): listing audit 6.974.040.958 → (−785.644.040 OKT/NOP/DES 2022) → per-book 6.188.396.918 → (−965.332.442 5 aset) → **book 5.223.064.476 = GL**. PAJE audit (Dr 412-066 / Cr 158-301, "kurang catat beban penyusutan") **belum dibukukan**; GL berdiri di sisi book.

### 5.1 Dekomposisi gap Rp1.750.976.482 ke level aset (terverifikasi DB)

| Komponen | Aset | Cost | Penyusutan 2026 | Bisa diselaraskan turun? |
|---|---|---:|---:|:--:|
| **5 aset tanpa penyusutan 2026** | KDR-0016 Camry (240 jt), KDR-0031 (178,6 jt), KDR-0002 (193,9 jt), KDR-0003 (176,9 jt), KDR-0004 (175,9 jt) | 965.332.442 | 0 | secara mekanis ya, **tapi** Camry NBV 147,5 jt = aset riil → butuh bukti disposal |
| **Uplift cost Expander** | KDR-0017/0018/0019 (Okt/Nov/Des 2022) | 785.644.040 | Jan–Jun **115.018.443,75 (terposting)** | ❌ TIDAK — penyusutan 2026 Expander dihitung atas basis audit & sudah terposting (cocok WP). Menurunkan basis = membongkar jurnal tervalidasi |

Gap akumulasi (158-301) DB−GL = 92.499.992 ≈ **seluruhnya = akum Camry (92.500.000)**.

**Kesimpulan analitis:** GL Kendaraan **under-state** (kurang catat aset riil Camry + uplift Expander), bukan DB yang over-state. Karena itu **menyelaraskan register turun ke GL = mustahil tanpa menghapus aset riil dan/atau membatalkan validasi jurnal 2026**. Maksimum yang dapat dicapai aman = 6.008.708.516 (masih Rp785,6 jt > GL).

---

## 6. Dampak

**TIDAK mempengaruhi:** penyusutan 2026, FA_DEPRECIATION, jurnal/voucher FA Jan–Jun 2026 (semua sudah valid & cocok GL untuk pergerakan).

**Mempengaruhi:** kesesuaian register aset terhadap GL, Laporan Aktiva Tetap / Kartu Aktiva, dan kesiapan audit.

---

## 7. Paket Koreksi

### Paket A — AMAN dieksekusi (value-neutral, tidak menyentuh jurnal/penyusutan)
File: `fa_10_koreksi_paket_A.sql`
1. Tambah **6 aset Bangunan** habis-susut (cost=akum, NBV=0) → BGN cost→3.712.136.932 & akum→1.469.198.390 = GL.
2. Tambah **11 master Tanah** (non-depresiasi, akum=0) → 151-001 = 17.934.062.500 = GL.
3. Koreksi **KDR-0002/0003/0004** (set akum=cost, NBV=0) → hilangkan inkonsistensi internal.

> Catatan: aset Bangunan baru fully-depreciated (book_value=0, sisa umur 0) dan Tanah non-depresiasi → **engine menghasilkan 0 penyusutan** untuk mereka. Wajib verifikasi pasca-insert: total FA_DEPRECIATION 2026 tidak berubah.

### Paket B — Kendaraan: KEPUTUSAN DIAMBIL = dokumentasikan sebagai PAJE pending
**Keputusan (2026-06-20):** register FA Kendaraan **TETAP pada basis audit-listing (6.974.040.958)** — basis yang lebih lengkap dan konsisten dengan penyusutan 2026 yang sudah tervalidasi & terposting. Gap Rp1.750.976.482 vs GL book (5.223.064.476) **dicatat sebagai reconciling item / PAJE audit yang belum diposting** (dekomposisi di §5.1), **dieskalasikan ke akuntan/auditor**. TIDAK ada penghapusan aset, TIDAK ada jurnal yang dibongkar.

Item yang tetap menunggu keputusan akuntan (tidak menghalangi operasi):
1. **Apakah & kapan PAJE audit diposting** untuk membawa GL ke basis audit (menaikkan 155-001/158-301). Bila tidak, gap tetap jadi reconciling item permanen.
2. **5 aset TA Kendaraan** (KDR-0026/0028/0029/0030/0031) — set akum=cost/NBV=0 agar register internal-konsisten (tetap di register, tidak dihapus). Dapat dimasukkan ke paket koreksi lanjutan setelah disetujui.
3. **Status posting voucher FA Jan–Jun** (`N`→`P`) — setelah verifikasi tidak ada double-posting / proses closing finance.

---

## 8. Kesimpulan

Modul penyusutan **layak produksi dari sisi perhitungan & jurnal**. Register aset **belum layak dijadikan sumber resmi** sampai Paket A dieksekusi. Setelah Paket A: **Bangunan, Tanah, P.Kantor, P.Bengkel tie penuh ke GL**.

Untuk **Kendaraan**, register sengaja dipertahankan pada basis audit-listing (lebih lengkap & konsisten dengan jurnal tervalidasi); selisih Rp1,751 M terhadap GL **bukan defect kalkulasi** melainkan **PAJE audit yang belum diposting**, dan didokumentasikan penuh (§5.1) sebagai reconciling item untuk akuntan/auditor. Dengan ini seluruh area rekonsiliasi **tertutup**: yang valid dinyatakan valid, yang perlu data ditambah lewat Paket A, dan yang perlu kebijakan diserahkan ke akuntan dengan bukti lengkap.
