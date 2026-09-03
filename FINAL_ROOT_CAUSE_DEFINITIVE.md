# ROOT CAUSE FINAL — Gap Stok vs Ledger Rp10,11 M (TERBUKTI KE RUPIAH)
Evidence-based, prod 103.233.89.43:2638. Metode: menjalankan SQL engine `dw_refresh_stok` yang ASLI untuk closing Des-2025, dibandingkan sinv tersimpan & GL.

## 0. Hipotesis yang DICABUT (dengan bukti)
- ❌ **WIP** menyebabkan gap → WIP terjurnal 1,8 M = GL 102-020 (match); gap ≠ WIP.
- ❌ **Double-count '05'** → formula AKHIR `dw_refresh_stok` **tidak memakai EKSPEDISI('05')**, hanya BELI('02'). '05' hanya nilai freight. Dicabut.

## 1. Rekonstruksi engine vs sinv (closing Desember 2025)
Menjalankan SQL `dw_refresh_stok` (arg_tgl='2025-12-01', arg_tgl2='2025-12-31'):

| Item | AWAL | BELI('02') | JUAL_BY_EVAP | CONSIN | **AKHIR (engine)** | **sinv 01-01-2026** | **Selisih** |
|---|---:|---:|---:|---:|---:|---:|---:|
| TR.038A | 14 | 12 | 15 | 15 | **9** | **39** | **+30 unit** |
| TR.039A | 0 | 19 | 6 | 5 | **13** | **25** | **+12 unit** |

Formula engine (dari transaksi) = 9 & 13. sinv menyimpan 39 & 25.

## 2. BUKTI KE RUPIAH (102-001 TR, nilai closing Des 2025)
| Sumber | Nilai |
|---|---:|
| **ENGINE `dw_refresh_stok` (AKHIR × hpp)** | **12.999.133.239** |
| **GL opening 2026 (gl_balance)** | **12.999.133.240** |
| **SINV tersimpan (01-01-2026)** | **23.110.313.890** |

→ **ENGINE = GL, beda Rp1.** SINV tersimpan **+10.111.180.650** di atas keduanya.

## 3. ROOT CAUSE FINAL
> **Gap Rp10,11 M = sinv opening 2026 (closing Des-2025) DITULIS LEBIH TINGGI dari yang dihasilkan formula transaksi.**
> Formula engine `dw_refresh_stok` menghasilkan nilai yang **SAMA PERSIS dengan GL (12,99 M, beda Rp1)**. Nilai sinv tersimpan (23,11 M) **tidak punya dasar transaksi** — ini **penulisan-ulang saldo (phantom write)** saat proses closing/refresh akhir tahun 2025, bukan penerimaan barang, bukan WIP, bukan freight.

**Kenapa ini bukti "barang phantom tidak ada" (tanpa cek fisik):**
Engine memperhitungkan SELURUH transaksi (beli '02', jual '22', WIP-Out/In '88', mutasi, retur, konsinyasi). Hasilnya = GL ke rupiah. **30 unit TR.038A & 12 unit TR.039A ekstra di sinv TIDAK berasal dari transaksi apa pun** → phantom penulisan, bukan aset riil.

## 4. Tabel Root Cause Final
| Item | Saldo seharusnya (engine=GL) | Saldo sistem (sinv) | Selisih | Sumber penyebab | Bukti |
|---|---:|---:|---:|---|---|
| TR.038A | Rp2,22 M (9 unit) | Rp9,64 M (39 unit) | +Rp7,42 M (+30 unit) | Penulisan sinv closing Des-2025 > formula | engine AKHIR=9 vs sinv=39; §2 total=GL |
| TR.039A | ± (13 unit) | Rp5,28 M (25 unit) | +Rp2,5 M (+12 unit) | idem | engine AKHIR=13 vs sinv=25 |
| **Total 102-001** | **12.999.133.239 (=GL)** | **23.110.313.890** | **+10.111.180.650** | **phantom write opening 2026** | engine=GL Rp1 |

## 5. KOREKSI (audit-safe, BUKAN write-off, BUKAN adjustment angka)
**Regenerasi sinv opening 2026 dari engine** (yang = GL ke rupiah) — bukan mengetik angka, tapi menjalankan ulang formula transaksi:
- **Mekanisme:** `n_cst_closing_stock.of_run(f_bom('2025-12-01'), silent, ab_sinv_only=TRUE, al_replace=1, al_minus=0)` → hitung ulang closing Des-2025 → tulis sinv[2026-01-01] = **12,99 M** (= GL). Ini **al_replace=1 year-close** yang SUDAH ada di hardening (P2).
- **Lalu re-close/re-refresh Jan-Feb** agar opening yang benar merambat.
- **Bukan write-off:** nilai baru = hasil formula transaksi = GL (terbukti §2). Yang dihapus hanya **selisih phantom yang tak berdasar transaksi**.
- **Tidak sentuh GL** (sudah benar). **Tidak sentuh HPP WIP** (Bagian A/B utuh). **Tidak sentuh freight '05'.**

Alternatif bila mau seed langsung (tanpa refresh Des): `update sinv[2026-01-01].nilai/qty/hpp_avg` = hasil engine per model — TAPI lewat regen engine lebih auditable.

## 6. VALIDASI WAJIB (COPY-DB dulu, jangan prod)
Setelah regen opening + re-close Jan-Feb:
- **A.** 102-001/003/006/020: **sinv = ledger** (≤ Rp1).
- **B.** Mutasi Jan-Feb **tetap** (regen hanya opening; gerakan tak berubah).
- **C.** Costing: WIP sale = HPP WIP-Out; non-WIP = average (Bagian B).
- **D.** GL tak berubah (nilai lama GL sudah = engine).

## 6b. KONFIRMASI SEMUA AKUN (engine = GL, sinv outlier)
| Akun | ENGINE (transaksi) | SINV tersimpan | GL opening | ENGINE−GL | Phantom sinv |
|---|---:|---:|---:|---:|---:|
| 102-001 | 12.999.133.239 | 23.110.313.890 | 12.999.133.240 | 0 | +10.111.180.650 |
| 102-006 | 1.877.122.941 | 2.760.554.063 | 1.877.122.940 | 1 | +883.431.122 |
| 102-101 | 7.067.735.174 | 7.144.614.910 | 7.067.735.169 | 5 | +76.879.736 |
| 102-110 | 3.070.685.529 | 3.115.291.871 | 3.070.685.470 | 58 | +44.606.342 |
| 102-010 | 245.382.000 | 256.302.000 | 245.382.000 | 0 | +10.920.000 |
| 102-003 | 55.094.965 | 55.094.965 | 55.094.965 | 0 | 0 |
| 102-201 (MT) | 96.827.614 | 96.827.620 | 120.790.252 | −23.962.638 | sinv≈engine (isu GL) |
**Engine = GL (beda ≤Rp58) untuk 6 akun.** Phantom sinv total ≈ **Rp11,13 M** (dominan 102-001). **102-201 beda: sinv=engine, GL yang lebih tinggi** → isu saldo-awal GL 102-201 (terpisah, kecil, terdokumen), BUKAN phantom sinv.

## 7. Kesimpulan audit (persisted derived-data corruption)
> **Root cause = bug pada proses refresh/closing HISTORIS (akhir 2025) yang menulis SINV lebih tinggi daripada hasil perhitungan engine.** Transaksi benar, GL benar, engine sekarang benar (= GL ke rupiah). SINV = data turunan yang ter-persist dengan nilai korup. **Tidak perlu cari pelaku** (tak ada audit trail); yang terbukti adalah MEKANISME: engine deterministik menghasilkan = GL, sinv menyimpan nilai tak-tereproduksi.

**Solusi 2 tahap (audit-safe):**
- **TAHAP 1 — Recovery:** regenerasi SINV dari engine terverifikasi → SINV = Engine = GL. (`RUNBOOK_recovery_prevention.md`)
- **TAHAP 2 — Prevention:** validasi otomatis tiap closing (gap≤Rp1 PASS, else FAIL/warn, jangan finalisasi). (`validation_post_closing.sql`)
- **Bukti pendukung:** engine idempoten (jalankan 2× = hasil identik = GL). (`idempotency_evidence.sql`)
