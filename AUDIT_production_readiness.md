# AUDIT PRODUCTION-READINESS — Recovery Mekanisme A (Koreksi Snapshot Opening)

Audit teknis terakhir. Setiap klaim disertai **bukti** (static code + hasil query di LOCAL DESKTOP-P04P4QG). Skema hardcode tahun dihapus (parameterized). Semua uji dijalankan atas file `.sql` **yang sebenarnya** (bukan re-implementasi).

---

## 1. Ringkasan verdict

| # | Persyaratan Pak Wira | Verdict | Bukti |
|---|---|---|---|
| 1 | Tidak ada UPDATE selain sinv opening target | **LULUS** | Static §3 (2 UPDATE: 1 scratch `_engine_dec`, 1 `sinv` WHERE periode=target) |
| 2 | Tidak ada INSERT (ke tabel bisnis) | **LULUS** | Static §3 (INSERT hanya ke scratch `_guard`/`_engine_dec`) |
| 3 | Tidak ada DELETE | **LULUS** | Static §3 (grep DELETE = kosong) |
| 4 | Tidak ada perubahan transaksi | **LULUS** | Static (no write tstok/tsales) + guard `move_tx` Δ0, `hppwip` Δ0 |
| 5 | Tidak ada perubahan GL | **LULUS** | Static (no write gl_journal/gl_balance) + guard `gl_prior` Δ0, `wip020` Δ0 |
| 6 | Tidak ada perubahan WIP | **LULUS** | guard `wip020` (GL 102-020) Δ0 + `hppwip` Δ0 |
| 7 | Tidak ada perubahan HPP | **LULUS** | SET clause tak memuat hpp_avg (static) + scope `row_HPP_AVG_berubah=0` (evidence) |
| + | UPDATE hanya sentuh periode target | **LULUS** | Scope A: tepat 1 periode berubah = target; per-periode 166 lain Δ0 |
| + | Trigger cascade | **LULUS** | Katalog: 0 trigger pada sinv/gl/tstok/tsales (hanya 3 trigger ml_* MobiLink) |
| + | Idempotent | **LULUS** | RUN#1=RUN#2 Δ0 |
| + | Parameterized (nol hardcode tahun) | **LULUS** | 1 anchor `target_opening_period`; sisanya derived (§2) |

**Status: PRODUCTION-READY** dengan 3 catatan terdokumentasi (§6) yang sudah divalidasi & ada guard-nya.

---

## 2. Parameterisasi (hilangkan hardcode 2026/2025)

Satu-satunya nilai yang di-set manual = **`target_opening_period`** (anchor, awal-bulan opening). Sisanya diderivasi:

| Variabel | Derivasi | Contoh (anchor=2026-01-01) |
|---|---|---|
| `closing_from` | `dateadd(month,-1,target)` | 2025-12-01 |
| `closing_to` | `dateadd(day,-1,target)` | 2025-12-31 |
| `prior_snapshot` | `= closing_from` (snapshot beku, READ-ONLY) | 2025-12-01 |
| `move_from` | `= target` | 2026-01-01 |
| `move_to` | `dateadd(day,-1,dateadd(month,1,target))` | 2026-01-31 |

- Engine SQL (dw_refresh_stok) juga terparameterisasi: `:arg_tgl`/`:arg_tgl2` → `(closing_from)`/`(closing_to)`. Verifikasi: `grep 202[0-9]` di recovery hanya menemukan **1 baris** (baris SET anchor).
- Bug ditemukan & diperbaiki saat audit: substitusi bareword menghasilkan `ANDclosing_to` (tanpa spasi) → INSERT engine gagal. Diperbaiki jadi `(closing_to)` berkurung. **Tanpa audit ini, engine tak terisi dan preview memakai data stale.**

---

## 3. Audit statik — SETIAP operasi tulis (grep `recovery_mekA_opening.sql`)

**UPDATE (2 saja):**
```
275: UPDATE _engine_dec SET nilai=...        <- tabel SCRATCH (kalkulasi), bukan bisnis
296: UPDATE sinv SET qty=e.akhir, nilai=e.nilai FROM _engine_dec e
       WHERE sinv.stok_id=e.stok_id AND sinv.periode=target_opening_period   <- SATU-SATUNYA tulis bisnis
```
- Kolom yang di-SET pada sinv: **qty, nilai** saja. **hpp_avg / site_id / periode / stok_id TIDAK di-set.**
- Scope WHERE: `periode=target_opening_period` (+ join stok). Tak mungkin menyentuh periode lain.

**INSERT (semua ke SCRATCH):** `_guard` (baris 41–45), `_engine_dec` (baris 51). **Nol** INSERT ke sinv/gl_journal/gl_balance/tstok*/tsales*.

**SELECT … INTO (semua SCRATCH/backup):** `_mekA_bak`, `_sinv_target_before`, `_sinv_ck_before`, `_guard`. (Baca dari tabel bisnis, tulis ke scratch.)

**DELETE:** grep `delete` = **kosong**. Tak ada penghapusan.

**DROP/CREATE TABLE:** hanya tabel scratch (`_mekA_bak`, `_sinv_target_before`, `_sinv_ck_before`, `_guard`, `_engine_dec`).

**Tabel bisnis yang DIBACA (read-only):** sinv, gl_journal, gl_balance, tstok1/2, tsales1/2, im_produk, im_product_group.
**Tabel bisnis yang DITULIS:** `sinv` — oleh **1** statement (baris 296), scope periode=target, kolom qty/nilai.

**Trigger (katalog SYS.SYSTRIGGERS):** total 3 trigger di DB, semua di tabel sistem MobiLink (`ml_connection_script`, `ml_script`, `ml_table_script`). **0 trigger pada sinv/gl_journal/tstok/tsales** → UPDATE sinv **tidak** memicu penulisan turunan ke GL/transaksi.

---

## 4. Bukti scope — UPDATE hanya menyentuh sinv[target] (per stok_id, site, periode)

Skenario uji: restore opening ke **phantom** (Σ36,94 M) → jalankan paket → ukur.

**A. Per-periode (166 periode sinv, checksum sebelum vs sesudah) — hanya periode berubah:**
```
periode      n_before  n_after  d_nilai              status
2026-01-01   6462      6462     -11,127,017,636.40   TARGET (boleh berubah)
```
→ **Tepat 1 baris.** 165 periode lain: Δ0 (ringkas: `periode_berubah_diluar_target = 0`, `selisih_jumlah_periode = 0`).

**C. Row-level periode target (per stok_id & site):**
```
row_berubah=547   row_tidak_berubah=5915   total=6462   row_HPP_AVG_berubah=0
```
→ 547 baris berubah (qty/nilai), 5915 tetap; **hpp_avg berubah pada 0 baris**.

**D. INSERT/DELETE di target:** `n_after=6462, n_before=6462, selisih=0` → tak ada baris ditambah/dihapus.

**E. Detail granular:** 547 baris (stok_id, site_id, qty/nilai/hpp before→after) — pada setiap baris `hpp_before = hpp_after`.
(dari 547: 42 material >Rp1 = phantom; ~505 sisanya sub-rupiah, lihat §6.)

---

## 5. Validasi independen 4-arah: engine · GL · sinv · laporan-mutasi

Per akun persediaan 102-xxx (setelah koreksi):

| akun | engine | GL | sinv | lap_mutasi | d(sinv−engine) | d(lap−sinv) | d(engine−GL) |
|---|--:|--:|--:|--:|--:|--:|--:|
| 102-001 | 12.999.133.239 | 12.999.133.240 | 12.999.133.239 | 12.999.133.239 | 0 | 0 | −0,34 |
| 102-006 | 1.877.122.941 | 1.877.122.940 | = | = | 0 | 0 | 0,60 |
| 102-101 | 7.067.735.174 | 7.067.735.169 | = | = | 0 | 0 | 5,19 |
| 102-110 | 3.070.685.529 | 3.070.685.470 | = | = | 0 | 0 | 58,14 |
| 102-102 | 163.879.013 | 163.878.784 | = | = | 0 | 0 | 228,43 |
| **102-201** | 96.827.614 | **120.790.252** | 96.827.614 | 96.827.614 | 0 | 0 | **−23.962.638** |

- **engine = sinv = laporan-mutasi PERSIS** (d=0) di semua akun — 3 sumber konvergen (engine dari transaksi+sinv prior; sinv snapshot; lap_mutasi = AWAL yang ditampilkan report dw_stok_gl_mutasi).
- **engine ≈ GL** ≤ Rp228 (residu shortcut; NVO recompute → ≤Rp1), **kecuali 102-201** (§6).
- Drill per stok_id 102-001: **0 baris** selisih > Rp1.
- Laporan mutasi **prior (Des)** AWAL = Σ sinv[prior] = **30.102.238.671,63 = baseline, Δ0** → laporan Desember byte-stabil.

---

## 6. Catatan terdokumentasi (bukan blocker; ada guard)

1. **~505 baris sub-rupiah** (bagian dari 547): UPDATE menulis `nilai=round(qty×hpp_avg)`, sehingga item non-phantom bergeser Rp0,01–beberapa rupiah (normalisasi pembulatan). **hpp_avg tetap.** Di produksi, recompute Feb/Mar via NVO menghitung nilai presisi. Per-akun tetap = GL ≤ Rp228 (shortcut) / ≤ Rp1 (NVO).
2. **`engine_not_in_sinv` = 68 baris**: engine punya stok yang tak ada barisnya di sinv[target], **nilai = Rp0**. UPDATE tak meng-INSERT baris baru; **aman hanya karena nilainya 0**. Guard di `validation_guard2025.sql` §C menegaskan `nilai_HARUS_0` — bila suatu saat ≠0, validasi akan menandainya (jangan finalisasi). `sinv_not_in_engine = 0` (tiap sinv[target] tercakup).
3. **102-201 (MT) gap −23,96 jt**: di sini `sinv = engine`, **GL yang lebih tinggi** → isu **saldo-awal GL MT terpisah**, bukan phantom sinv. Mekanisme A **sengaja tidak menyentuhnya**; tangani terpisah di sisi GL.

---

## 7. Berkas paket (produksi)
- `recovery_mekA_opening.sql` — parameterized; backup + before-image + guard + engine + preview + coverage + **1 UPDATE sinv**.
- `evidence_scope_proof.sql` — bukti scope (A per-periode, C row-level per stok/site, D insert/delete, E detail).
- `validation_guard2025.sql` — guard prior-year Δ0 + opening=GL + coverage + idempotency checksum.
- `evidence_4way_recon.sql` — rekonsiliasi engine/GL/sinv/laporan-mutasi.
- `RUNBOOK_recovery_mekanismeA.md` — prosedur L1–L6 (COPY-DB dulu; recompute Feb/Mar via NVO).
- `AUDIT_production_readiness.md` — dokumen ini.

**Kesimpulan: paket LULUS audit dan PRODUCTION-READY** (uji di COPY-DB dulu; agent write-blocked ke prod — Pak Wira eksekusi).
