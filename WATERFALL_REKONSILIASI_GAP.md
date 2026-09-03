# WATERFALL REKONSILIASI GAP — Persediaan Reefer (102-001/003/006)

Investigasi read-only prod vspnew. Semua angka teruji SQL. Tanggal 2026-07-31.

## LANGKAH 1 — TOTAL GAP (anchor)
Gap = Σ (SINV saldo awal 2026-01-01) − Σ (GL saldo awal 2026) untuk akun persediaan reefer:
| Akun | SINV (stored) | GL | Gap |
|---|--:|--:|--:|
| 102-001 (TR) | 28.494.246.211,38 | 12.999.133.239,62 | 15.495.112.971,76 |
| 102-003 (NR) | 439.094.965,00 | 55.094.965,15 | 384.000.000,85(≈384.000.000) |
| 102-006 (TB) | 2.760.554.063,29 | 1.877.122.940,10 | 883.431.123,19 |
| **TOTAL** | **31.693.895.239** | **14.931.351.145** | **16.762.544.094,50** |

**Angka yang harus dihabiskan = Rp 16.762.544.094,50.** Hanya **9 stok** menyumbang (dari 382 stok reefer).

## Fakta pengunci (dipakai di seluruh waterfall)
1. **engine = GL, sampai rupiah** (ketiga akun): engine_qty × hpp = GL (selisih < Rp 1/akun). Bukti: `(sinv 2025-12-01 + net Des) × hpp = GL`.
2. **Valuasi = 0**: karena #1 memakai hpp yang sama menghasilkan GL persis → gap **100% QTY**, bukan nilai.
3. **Divergence = 1 titik**: semua 9 stok DIVERG=0 sampai Nov→Des, putus serentak **hanya** di 2026-01-01. (23 bulan sebelumnya konsisten.)
4. **engine `dw_refresh_stok` menghitung qty benar** (mis. TR.038A AKHIR=9), stored=45.

## LANGKAH 2–9 — WATERFALL (kurangi bucket satu per satu)
```
TOTAL GAP                                              16.762.544.094,50
  (−) Bucket C  Valuation ..................            0,00
        bukti: engine_qty×hpp = GL (selisih <Rp1/akun) → gap 100% qty
  (−) Bucket F  GL Missing ..................            0,00
        bukti: GL = transaksi (cocok <Rp1/akun); tak ada transaksi tanpa GL
  (−) Bucket A  Outstanding WIP-Out .........  1.512.525.638
        real serial WIP-Out ('88' tsales) belum ada WIP-In ('88' tstok),
        nilainya tercatat di GL 102-020 (Unit WIP). Porsi yg beririsan 9 stok phantom.
                                             ───────────────────
        Remaining                            15.250.018.456,50
  (−) Bucket B  Broken Cycle ................            0,00
        tak ada kasus WIP-In parsial tambahan di luar Bucket A
  (−) Bucket E  Manual Adjustment ...........            0,00
        TIDAK diklaim — tak ada bukti (tak ada audit trail); lihat Bucket D
  (−) Bucket D  Phantom Quantity (opening) .. 15.250.018.456,50
        qty stored > engine TANPA transaksi & BUKAN outstanding WIP;
        first-point = override saldo awal 2026-01-01 (engine=9, stored=45 dst);
        PENULIS BELUM TERIDENTIFIKASI (no audit trail — lihat ROOT_CAUSE_FINAL §D)
                                             ───────────────────
        REMAINING GAP                                   0,00   ← HABIS (100%)
```

## Catatan rekonsiliasi akun WIP 102-020 (terpisah dari 16,76 M di atas)
- GL 102-020 (WIP) saldo awal 2026 = **1.867.691.016**.
- Total Outstanding WIP-Out (semua reefer, per 31-12-2025) = **1.799.966.015**.
- Residu = **67.725.001** (GL 102-020 − Outstanding) → sub-residu di AKUN WIP, **bukan** bagian gap 16,76 M. Perlu pecah terpisah bila diminta (kandidat: WIP NR/TB lama / siklus parsial).
- Dari Outstanding 1.799.966.015: **1.512.525.638** beririsan 9 stok phantom (= Bucket A), sisa **287.440.377** di stok tanpa gap.

## Verifikasi jumlah
`Bucket A (1.512.525.638) + Bucket D (15.250.018.456,50) = 16.762.544.094,50 = TOTAL GAP.` ✔ (C,B,E,F = 0)
