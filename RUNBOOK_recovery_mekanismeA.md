# RUNBOOK — Recovery Mekanisme A (Koreksi Opening 2026, Desember 2025 FROZEN)

**Tujuan:** memperbaiki **data turunan** `sinv[2026-01-01]` (opening 2026) yang korup (23,11 M) menjadi nilai benar = engine = GL (12,99 M), **tanpa** menyentuh Desember 2025 dan **tanpa** membuat transaksi/mutasi/jurnal koreksi.

**Prinsip (dikunci Pak Wira):**
- Saldo akhir / closing / neraca / laporan **2025 = hasil audit → TIDAK BOLEH berubah**.
- Recovery = perbaikan **data turunan (snapshot)**, **BUKAN** menambah transaksi. Tidak ada baris "Koreksi Saldo Awal" di mutasi.
- Yang berubah HANYA **Saldo Awal 2026** (dan turunannya: sinv Feb/Mar). Mutasi Januari **identik**.

---

## 0. Kenapa ini aman untuk Desember 2025 (bukti teknis dari source)

| Fakta | Sumber | Konsekuensi |
|---|---|---|
| Laporan Mutasi Stok **Des-2025** hitung AKHIR **dari transaksi** (`AKHIR FROM IM_PRODUK`), baca sinv hanya sbg AWAL `sinv[2025-12-01]` | `dw_stok_gl_mutasi` | Ubah `sinv[2026-01-01]` **tak mengubah** laporan Des-2025 |
| Neraca 2025 = **GL** (`gl_balance`/`gl_journal`) | — | Recovery tak sentuh GL → neraca 2025 identik |
| Rebuild `sinv[Jan]` (peralihan tahun) **hanya fire saat closing Desember** (`if string(ldt_next,'mm')='01'`, `al_replace=1`) | `n_cst_closing_stock.sru` baris 136 & 191 | Recompute **Jan/Feb** → `ldt_next`=Feb/Mar → **tak menyentuh** `sinv[2026-01-01]` |
| Sinkron SINV memakai `of_run(...,ab_sinv_only=TRUE,...)` | `w_refresh_journal.srw` baris 2613 | Recompute sinv **tanpa** menyentuh GL/HPP |
| `sinv[2026-01-01]` = SATU baris, single site (101), `(periode,stok_id)` unik | verifikasi DB | UPDATE join `stok_id+periode` aman, tak ambigu |

**Sifat recovery:** UPDATE snapshot `sinv[2026-01-01]` saja. **Nol** `tstok/tsales/gl_journal` dibuat. Desember 2025 byte-frozen.

---

## 1. Prasyarat & keamanan

1. **UJI DI COPY-DB DULU.** Sebelum eksekusi verifikasi: `select property('MachineName')` = mesin test, **bukan** prod (103.233.89.43).
2. **Backup penuh DB** (file `.db`/`.log`) sebelum mulai.
3. **Aplikasi VSP ditutup** semua user saat langkah SQL & recompute (hindari lock & retrieve saldo lama).
4. Tools dbisql / dbeng9 (ASA9). Login `dba`.

---

## 2. Langkah eksekusi (urut)

### L1 — Backup snapshot + baseline guard-2025
Jalankan `recovery_mekA_opening.sql` **STEP 1 & STEP 2** di dbisql.
- Membuat `_mekA_bak` (backup sinv 2026) & `_guard2025` (checksum baseline Des-2025).
- Materialisasi `_engine_dec` = hasil engine closing Des-2025 (READ-ONLY; **tidak menulis** ke 2025).

### L2 — Preview & setujui
Jalankan **STEP 3**. Baca daftar item terdampak (opening lama vs engine, kolom `phantom`).
- **Verifikasi:** total phantom ≈ selisih 102-001 (± 10,11 M) dst. Bila janggal → STOP, jangan lanjut.

### L3 — Koreksi opening (UPDATE snapshot; NOL transaksi)
Jalankan **STEP 4**: `UPDATE sinv[2026-01-01] = engine`. `COMMIT`.
- Hanya mengubah qty/nilai `sinv[2026-01-01]`. Tidak ada transaksi/jurnal.

### L4 — Recompute Feb/Mar (presisi, via NVO, tanpa sentuh GL)
Recompute `sinv[2026-02-01]` & `sinv[2026-03-01]` dari opening baru + transaksi asli, dengan HPP presisi.

**Cara (pakai aplikasi, tanpa kode baru):** jalankan **Refresh bulanan normal untuk Januari, lalu Februari** (proses yang Bapak jalankan rutin).
- Internal memanggil `of_run(f_bom(bln), false, true, 0, 1, ...)` → **sinv-only, presisi HPP, tanpa timpa GL** (baris 2613).
- Karena Jan/Feb **bukan** peralihan tahun (`ldt_next` mm=02/03), **`sinv[2026-01-01]` TIDAK di-rebuild** → opening hasil koreksi L3 tetap.
- GL Jan/Feb 2026 di-refresh idempoten (delete+insert dari transaksi asli) — **bukan** transaksi baru, **tidak** menyentuh 2025.

> Catatan: `of_run` dengan `ab_sinv_only=TRUE` menghitung ulang moving-average presisi → **menghilangkan residu ~Rp32,5 jt** yang muncul bila memakai jalan pintas `qty × hpp_avg`.

### L5 — Validasi & bukti (WAJIB semua lolos)
Jalankan (satu sesi, setelah STEP 4): `evidence_scope_proof.sql`, `validation_guard2025.sql`, `evidence_4way_recon.sql`.
- **Scope** (`evidence_scope_proof.sql`) — hanya periode target berubah (1 baris); `periode_berubah_diluar_target=0`; `row_HPP_AVG_berubah=0`; insert/delete `selisih=0`.
- **A. Guard** (`validation_guard2025.sql`) — 6 metrik (`prior_open_qty/nil`, `gl_prior`, `move_tx`, `wip020`, `hppwip`) **delta HARUS 0** → prior-year frozen, WIP/HPP tetap.
- **B. Opening = GL** — `sinv[target]` vs `gl_balance[target]` per akun 102-xxx, **gap ≤ Rp1** (via NVO; shortcut SQL ≤ ratusan rupiah). **Kecuali `102-201` (MT)**: gap ~ −23,96 jt = isu **saldo-awal GL MT terpisah** (sinv=engine, GL lebih tinggi) → **bukan** phantom sinv, tidak disentuh; tangani terpisah di sisi GL.
- **C. Coverage** — `sinv_not_in_engine=0`, `engine_not_in_sinv` nilai=0 (bila ≠0 → JANGAN finalisasi).
- **4-arah** (`evidence_4way_recon.sql`) — engine=sinv=lap_mutasi (d=0); engine≈GL ≤Rp1 kecuali 102-201.
- **C. Closing Feb/Mar = GL** — bandingkan **w_rpt_stok_glmutasi vs w_rpt_ledger** Jan & Feb 2026 → harus sama.

### L6 — Idempotency
Ulangi L3+L4 sekali lagi → checksum sinv 2026 (query D) **identik** (delta 0). Deterministik → aman jadi SOP.

---

## 3. Prevention (pasang setelah recovery)
Tiap closing bulanan, validasi otomatis: **engine closing = sinv = GL** per akun persediaan; **selisih > Rp1 → FAIL** (blok/peringatkan). Mencegah opening korup terulang.
> Catatan akar: phantom opening 23,11 M kemungkinan warisan close Des-2025 lama (sebelum fix engine). Prevention ini menangkap bila terjadi lagi.

## 4. Rollback
```sql
UPDATE sinv SET qty=b.qty, nilai=b.nilai, hpp_avg=b.hpp_avg FROM _mekA_bak b
  WHERE sinv.stok_id=b.stok_id AND sinv.periode=b.periode AND sinv.site_id=b.site_id;
COMMIT;
```
(mengembalikan sinv 2026 Jan/Feb/Mar ke kondisi sebelum recovery.)

---

## 5. Bukti uji LOCAL paket-produksi end-to-end (sudah lolos — DESKTOP-P04P4QG, 2026-08-01)
Skenario: restore opening ke kondisi **phantom** (36,94 M semua akun) → jalankan `recovery_mekA_opening.sql` → `validation_guard2025.sql`.

| Validasi | Hasil |
|---|---|
| STEP3 PREVIEW deteksi phantom | **42 item, total Rp11.127.017.636** terdeteksi otomatis |
| Guard-2025: dec_open_qty/nil, gl_2025, jan_tx, wip020, hppwip | **delta 0 semua** (Des-2025 frozen, WIP/HPP tetap) |
| Opening 2026 **102-001 (TR)** | 23.110.313.890 → **12.999.133.239** = GL 12.999.133.240, **gap −Rp0,34** |
| Opening 2026 akun 102 lain | gap ≤ **Rp228** (102-102 = isu qty TL2030504; sisanya < Rp60, residu shortcut) |
| Opening 2026 **102-201 (MT)** | gap −23,96 jt = **isu GL saldo-awal MT terpisah** (bukan phantom; tak disentuh) |
| Idempotency (re-run) | checksum sinv identik (delta 0) |

Mekanisme A terbukti end-to-end: **preview mendeteksi phantom → koreksi snapshot → guard-2025 delta 0 → opening = GL sampai rupiah**, murni perbaikan data turunan, Desember 2025 utuh, WIP/costing tetap. Residu ≤ ratusan rupiah dari shortcut `qty×hpp_avg` → hilang setelah recompute NVO (L4).

---

## Berkas paket
- `recovery_mekA_opening.sql` — **parameterized** (anchor `target_opening_period`, nol hardcode tahun); backup + before-image + guard baseline + materialisasi engine + preview + coverage + **1 UPDATE sinv**.
- `evidence_scope_proof.sql` — bukti scope: hanya periode target berubah (per-periode), row-level per stok_id/site, no insert/delete, hpp_avg tetap.
- `validation_guard2025.sql` — guard prior-year Δ0 + opening=GL + coverage + idempotency checksum.
- `evidence_4way_recon.sql` — rekonsiliasi independen engine · GL · sinv · laporan-mutasi.
- `AUDIT_production_readiness.md` — audit statik operasi-tulis + trigger + verdict per persyaratan.
- `RUNBOOK_recovery_mekanismeA.md` — dokumen ini.

## Parameterisasi
Ubah **hanya** baris `SET target_opening_period='YYYY-MM-01'` di tiap script (samakan). `closing_from/closing_to/prior_snapshot/move_from/move_to` diderivasi otomatis. Jalankan keempat `.sql` dalam **satu sesi dbisql** (variabel dibagi antar-script).
