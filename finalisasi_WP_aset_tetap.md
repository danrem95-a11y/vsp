# Finalisasi `WP_Aset tetap_TAM 2026.xlsx` — Parameter Penyusutan & Saldo Awal

**Tanggal:** 2026-06-17
**Sumber:** `C:\BTV\debug\WP_Aset tetap_TAM 2026.xlsx` (6 sheet: Kendaraan, Bangunan, Tanah, Perl. Kantor, Perl. Bengkel, JURNAL)
**Status:** Parameter penyusutan FINAL & terverifikasi. Saldo awal & target jurnal 2026 diambil dari sheet `JURNAL` (otoritatif — sudah dijumlah & direkonsiliasi di dalam workbook).

> ⚠️ **Catatan entitas.** Header sheet `JURNAL` = **PT. THERMO ASRI MAKMUR (TAM)**, sedangkan `gl_site.company_site` di DB `vsp` = "PT.VARIA PERDANA KARYA". **Kode akun pada Excel cocok 100% dengan COA DB** (158-001/101/201/301, 412-066, 151/153/154/155), jadi pemetaan tetap valid. Perlu konfirmasi: apakah `vsp` memang DB milik TAM (label `gl_site` stale) atau ada pemisahan entitas. Tidak menghambat desain.

---

## 1. Parameter Kategori — FINAL (audited, straight-line, residu 0)

| Kategori (sheet) | category_code | COA Aset | COA Akumulasi | COA Beban | Umur (bln) | Tarif/th | Residu | Metode |
|---|---|---|---|---|---|---|---|---|
| Bangunan | BGN | 151-100 | 158-001 | 412-066 | **120** | 10% | 0 | Straight line |
| Kendaraan | KDR | 155-001 | 158-301 | 412-066 | **96** | 12,5% | 0 | Straight line |
| Peralatan Kantor | PKT | 153-001 | 158-101 | 412-066 | **48** | 25% | 0 | Straight line |
| Peralatan Bengkel | PBK | 154-001 | 158-201 | 412-066 | **96** | 12,5% | 0 | Straight line |
| Tanah | TNH | 151-001 | — | — | 0 | 0 | — | Tidak disusutkan |

**Koreksi penting vs draft desain awal:** Bangunan = **120 bulan (10 th)**, bukan 240. Semua kategori **residu = 0** (NBV mendarat di 0 saat akhir umur). Umur ekonomis adalah **per-aset** (kolom *Life → Audited → Month*); tabel di atas adalah nilai dominan/default per kategori (umur unaudited "Awal" 48 bln tidak dipakai untuk buku komersial).

> Catatan tarif: workbook punya 2 basis — *Awal/Unaudited* (mis. kendaraan 25%/4th) dan *Penyesuaian/Audited* (12,5%/8th). **Buku komersial yang dijurnal memakai basis Audited.** Kolom "TA" (Tax Adjustment) di sheet JURNAL semuanya 0 → hanya 1 buku (Normal/komersial) yang diposting.

---

## 2. Formula Penyusutan — FINAL (reproduksi Excel persis)

Terbukti dari aset aktif 2026 (residu 0):
- Bangunan `T 93/02/18`: cost 56.400.000 ÷ 120 = **470.000/bln** = Excel JAN ✓
- Perl. Kantor `23012004P069`: cost 4.700.000 ÷ 48 = **97.916,67/bln** = Excel ✓
- Perl. Bengkel `T122/10/19`: cost 24.818.182 ÷ 96 = **258.522,73/bln** = Excel ✓

**Formula engine (go-forward, robust untuk aset re-lifed audit):**
```
monthly = ROUND( (book_value_beginning - residual_value) / remaining_useful_months , 2 )
        di mana book_value_beginning = acquisition_cost - accum_dep_beginning (per 31/12/2025)
              remaining_useful_months = umur_audited - bulan_berjalan s/d 31/12/2025
Berhenti saat akumulasi mencapai (acquisition_cost - residual_value); bulan terakhir = sisa.
```
Untuk aset yang umurnya tidak pernah diubah, rumus ini identik dengan `cost / useful_life_month`. Untuk aset yang di-relife saat audit (mis. sebagian Bangunan 4→10 th), rumus berbasis **NBV ÷ sisa umur** inilah yang mereproduksi angka 2026 di Excel — **disarankan dipakai sebagai basis impor saldo awal** (impor `accum_dep_beginning` + `remaining_useful_months` per aset, bukan sekadar cost/life).

---

## 3. Saldo Awal per 31/12/2025 — per Kategori (dari sheet JURNAL, baris 22–28)

Kolom workbook: AKTIVA(cost) | PENYUSUTAN 2026 | AKUM 31/12/2025 | NBV 31/12/2025 | AKUM 31/12/2026 | NBV 31/12/2026.

| Kategori | Harga Perolehan | Akum. Peny. 31/12/2025 | NBV 31/12/2025 | Penyusutan 2026 (setahun) |
|---|---:|---:|---:|---:|
| Tanah | 17.934.062.500,00 | 0,00 | 17.934.062.500,00 | 0,00 |
| Bangunan | 3.712.136.932,00 | 1.617.241.158,17 | 2.094.895.773,83 | 148.042.768,26 |
| Peralatan Kantor | 959.181.516,00 | 891.750.125,46 | 67.431.390,54 | 46.112.368,08 |
| Peralatan Bengkel | 221.324.363,08 | 154.479.764,60 | 66.844.598,48 | 23.554.707,88 |
| Kendaraan | 5.223.064.476,00 | 3.078.050.010,13 | 2.145.014.465,88 | 439.090.256,79 |
| **TOTAL** | **28.049.769.787,08** | **5.741.521.058,35** | **22.308.248.728,73** | **656.800.101,02** |

**Target rekonsiliasi GL per 31/12/2025** (sub-ledger FA harus = saldo akun GL; saldo awal TIDAK dijurnal ulang):
| Akun GL | Nama | Saldo target |
|---|---|---:|
| 151-001 | Tanah (D) | 17.934.062.500,00 |
| 151-100 | Bangunan (D) | 3.712.136.932,00 |
| 153-001 | Peralatan Kantor (D) | 959.181.516,00 |
| 154-001 | Peralatan Bengkel (D) | 221.324.363,08 |
| 155-001 | Kendaraan (D) | 5.223.064.476,00 |
| 158-001 | Akum. Bangunan (K) | 1.617.241.158,17 |
| 158-101 | Akum. Peralatan Kantor (K) | 891.750.125,46 |
| 158-201 | Akum. Peralatan Bengkel (K) | 154.479.764,60 |
| 158-301 | Akum. Kendaraan (K) | 3.078.050.010,13 |

> Langkah verifikasi (saat engine SQLA hidup): bandingkan saldo `gl_balance`/mutasi GL per 31/12/2025 vs tabel di atas. Selisih harus 0 sebelum go-live.

---

## 4. Target Jurnal Penyusutan Jan–Jun 2026 (dari sheet JURNAL) — yang harus direproduksi `f_fa_post_journal`

Struktur tiap bulan: **Dr 412-066** (total) ; **Cr 158-001/158-301/158-101/158-201** (per kategori).

| Bulan | Dr 412-066 (Total) | Cr 158-001 Bangunan | Cr 158-301 Kendaraan | Cr 158-101 P.Kantor | Cr 158-201 P.Bengkel |
|---|---:|---:|---:|---:|---:|
| **JAN** | 57.203.299,04 | 14.300.641,11 | 36.888.945,01 | 4.017.695,60 | 1.996.017,32 |
| **FEB** | 56.075.183,60 | 13.395.442,33 | 36.666.028,34 | 4.017.695,60 | 1.996.017,32 |
| **MAR** | 55.690.604,06 | 13.049.987,78 | 36.666.028,34 | 3.978.570,60 | 1.996.017,32 |
| **APR** | 55.214.815,77 | 12.574.199,50 | 36.666.028,34 | 3.978.570,60 | 1.996.017,32 |
| **MEI** | 55.165.128,27 | 12.574.199,50 | 36.666.028,34 | 3.978.570,60 | 1.946.329,82 |
| **JUN** | 54.798.516,91 | 12.207.588,14 | 36.666.028,34 | 3.978.570,60 | 1.946.329,82 |
| **Jan–Jun** | **334.147.547,64** | 78.102.058,34 | 220.219.086,72 | 23.949.673,62 | 11.826.728,93 |

Catatan akurasi:
- Nilai bulanan **menurun** karena sebagian aset mencapai akhir umur di tengah tahun (Kantor turun di MAR, Kendaraan di FEB, Bengkel di MEI, Bangunan menurun bertahap). Engine per-aset dengan aturan "berhenti di akhir umur" mereproduksi pola ini otomatis.
- Toleransi pencocokan ±0,01 (pembulatan 2 desimal per kategori per bulan).

---

## 5. Populasi Aset (indikatif) & catatan ekstraksi per-aset

| Kategori | Jumlah aset (indikatif) | Catatan |
|---|---|---|
| Peralatan Kantor | ±91 | layout sheet rapi, ekstraksi per-aset OK |
| Peralatan Bengkel | ±28 | OK |
| Bangunan | ±10+ | sebagian re-lifed → impor pakai NBV+sisa umur |
| Kendaraan | (parser undercount) | **layout merged-cell lebih lebar**, butuh peta kolom khusus untuk impor per-aset |
| Tanah | ASET TA: Sukoharjo, Semarang, Surabaya, dst | non-depreciable, hanya master |

> Untuk impor `FA_ASSET` per-aset (Tahap 4) perlu extractor dengan **peta kolom per-sheet** (Kendaraan & Bangunan berbeda dari Kantor/Bengkel karena kolom *Life* punya sub-kolom Awal/Penyesuaian). Field yang diimpor per aset: Tanggal Perolehan, Deskripsi, Harga Perolehan (Audited), Umur Audited (bln), Akum 31/12/2025, NBV 31/12/2025. Saldo awal level **kategori** (untuk rekonsiliasi GL) sudah final di §3.

---

## 6. Dampak ke Desain (update `design_modul_fixed_asset.md`)

1. Seed `FA_CATEGORY` dikoreksi: Bangunan `useful_life_month=120` (bukan 240); residu 0 semua. (Lihat seed di §6.1.)
2. Formula engine: pakai **NBV ÷ sisa umur** (bukan cost/life) agar aset re-lifed cocok dengan Excel.
3. `FA_ASSET` impor wajib bawa `accum_dep_beginning`, `book_value_beginning`, dan **sisa umur (remaining_useful_months)** per aset — tambah kolom `remaining_life_begin integer` jika ingin eksplisit (opsional; bisa diturunkan dari umur & tgl perolehan, tapi untuk aset re-lifed lebih aman disimpan eksplisit).
4. Validasi go-live: total Jan–Jun engine = §4; saldo awal per kategori = §3.

### 6.1 Seed FA_CATEGORY (final)
```sql
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES
('101','BGN','Bangunan',         '151-100','158-001','412-066',120,0,'Y'),
('101','KDR','Kendaraan',        '155-001','158-301','412-066', 96,0,'Y'),
('101','PKT','Peralatan Kantor', '153-001','158-101','412-066', 48,0,'Y'),
('101','PBK','Peralatan Bengkel','154-001','158-201','412-066', 96,0,'Y'),
('101','TNH','Tanah',            '151-001', NULL,     NULL,       0,0,'N');
```

---

*Parameter penyusutan FINAL. Yang masih perlu: (a) konfirmasi entitas TAM vs Varia; (b) extractor per-aset Kendaraan/Bangunan untuk impor master FA_ASSET (Tahap 4); (c) verifikasi saldo GL 31/12/2025 vs §3 saat engine SQLA hidup.*
