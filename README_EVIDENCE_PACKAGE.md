# Production Readiness Evidence Package — Patch HPP EVAP Moving-Average Fallback

**Tujuan:** membuktikan secara OBJEKTIF (bukan asumsi) bahwa koreksi COGS ~Rp394 jt ini
(1) benar secara costing, (2) tidak menimbulkan regresi, (3) tidak mengubah transaksi normal,
(4) dapat dipertanggungjawabkan saat closing.

Semua file ASA9/SQL Anywhere 9, dijalankan di **DB COPY** via dbisql 32-bit. Sudah divalidasi
syntax-nya jalan di engine prod (read-only).

---

## Isi paket
| File | Fungsi |
|---|---|
| `EVIDENCE_1_baseline_snapshot.sql` | Snapshot _pre_* + `_cfg` (periode) + `_evap_stok` + timestamp |
| `EVIDENCE_2_hpp_comparison.sql` | Kategori perubahan HPP: SAFE_CHANGE vs REGRESSION (target 0) |
| `EVIDENCE_3_cogs_recon.sql` | Δ jurnal COGS (modul HP) vs Σ(qty×Δhpp); selisih ≤ pembulatan |
| `EVIDENCE_4_inventory_titipan_recon.sql` | Phantom saldo akhir EVAP (=0) + Titipan 102-020 pre/post |
| `run_evap_patch_validation.sql` | **MASTER GATE**: Gate1–6 + hardening → laporan + keputusan GO/NO-GO |

---

## Urutan eksekusi (WAJIB) — protokol baseline bersih
1. **Copy** DB prod → DB_TEST (`dbunload -an` / salin file + `dblog`).
2. Pastikan DB_TEST memakai **KODE PRE-PATCH** (revert 2088 & f_insert_cons_in), **refresh+close Juni & Juli** → ini baseline.
3. Jalankan **EVIDENCE_1** → snapshot `_pre_*`.
4. **Terapkan patch** (2088 fallback di kedua window + f_insert_cons_in) → **Full Build 0 error**.
   Konfirmasi: `INSERT INTO _gate_manual VALUES('Gate1 SQL Compile','PASS'); COMMIT;`
5. **Refresh+close Juni & Juli #1** → jalankan blok `SNAPSHOT-POST1` (di header master) → `_post1_tsales2_hpp`.
6. **Refresh+close Juni & Juli #2** (uji idempotent).
7. Jalankan **EVIDENCE_2/3/4** (detail) lalu **run_evap_patch_validation.sql** (gate + keputusan).

> Kunci: baseline HARUS di-refresh dgn kode LAMA. Karena moving-average deterministik,
> satu-satunya baris yang berubah pre→post adalah baris fix (mv=0 ∧ EVAP ∧ ada consout).
> Kalau ada baris lain berubah → itu REGRESSION (Gate 2 menangkapnya).

---

## Gate & ambang
| Gate | Lulus bila | Sumber |
|---|---|---|
| 1 SQL Compile | Full Build 0 error (manual → `_gate_manual`) | eksternal PB |
| 2 HPP Regression | `regression rows = 0` | EVIDENCE_2 |
| 3 COGS Reconcile | tiap bulan `|Δgl_HP − Σqty×Δhpp| ≤ 5` | EVIDENCE_3 |
| 4 Inventory Clean | phantom EVAP (qty=0 & nilai<>0) `= 0` | EVIDENCE_4A |
| 5 Titipan Release | `|turun_titipan − koreksi_COGS| ≤ 5` | EVIDENCE_4B |
| 6 Refresh Idempotent | hpp refresh#1 = refresh#2 (0 beda) | `_post1` |
| Harden Dup-Cost | 0 serial dgn >1 HPP consout beda | live |
| Harden Future-Cost | 0 consout-hanya-setelah-jual | live |
| Harden Orphan | (WARN) jual EVAP tanpa consout | live |

**Keputusan otomatis:** FAIL/PENDING = **NO-GO**. Semua PASS & orphan 0 = **READY**.
Orphan>0 = **READY dgn catatan** (triase manual, lihat bawah).

---

## Bukti awal dari PRODUKSI (read-only, sebagai referensi angka)
Dijalankan langsung ke prod (bukan copy) untuk validasi logika & besaran:
- **Harden Dup-Cost = 0** → `MAX(hpp)` deterministik (tiap stok+serial hanya 1 harga consout). AMAN sekarang.
- **Harden Future-Cost = 0** → tak ada fallback memakai cost masa depan. AMAN sekarang.
- **Harden Orphan (tipe22, Jun–Jul) = 29 unit** → jual EVAP hpp=0 **tanpa consout** → fix **tak menolong** → tetap understated. **HARUS di-triase** (sebagian mungkin baris Juli belum-refresh; angka final = hasil Gate di COPY pasca-refresh).
- **COGS = modul `HP`** terkonfirmasi (akun 402-xxx). Recon Gate 3 sah.
- **Dampak COGS** (dari audit): Jan–Mei = 0, Juni = +38,5 jt (1 trx), Juli = +355 jt (4 trx). Total ≈ **Rp394 jt**.

> Catatan penting: `MAX` dan "tanpa batas tanggal" AMAN **karena data saat ini** (dup=0, future=0),
> BUKAN karena dijamin desain. Bila suatu saat ada revaluasi konsinyasi (>1 harga per serial),
> Gate Harden Dup-Cost akan FAIL → hentikan deploy sampai fallback diperketat (ambil consout
> TERAKHIR ≤ tgl jual, bukan MAX).

---

## Untuk Pak Wira — kesimpulan yang dapat dipertanggungjawabkan
1. **Benar secara costing:** unit EVAP konsinyasi yang terjual dinilai pada **cost consout serial-nya**
   (bukan 0). Nilai 0 sebelumnya adalah **salah saji** (COGS understated, laba overstated). Fix mengoreksinya.
2. **Tidak ada regresi transaksi normal:** terbukti **secara struktur** — `isnull(nullif(mv,0),fb)`
   berarti untuk `mv≠0` hasilnya **IDENTIK** dengan rumus lama; hanya baris `mv=0 ∧ EVAP ∧ ada consout`
   yang berubah. Diperkuat: Jan–Mei **0 perubahan**, Juni **regresi 0**. Gate 2 membuktikannya di COPY.
3. **Dapat dipertanggungjawabkan saat closing:** Gate 3 membuktikan kenaikan **jurnal GL 402** persis
   = Σ(qty×Δhpp); Gate 4 membuktikan tak ada phantom persediaan; Gate 5 membuktikan Titipan 102-020
   ter-relieve sebesar itu. Angka konsisten Mutasi = Ledger = Laba Rugi.
4. **Yang MASIH terbuka (jujur):** 29 unit orphan (tanpa consout) tetap 0 — perlu keputusan Pak Wira
   (sumber cost lain / koreksi manual). Fix ini TIDAK menutup itu.

**REKOMENDASI AUDITOR:** jalankan paket ini di COPY. Bila Gate 1–6 PASS & Harden Dup/Future PASS →
**GO** (dgn triase 29 orphan sebagai tindak lanjut terpisah, non-blocking bila immaterial). Bila Gate
2/3 FAIL → **NO-GO**, kembali ke desain.
