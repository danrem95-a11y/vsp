# DESIGN PERBAIKAN SUMBER TRANSAKSI — Movement Gap 2026 (DESIGN ONLY, belum ada SQL UPDATE)

> Recovery opening 2026 = **CLOSED/TERKUNCI, tidak disentuh.** Design ini read-only-analysis; **belum** membuat script koreksi. Semua koreksi (nanti) = **perbaiki data sumber transaksi**, bukan jurnal penyesuaian/balancing.

---

## 0. ⚠️ KOREKSI ROOT CAUSE (transparansi — wajib dibaca dulu)

Investigasi lebih dalam **ke kode engine `dw_refresh_stok`** (bukan asumsi) **membalik** root cause yang sebelumnya dilaporkan (RC-1 produk_id kosong / RC-2 currency / RC-3 TL orphan). Bukti:

| Klaim lama | Bukti pembatal (query read-only) | Verdict lama |
|---|---|---|
| RC-1: `produk_id` kosong → stok tak terbentuk | Engine join **`IM_PRODUK.PRODUK_ID = TSTOK2.STOK_ID`** (baris 141/160). Engine pakai **STOK_ID** (terisi), **bukan** `produk_id`. | **SALAH** |
| RC-2: valas tak dikonversi ke stok | Engine BELI = **`TSTOK2.NETTO × ISNULL(TSTOK1.KURS,1)`** (baris 150). Konversi SUDAH ada. | **SALAH** |
| RC-3: TL.203.0504 qty orphan | `tstok2.STOK_ID='TL.203.0504'` ADA beli 40.000 (AMARI) + issue; opening 4.472,80 +40.000 −15.970 −3.000 = **25.502,80 = sinv PERSIS** | **SALAH (bukan orphan)** |

**Bukti kunci menyeluruh:** engine-BELI dihitung ulang persis cara engine (STOK_ID × KURS, `ORDER_OKE='Y'`) = **GL PO ke rupiah di SEMUA 6 akun**:
`102-203 117.500.000=117.500.000 · 102-101 251.977.285,12=251.977.285,12 (termasuk USD) · 102-010 49.906.000 · 102-102 56.986.700 · 102-103 12.451.230 · 102-110 266.479.566,80`.
→ **Sisi pembelian SINKRON sempurna GL=stok.** produk_id & currency **bukan** penyebab.

---

## 1. ROOT CAUSE SEBENARNYA — Penjualan ber-HPP=0 (COGS tak tertangkap)

**Mekanisme (terbukti ke rupiah):**
1. Barang **dibeli** penuh → masuk GL persediaan **dan** stok (BELI engine = GL, cocok).
2. Barang **dijual** tetapi baris jual `tsales2.HPP = 0` → **COGS tidak dibukukan** (GL modul HP=0; stok JUAL_RP=0).
3. Saat qty item **net = 0** (dibeli+dijual habis dalam periode), engine `n_cst_closing_stock` menerapkan aturan **`qty=0 → nilai=0`** → **nilai beli dihapus dari stok**.
4. GL tak punya COGS untuk mengeluarkan nilai itu → **GL persediaan tetap menyimpan nilai beli**.
5. Hasil: **GL persediaan > stok** sebesar nilai beli yang **tak ter-COGS-kan**.

**Bukti rekonsiliasi (102-010):** BELI 49.906.000 − COGS_stok 19.110.000 − **zeroing 30.796.000** = 0 (stok) ; GL simpan 49,9−19,11 = **30.796.000 = gap**. Cocok persis. Untuk 102-203: 2/2 penjualan HPP=0 → gap = 117.500.000 (100%).

**Sebaran penjualan HPP=0 (Jan–Feb 2026):** 102-203 2/2 · 102-010 15/22 · 102-110 8/184 · 102-101 9/196 · 102-102 2/46 · 102-103 1/5. Contoh transaksi: `BF.01.0006`/`BF.01.0013`/`TYU-001` dijual HPP=0; `TYU-001B` kadang HPP benar 2.730.000, kadang 0.

---

## 2. TABEL RC (sumber → kolom → mekanisme → data → risiko → solusi aman)

| RC | Root Cause | Tabel | Kolom | Mekanisme bug | Data yang harus diperbaiki | Risiko jika langsung UPDATE | Solusi Aman |
|---|---|---|---|---|---|---|---|
| **RC-A** | Penjualan HPP=0 (COGS tak tertangkap) | **tsales2** | **HPP** (+ turunan COGS di gl_journal modul HP) | Moving-avg tak tertarik saat jual → COGS=0; qty=0 → engine nol-kan nilai beli; GL simpan nilai | HPP baris jual = **moving-avg cost tanggal jual** (yang benar) | Mengubah COGS → **mengubah HPP/Laba-Rugi & neraca**; re-refresh menggeser moving-avg bulan berikut; sebagian HPP=0 mungkin **disengaja** (model dasar/dummy) | Klasifikasi bug vs sengaja → daftar kandidat → **approval akuntansi** → isi HPP dari moving-avg → **re-refresh resmi** (bukan jurnal balancing) |

> Catatan: engine rule `qty=0→nilai=0` **benar secara fisik** (stok nol = nilai nol); yang salah adalah **COGS tak dibukukan saat jual**. Perbaikan menyasar **HPP jual**, bukan mematikan rule engine.

---

## 3. STRATEGI KOREKSI (per langkah, audit-safe)

### 3.1 Analisa dulu (JANGAN isi HPP membabi buta)
Untuk tiap baris jual `tsales2.HPP=0`, tentukan:
- **a. Apakah item memang punya cost?** Ada BELI/moving-avg > 0 pada periode ≤ tanggal jual? (bila ya → HPP=0 itu **bug**.)
- **b. Apakah HPP=0 disengaja?** Model dasar/dummy/sample yang cost-nya melekat di varian (mis. `TYU-001` base vs `TYU-001A/B` bervarian). (bila ya → **bukan** untuk dikoreksi.)
- **c. Apakah ambigu?** Cost tak jelas (beli lintas-periode, moving-avg 0 sah). → **STOP, masuk daftar keputusan user.**

### 3.2 Output analisa = 3 daftar (belum eksekusi)
1. **KANDIDAT KOREKSI** — HPP=0 + ada moving-avg jelas → HPP seharusnya = moving-avg.
2. **SENGAJA (skip)** — base/dummy model, dikonfirmasi akuntansi.
3. **BUTUH KEPUTUSAN USER** — ambigu.

### 3.3 Bentuk koreksi (nanti, setelah approval) — **perbaiki sumber**
- Isi `tsales2.HPP` baris kandidat = moving-avg cost yang benar → **jalankan closing/refresh resmi** → COGS terbukukan (GL Dr HPP / Cr persediaan) → GL persediaan = stok.
- **A vs B:** **A = re-refresh dari transaksi sumber** (disarankan; setelah HPP sumber benar) — bukan **B (jurnal koreksi manual)**. Tidak ada balancing.
- **Dampak akuntansi nyata:** COGS understated selama ini → koreksi **menaikkan HPP, menurunkan laba** periode terkait → **WAJIB sign-off manajemen/akuntansi** (bukan sekadar teknis).

---

## 4. RUNBOOK KOREKSI PRODUKSI (rancangan; eksekusi menunggu approval)

| Step | Aksi | Kontrol |
|---|---|---|
| **0** | **Backup DB penuh** + snapshot `tsales2` (baris kandidat) | uji **COPY-DB** dulu |
| **1** | **Generate daftar kandidat** (read-only): jual HPP=0 dengan moving-avg>0, per item/voucher/tanggal/nilai-seharusnya | 3 daftar (§3.2) |
| **2** | **Approval user/akuntansi** per daftar (klasifikasi bug/sengaja/ambigu) + sign-off dampak L/R | tertulis |
| **3** | **Eksekusi koreksi sumber**: isi `tsales2.HPP` baris disetujui = moving-avg (bukan jurnal) | hanya baris approved |
| **4** | **Refresh stok RESMI** (closing/refresh normal) — recompute COGS & moving-avg | tidak sentuh opening 2026 |
| **5** | **Validasi:** GL movement = stock movement per akun; sinv=GL; **WIP 102-020 tetap**; **HPP-WIP tetap**; **idempotency** (re-refresh 2× identik) | semua ✓ baru finalisasi |

---

## 5. GUARD PERMANEN (validasi closing — desain)

Pasang di proses closing/refresh, **FAIL/peringatkan** jika:
1. **Jual HPP=0 pada item ber-moving-avg>0** (COGS understated) → tandai voucher.
2. **GL movement ≠ Stock movement** per akun persediaan (toleransi > Rp1) → closing gagal.
3. **BTB (‘02’) tanpa `STOK_ID`** (produk kosong di kolom yang dipakai engine) → tolak posting.
4. **Transaksi valas**: pastikan `NETTO×KURS` (IDR) konsisten GL↔stok.
5. **Qty stok berubah tanpa transaksi sumber** (STOK_ID) → tandai.

> Guard #1 & #2 adalah yang menangkap root cause sebenarnya (HPP=0). #3–#5 pelengkap kebersihan data.

---

## 6. YANG BELUM DIPUTUSKAN (butuh input, sebelum koreksi)
- **Klasifikasi HPP=0**: mana yang bug (BF box, unit dibeli-dijual) vs sengaja (model dasar `TYU-001`?). → butuh konfirmasi akuntansi.
- **Sumber moving-avg yang benar** untuk baris kandidat (tanggal & metode).
- **Sign-off dampak Laba-Rugi** (COGS naik).

**Aturan dijaga:** tidak ada jurnal penyesuaian, tidak ada transaksi fiktif, tidak ada angka balancing, tidak menyentuh opening recovery / Desember 2025 / WIP. Semua koreksi kembali ke **sumber transaksi (`tsales2.HPP`)** lalu **re-refresh**. **DESIGN ONLY — belum ada SQL UPDATE.**
