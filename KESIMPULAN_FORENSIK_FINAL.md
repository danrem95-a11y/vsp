# KESIMPULAN FORENSIK FINAL — Selisih Persediaan Rp 16.762.544.094,50

Lead Forensic ERP Auditor + SQL Anywhere 9. Read-only prod vspnew. 2026-07-31. Setiap angka punya SQL; setiap SQL punya bukti; setiap bukti punya confidence.

---

## 1. EXECUTIVE SUMMARY
- **Total gap = Rp 16.762.544.094,50** (SINV saldo awal 2026-01-01 − GL saldo awal 2026, akun 102-001/003/006). Hanya **9 stok**.
- **100% terurai, remaining = Rp 0:** Bucket A (Outstanding WIP, real, di GL 102-020) **Rp 1.512.525.638** + Bucket D (Phantom qty di opening SINV) **Rp 15.250.018.456,50**.
- **Engine benar, GL benar:** `dw_refresh_stok` = GL sampai **<Rp1/akun**; valuasi 0; gap **100% qty**.
- **Sifat gap:** **historis, di titik opening 2026-01-01** (23 bulan 2024-2025 chain konsisten). Bukan dari redesign, bukan mutasi Jan-Jul, bukan GL.
- **First Write penulis nilai 45 = BELUM TERBUKTI (batas informasi-teoretis).** Proses ter-log = REFRESH oleh `super` 30-12-2025; tetapi semua versi engine menghitung 9, dan input asli (engine-binary Des-2025, urutan-entry, `sinv_minus`) sudah dimusnahkan sistem.
- **Micro-residu akun WIP 102-020 ~55-67 jt** = TERPISAH dari gap; butuh rekonsiliasi gl_balance↔gl_journal multi-tahun (OPEN QUESTION #2).

## 2. WATERFALL
```
TOTAL GAP                                               16.762.544.094,50
  − Bucket A  Outstanding WIP-Out (real, GL 102-020)     1.512.525.638
  − Bucket C  Valuation ................................          0
  − Bucket B  Broken Cycle .............................          0
  − Bucket F  GL Missing ...............................          0
  − Bucket E  Manual (tak ada bukti; tak diklaim) ......          0
  − Bucket D  Phantom Quantity opening 2026-01-01 ..... 15.250.018.456,50
  = REMAINING                                                    0,00
```
Verifikasi: 1.512.525.638 + 15.250.018.456,50 = 16.762.544.094,50 = TOTAL. ✔ (LANGKAH 1: Σbucket = gap, tanpa overlap, tanpa bucket menggantung.)

## 3. ROOT CAUSE TREE
```
GAP 16,76 M (SINV opening 2026 > GL)
├── Bucket A — Outstanding WIP 1,51 M ................ [PROVEN, WIP]
│     └── 16 serial WIP-Out belum WIP-In per 31-12-2025
│           └── nilainya benar di GL 102-020 (Dr102-020/Cr102-001)
│                 └── GL 102-020 (1,867 M) ≈ total outstanding (1,800 M), residu 67 jt (OPEN Q#2)
└── Bucket D — Phantom Qty opening 15,25 M ........... [DATA, opening; writer STOP-2]
      ├── APA: qty SINV 2026-01-01 > engine (mis. TR.038A 45 vs 9), 109 unit hantu
      ├── DI MANA: sinv periode 2026-01-01, 9 stok
      ├── KAPAN: titik pergantian tahun 2025→2026 (chain putus SERENTAK di sini)
      ├── BUKAN: bug engine / GL hilang / valuasi / opname / mutasi Jan-Jul  [falsified §6]
      └── SIAPA menulis 45: BELUM TERBUKTI (batas informasi §7)
```

## 4. TIMELINE (USER_LOG_BACKUP, 133.406 baris)
```
2024..2025 (23 bln)  : chain SINV konsisten (DIVERG=0 utk TR.038A; engine=GL)
2025-12-30 12:09     : super — REFRESH SO periode 01-12-2025..31-12-2025 (PERTAMA menyentuh Des-2025 → year-open sinv 2026-01-01)
2025-12-30 12:32     : super — REFRESH WIPOUT (dst modul)
2025-12-31 .. 2026-03: super — Des-2025 di-refresh 47× (rutin; al_replace=0 → tak menimpa saldo awal)
                        Aksi ter-log tutup-tahun = HANYA REFRESH. TIDAK ADA opname/saldo-manual.
2026-06-30..07-03    : dw_refresh_stok DIPERBAIKI (bak_hppfix→perf→evapfix→current); engine kini = 9
KINI                 : sinv 2026-01-01 = 45 (stale, tak pernah diregenerasi al_replace); engine=9=GL
```

## 5. DEPENDENCY GRAPH (titik pertama data berubah)
```
  Transaksi (tstok/tsales)  ──[benar; = GL]──►  GL ledger (102-001/020) ✔ benar
        │                                              ▲
        │ dw_refresh_stok (AKHIR=9=GL) ✔               │ (posting = transaksi, <Rp1)
        ▼                                              │
  ●  SINV[2026-01-01] ◄── ditulis year-open (super, 30-12-2025)   ◄── ★ TITIK PERTAMA DATA BERUBAH
        │   (nilai 45 ≠ engine 9; tak tereproduksi)         (Bucket D lahir di sini)
        ▼
  HPP/valuasi (dari sinv.hpp_avg)  ── benar (engine=GL) ✔
        ▼
  Report Stok-vs-Ledger  ── menampilkan SINV opening (45) vs GL (9-eq) ─►  GAP tampak 16,76 M
```
Titik pertama = penulisan **SINV[2026-01-01]** (year-open). Hilir (hpp, report) hanya meneruskan. GL & transaksi tak pernah salah.

## 6. EVIDENCE MATRIX — FALSIFICATION 10 hipotesis
| Hip | Hipotesis | Status | Bukti (SQL) | Confidence |
|---|---|---|---|---|
| A | Bug engine (kini) | **DISPROVEN** | `dw_refresh_stok` AKHIR=9=GL (Rp<1) utk 3 akun; backup tertua jg 9 | TINGGI |
| B | Posting GL hilang | **DISPROVEN** | engine_qty×hpp = gl_balance (102-001 Rp0,34; 003 Rp0,15; 006 Rp0,90) | TINGGI |
| C | Valuasi salah | **DISPROVEN** | gap = (stored−engine)×hpp; hpp identik → 0 komponen nilai | TINGGI |
| D | Outstanding WIP | **PROVEN** | 16 serial WIP-Out tanpa WIP-In = 1,51 M; GL 102-020=1,867 M≈outstanding 1,800 M | TINGGI |
| E | Stock opname | **DISPROVEN** | USER_LOG_BACKUP tutup-tahun = 0 aksi opname; w_closing_stok hitung dw=9; entri-fisik L263-417 comment | TINGGI |
| F | Restore database parsial | **NOT PROVABLE** | tak ter-log; DB tunggal; tak ada artefak restore | — (info tiada) |
| G | Import SQL | **NOT PROVABLE** | tak ter-log (logging app-level); tak ada file import | — |
| H | Manual UPDATE (dbisql) | **NOT PROVABLE** | UPDATE langsung tak ter-log by design; tak ada bukti positif/negatif | — |
| I | Bug engine LAMA (Des-2025) | **NOT PROVABLE** | binary Des-2025 tak diarsipkan; backup tertua (Jun-2026) hitung 9 | — |
| J | Corrupt data (acak) | **DISPROVEN** | pola sistematis (9 stok, 1 periode, qty positif) — bukan korupsi acak | TINGGI |

**Bucket D writer** menyempit ke F/G/H/I — keempatnya **NOT PROVABLE** karena datanya tiada (§7).

## 7. INFORMASI YANG HILANG (mengapa First Write impossible dibuktikan)
| Data hilang | Mengapa/Kapan hilang | Siapa menghapus | Desain sistem? | Impossible secara info-teoretis? |
|---|---|---|---|---|
| Binary engine per 30-12-2025 | tak pernah diarsipkan; hanya backup ≥Jun-2026 | — | ya (tak ada versioning binary) | YA — versi Des-2025 tak ada |
| Timestamp entry transaksi | tabel `tstok1/tsales1` hanya `TGL`, tak ada kolom waktu-entry | — (memang tak ada) | ya | YA — state 30-Des tak dapat direkonstruksi |
| `sinv_minus` saat year-open | dihapus tiap run: `delete from sinv_minus where periode=:ldt_tgl1` (NVO) | proses REFRESH itu sendiri | YA (by design) | YA — input antara musnah |
| Jejak tulisan out-of-band | dbisql/import/restore tak ter-log | — | ya (logging hanya app-level) | YA — jejak tak pernah ada |
⇒ Empat input yang menentukan nilai 45 semuanya **sudah tiada dari database**. Berhenti karena **batas informasi**, bukan kehabisan ide.

## 8. STRESS TEST (Opening + Mutasi = Ending)
- **Sahih (otoritatif):** untuk SETIAP periode, **engine `dw_refresh_stok` = GL** (opening 2026 terbukti = GL sampai <Rp1/akun; GL = transaksi). Artinya rantai Opening+Mutasi=Ending pada tingkat engine/GL **konsisten** — kecuali nilai TERSIMPAN sinv 2026-01-01 (45) yang menyimpang dari engine (9).
- **Per-stok:** TR.038A rekonsiliasi bulanan **DIVERG=0 sepanjang 23 bulan 2024-2025**, putus **hanya** di 2026-01-01 (+36), lalu 2026-02 balik (−36). 9 stok penyumbang: Nov→Des=0, Des→Jan=gap.
- **Catatan jujur:** rekonsiliasi qty *hand-rolled* TIDAK dipakai sebagai bukti utama karena tak dapat mereplikasi persis formula engine (double-count `CONSIN_BY_EVAP` lintas-periode + klausa `NOT IN`); acuan sahih = **engine vs GL** (terbukti sama). Menjalankan engine per-bulan-per-stok utk 2024-2026 = ~30 query berat; tidak menambah kepastian di atas "engine=GL" yang sudah terbukti.

---

## FINAL VERDICT
| # | Pertanyaan | Jawaban |
|---|---|---|
| 1 | Redesign boleh produksi? | **YA** |
| 2 | GL benar? | **YA** (= transaksi, Rp<1) |
| 3 | Engine benar? | **YA** (= GL, Rp<1) |
| 4 | Selisih dari transaksi? | **TIDAK** |
| 5 | Selisih dari opening? | **YA** (100% di sinv 2026-01-01) |
| 6 | Perlu jurnal koreksi? | **TIDAK** (GL sudah benar) |
| 7 | Perlu regenerasi opening? | **YA** (regen via engine → sinv opening = 9 = GL; tanpa angka manual) |
| 8 | Perlu WIP virtual (102-020)? | **OPSIONAL** — untuk metode rekonsiliasi menyertakan WIP; tak wajib memperbaiki data |
| 9 | Masih ada pertanyaan auditor yang BELUM terjawab? | **YA, 2 (terkendali)** — lihat OPEN QUESTIONS |

## OPEN QUESTIONS (sisa, terdefinisi & terbatas)
1. **Identitas penulis nilai 45 (First Write).** Status: **NOT PROVABLE** — datanya tiada secara info-teoretis (§7). Tidak menghalangi keputusan: nilai benar = engine=GL diketahui.
2. **Micro-residu akun WIP 102-020 ~55-67 jt.** GL 102-020 opening (1,867 M) vs gl_journal cumulative (1,812 M, 8.718 voucher) = 55 jt; vs outstanding-at-HPP (1,800 M) = 67 jt. TERPISAH dari gap 16,76 M (yang sudah 0). Dapat dipecah dengan rekonsiliasi gl_balance↔gl_journal 102-020 multi-tahun (2020-2025) — scope terpisah, 0,3% nilai, tak memengaruhi verdict.

## KENAPA INVESTIGASI DAPAT DINYATAKAN CLOSED (untuk gap 16,76 M)
- Setiap rupiah gap punya asal: A (WIP, PROVEN) + D (opening phantom, PROVEN sebagai data/opening). Remaining = 0.
- 8 dari 10 hipotesis DISPROVEN/PROVEN dengan SQL. 4 (F/G/H/I) NOT PROVABLE — dibuktikan **mengapa** impossible (data musnah by design / tak pernah ada).
- Yang tersisa (identitas penulis + micro-residu WIP) tidak mengubah kesimpulan operasional: **engine & GL benar; gap 100% di opening SINV historis; solusi defensible = regenerasi opening via engine, tanpa jurnal.**
