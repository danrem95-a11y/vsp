# MATRIKS BUCKET SELISIH — Rp 16.762.544.094,50 (100% terpecah)

Bucket mutually exclusive, tanpa overlap, tanpa double-count. Total = Rp 16.762.544.094,50.

## Ringkas per bucket
| Bucket | Kategori | Nilai | % | Confidence | Klasifikasi |
|---|---|--:|--:|---|---|
| A | Outstanding WIP-Out | 1.512.525.638 | 9,0% | TINGGI | WIP (real, di GL 102-020) |
| B | Broken Cycle | 0 | 0% | TINGGI | — |
| C | Valuation | 0 | 0% | TINGGI | — |
| D | Phantom Quantity (opening) | 15.250.018.456,50 | 91,0% | qty=TINGGI; penulis=BELUM TERIDENTIFIKASI | data/opening |
| E | Manual Adjustment | 0 (tak diklaim) | 0% | — | tak ada bukti |
| F | GL Missing | 0 | 0% | TINGGI | — |
| G | Lainnya | 0 | 0% | — | — |
| | **TOTAL** | **16.762.544.094,50** | 100% | | |

## Detail per-stok (9 stok penyumbang, urut nilai)
| Stok | Akun | stored | engine | phantom qty | outstanding qty | hpp | **Bucket A** (out×hpp) | **Bucket D** (phantom−out)×hpp |
|---|---|--:|--:|--:|--:|--:|--:|--:|
| TR.038A | 102-001 | 45 | 9 | 36 | 2 | 247.123.579 | 494.247.158 | 8.402.201.689 |
| TR.039A | 102-001 | 31 | 13 | 18 | 2 | 211.206.845 | 422.413.690 | 3.379.309.521 |
| TR.1006A | 102-001 | 42 | 18 | 24 | 2 | 39.585.997 | 79.171.993 | 870.891.924 |
| TB.10001 | 102-006 | 7 | 1 | 6 | 0 | 147.238.520 | 0 | 883.431.122 |
| TR.040A | 102-001 | 13 | 9 | 4 | 1 | 201.915.420 | 201.915.420 | 605.746.261 |
| TR.910A | 102-001 | 51 | 28 | 23 | 6 | 27.165.190 | 162.991.138 | 461.808.223 |
| NR.401A | 102-003 | 8 | 0 | 8 | 0 | 48.000.000 | 0 | 384.000.000 |
| TR.1004A | 102-001 | 23 | 17 | 6 | 0 | 35.339.051 | 0 | 212.034.304 |
| TR.1007A | 102-001 | 9 | 5 | 4 | 3 | 50.595.413 | 151.786.239 | 50.595.413 |
| **TOTAL** | | | | **125** | **16** | | **1.512.525.638** | **15.250.018.457** |

## Bukti per bucket (LANGKAH 5)

### Bucket A — Outstanding WIP-Out = Rp 1.512.525.638
- **Nilai/serial:** 16 serial (di 9 stok phantom) WIP-Out ('88' tsales) belum ada WIP-In ('88' tstok). Contoh serial: CIM1083290 (TR.038A, WIP-Out 2025-12-31), CIM1083284 (TR.038A, 2025-12-26), CIM1086504 (TR.039A), CIM1083390 (TR.910A), dst.
- **Voucher:** order_client per serial (tsales1 '88').
- **First point:** tanggal WIP-Out masing-masing serial (Des-2025).
- **SQL:** `count(distinct evap) WHERE tipe_trans='88' AND NOT EXISTS(WIP-In tstok '88' coa_id=evap) AND tgl<='2025-12-31'`.
- **Evidence:** GL 102-020 (1.867.691.016) ≈ Total Outstanding WIP-Out (1.799.966.015), residu 67,7 jt.
- **Confidence: TINGGI.** Real, tercatat di GL 102-020.

### Bucket C — Valuation = Rp 0
- **Evidence:** engine_qty × hpp = GL persis (102-001 selisih Rp 0,34; 102-003 Rp 0,15; 102-006 Rp 0,90). Tak ada komponen beda-HPP. **Confidence: TINGGI.**

### Bucket F — GL Missing = Rp 0
- **Evidence:** GL = transaksi sampai <Rp 1/akun (23 bulan alur konsisten; engine=GL). Tak ada transaksi tanpa posting GL. **Confidence: TINGGI.**

### Bucket B/E/G = Rp 0
- **B Broken Cycle:** tak ada WIP-In parsial tambahan di luar A. **E Manual Adjustment:** TIDAK diklaim — tak ada bukti (audit trail nihil). **G:** nihil.

### Bucket D — Phantom Quantity (opening) = Rp 15.250.018.456,50
- **Nilai/qty:** 109 unit hantu (125 phantom − 16 outstanding) × hpp masing-masing; per stok di tabel kolom Bucket D.
- **Serial/voucher:** **TIDAK ADA** — ini selisih QTY di saldo awal `sinv 2026-01-01`, bukan transaksi/serial. (sinv per-stok, bukan per-serial.)
- **First point of divergence:** **2026-01-01** — saldo awal SINV di-set qty > engine (TR.038A 45 vs engine 9; dst), tanpa transaksi Des yang mendukung (DIVERG Des→Jan = phantom qty; DIVERG Nov→Des = 0).
- **SQL:** `stored = sinv.qty(2026-01-01)`; `engine = sinv.qty(2025-12-01) + net Des`; keduanya diverifikasi = `dw_refresh_stok` AKHIR & = GL.
- **Evidence:** engine `dw_refresh_stok` dijalankan → AKHIR=9; stored=45; selisih tak ada di transaksi mana pun, tak di GL, tak outstanding-WIP.
- **Penulis:** **BELUM TERIDENTIFIKASI** — USER_LOG (6 baris Jul-2026) & refresh_jurnal_log (34 baris Jul-2026) tak mencakup Des-2025/Jan-2026; semua proses aplikasi kini menghitung 9. Lihat ROOT_CAUSE_FINAL §D.
- **Confidence:** nilai & qty & first-point = **TINGGI**; identitas penulis = **TIDAK DAPAT DIBUKTIKAN** (kondisi STOP-2).

## Klasifikasi (LANGKAH 10)
| Bucket | Bug engine? | Bug historis? | Data? | Jurnal? | Valuasi? | Opening? | WIP? |
|---|---|---|---|---|---|---|---|
| A Outstanding WIP | Tidak | Tidak | Tidak | Tidak (GL 102-020 benar) | Tidak | Tidak | **YA** |
| D Phantom Qty | **Tidak** (engine hitung 9) | tak dpt dibuktikan | **YA** (saldo awal sinv) | Tidak (GL benar) | Tidak | **YA** (2026-01-01) | Tidak |
