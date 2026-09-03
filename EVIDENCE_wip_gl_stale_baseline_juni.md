# EVIDENCE — WIP-Out GL 102-020 stale (Baseline SEBELUM uji CONSOUT re-run)
Tanggal rekam: 2026-07-31. Sumber: prod vspnew (103.233.89.43).

## Fakta terbukti (read-only)
1. **Mekanisme f_transfer_cons** (baris 220-223): `delete from gl_journal where voucher=:arg_order_client and modul_id='AS'` lalu **posting ulang dari ttl_hpp**.
2. **ttl_hpp** (`d_trace_consout_real`) = `tsales2.qty * tsales2.hpp` = HPP WIP-Out **BEKU**.
3. **ttl_hpp RUNTIME** utk voucher 101260600017 (CIM1096180) = **249.707.668,74** (dikonfirmasi jalankan query d_trace_consout_real langsung).
   → Maka bila f_transfer_cons dieksekusi SEKARANG utk voucher itu, jurnal GL PASTI = 249.707.668,74, bukan 253.862.766.

## Yang MASIH hipotesis (belum terbukti)
"CONSOUT posting nilai transisi krn urutan modul." → dibuktikan/dibantah oleh uji CONSOUT-only.

## BASELINE SEBELUM — 23 voucher WIP-Out Juni stale (GL 102-020 debet vs ttl_hpp beku)
| Voucher | Serial | GL SEBELUM | ttl_hpp beku (target) | Selisih |
|---|---|--:|--:|--:|
| 101260600002 | CIM1096166 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600004 | CIM1096257 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600005 | CIM1096248 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600006 | CIM1096165 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600007 | CIM1096164 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600008 | CIM1096181 | 253.862.766,67 | 249.707.668,74 | 4.155.097,93 |
| 101260600009 | CIM1096262 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600013 | CIM1096240 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600015 | CIM1096169 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600017 | CIM1096180 | 253.862.766,67 | 249.707.668,74 | 4.155.097,93 |
| 101260600019 | CIM1096261 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600020 | CIM1096232 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600021 | CIM1096245 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600030 | CIM1096173 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600031 | CIM1096231 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600032 | CIM1096176 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600033 | CIM1096246 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600034 | CIM1096250 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600035 | CIM1096175 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600036 | CIM1096249 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |
| 101260600037 | CIM1096177 | 253.862.766,67 | 249.707.668,74 | 4.155.097,93 |
| 101260600041 | CIM1096174 | 222.647.195,01 | 215.984.724,82 | 6.662.470,19 |
| 101260600042 | CIM1096233 | 42.897.476,93 | 41.611.969,91 | 1.285.507,02 |

**Total selisih Juni = 81.191.139,55** (23 voucher).

## PROTOKOL UJI (Pak Wira)
1. Aplikasi produksi → menu Refresh → periode **01-06-2026 s/d 30-06-2026**.
2. **HANYA centang modul CONSOUT.** Uncheck SO/PO/NONITEM/EXP/AR/AP/ADJ/CONSIN. Jangan ada proses lain.
3. Jalankan. Selesai → kabari saya.

## VERIFIKASI SESUDAH (dijalankan agent)
Query yang sama diulang → harapan: **23 voucher GL berubah dari kolom "GL SEBELUM" → "ttl_hpp beku"**. Kalau semua cocok = HIPOTESIS TERBUKTI, lanjut CONSOUT-only Feb-Mei. Kalau tidak berubah = investigasi lanjut (cursor/delete/insert/overwrite).

---
# LAPIS 2 — BASELINE NERACA SEBELUM (direkam 2026-07-31, sebelum uji)

## Akun WIP (sinv vs GL, kumulatif s.d Jul / periode sinv 2026-08-01)
| Akun | sinv | GL | Gap SEBELUM |
|---|--:|--:|--:|
| 102-001 (TR) | 20.117.206.135,26 | 9.721.679.452,89 | **10.395.526.682,37** |
| 102-003 (NR) | 132.094.965,00 | 93.594.965,15 | 38.499.999,85 |
| 102-006 (TB) | 2.613.315.542,90 | 1.729.884.419,70 | 883.431.123,20 |

## 102-020 (Unit Work in Process) SEBELUM
- Saldo akhir (opening+Jan-Jul): **2.851.299.782,42**
- Debit total Jan-Jul (WIP-Out): **37.019.642.335,75**

## HARAPAN SESUDAH CONSOUT-only JUNI (uji 1 bulan)
Uji hanya re-post WIP-Out JUNI (23 voucher, total selisih 81.191.139,55; semuanya akun 102-001/TR).
- **Lapis transaksi:** 23 voucher GL 102-020 debet berubah 253.862.766→249.707.668 dst (ke ttl_hpp beku).
- **Lapis neraca (efek Juni saja):**
  - GL 102-001 mutasi naik +81.191.139,55 (kredit WIP-Out berkurang) → **Gap 102-001: 10.395.526.682,37 → ~10.314.335.542,82** (turun 81,19 jt).
  - GL 102-020 debet total: 37.019.642.335,75 → **~36.938.451.196,20** (turun 81,19 jt).
  - GL 102-020 saldo akhir: 2.851.299.782,42 → **~2.770.108.642,87**.
- **Kriteria lulus:** turunnya gap 102-001 = **tepat 81.191.139,55** (bukan angka lain). Kalau tepat → dua lapis konsisten → lanjut Feb/Apr/Mei.

---
# HASIL UJI CONSOUT-only JUNI (2026-07-31) — LULUS ✅
## Lapis 1 (transaksi): 23 voucher Juni MASIH stale = **0** (semua ke nilai beku).
## Lapis 2 (neraca):
| | SEBELUM | SESUDAH | Δ |
|---|--:|--:|--:|
| GL 102-001 | 9.721.679.452,89 | 9.802.870.592,44 | +81.191.139,55 |
| Gap 102-001 | 10.395.526.682,37 | 10.314.335.542,82 | −81.191.139,55 |

**Turun gap = TEPAT 81.191.139,55 = total selisih 23 voucher.** Dua lapis konsisten.

## KEPUTUSAN: re-run CONSOUT = koreksi yang benar. TANPA GL manual.
Lanjut CONSOUT-only untuk sisa bulan stale: Feb (50,9jt), Apr (7,7jt), Mei (148,1jt), Mar (26,5jt*), Jul (0,07jt).
(*Mar = 1 kasus zero-opening re-konsinyasi TR.911A, cek terpisah — nilai beku-nya 0.)
Setelah semua: cek CONSIN (sisi WIP-In kredit) yg juga stale ~143jt.
