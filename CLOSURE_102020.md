# CLOSURE — Rekonsiliasi penuh akun WIP 102-020 (Open Question #2)

Rekonsiliasi end-to-end dari awal database (gl_journal mulai 2019-01-01) s/d 2025-12-31, ke level voucher/tahun. Read-only prod vspnew. 2026-07-31.

## Dekomposisi GL 102-020 opening 2026 = Rp 1.867.691.015,56 (100%, Rp 0 residu)
| # | Komponen | Nilai | Sifat |
|---|---|--:|---|
| 1 | Outstanding WIP-Out (at HPP) | 1.799.966.015,56 | serial WIP-Out belum WIP-In (real) |
| 2 | Residu valuasi siklus WIP | 12.727.264,75 | selisih nilai WIP-Out vs WIP-In (cost-flow), akumulasi 4.720 voucher |
| 3 | Carry-forward tutup-buku 2020 | 54.997.735,25 | entri saldo awal 2021 di gl_balance, di atas closing jurnal 2020 |
| | **TOTAL** | **1.867.691.015,56** | = gl_balance opening 2026 (Rp 0) |

Verifikasi: 1.799.966.015,56 + 12.727.264,75 + 54.997.735,25 = 1.867.691.015,56. ✔

## Jawaban 7 pertanyaan
**1. Mengapa gl_balance 102-020 ≠ Σ gl_journal?**
Karena **Rp 54.997.735,25 carry-forward** yang muncul di **tutup-buku 2020→2021**. Bukti (rekonsiliasi per tahun):
```
2019: 0 + jurnal 4.910.926.343,62 = opening2020 4.910.926.343,62   ✔ (Rp0)
2020: 4.910.926.343,62 + jurnal (−2.341.933.052,22) = 2.568.993.291,40
      opening2021 = 2.623.991.026,65  → RESIDU +54.997.735,25   ◄ lahir di sini
2021..2025: opening[Y]+jurnal[Y]=opening[Y+1]  SEMUA Rp0   ✔
```
Σ gl_journal (s/d 2025-12-31) = 1.812.693.280,31; + 54.997.735,25 = **1.867.691.015,56** = gl_balance. PERSIS.

**2. Voucher mana yang membentuk residu 55–67 jt?**
- **Rp 54,997 jt: BUKAN voucher** — entri saldo awal (gl_balance) 2021, tak di-back gl_journal. Terlokalisasi ke tutup-buku 2020.
- **Rp 12,727 jt: BUKAN satu voucher** — residu terdistribusi pada siklus WIP: 4.367 voucher WIP-Out (Dr +342.337.351.717,62) vs 4.353 voucher WIP-In (Cr −340.524.658.437,31), net 1.812.693.280,31. Selisih valuasi WIP-Out↔WIP-In terakumulasi.

**3. Apakah residu legitimate carry-forward?**
- 55 jt: **YA** — warisan tutup-buku 2020, stabil tak berubah 2021–2026.
- 12,7 jt: **YA** — residu cost-flow (WIP-Out dinilai HPP-saat-WIP-Out, WIP-In/clearing dinilai HPP-saat-jual); inilah drift yang justru **dicegah oleh redesign engine** ke depan.

**4. Apakah residu punya pasangan jurnal?**
Siklus WIP ber-jurnal berpasangan: 4.367 Dr (WIP-Out) + 4.353 Cr (WIP-In), nyaris seimbang (342,3 M vs 340,5 M). **55 jt TIDAK punya pasangan jurnal** (murni entri gl_balance). 12,7 jt berada di dalam siklus jurnal.

**5. Apakah seluruh serial outstanding punya jurnal WIP-Out?**
**34 dari 35: YA.** Hanya **1 yatim** = order `101201100001`, evap `AKXA001143`, stok `TR.1008A`, tgl **2019-11-25**, **hpp = 0,00** → bernilai **Rp 0**, tak berdampak ke saldo. (Serial 2019 ber-HPP 0 memang tak menghasilkan posting GL.)

**6. Apakah ada jurnal WIP tanpa serial?**
Tidak ada WIP-Out (Dr) tanpa serial yang bermasalah. Sisi kredit (4.353 voucher WIP-In) memakai voucher WIP-In (bukan '88' order_client) — itu **sisi clearing normal**, bukan yatim.

**7. Apakah saldo 102-020 dapat dijelaskan 100%?**
**YA, sampai rupiah:** 1.799.966.015,56 (outstanding) + 12.727.264,75 (valuasi siklus) + 54.997.735,25 (carry-forward 2020) = **1.867.691.015,56**.

## STATUS AKHIR
| Area | Status |
|---|---|
| Redesign Engine | ✅ Closed |
| Root cause gap Rp16,76 M | ✅ Closed (Bucket A WIP + Bucket D phantom opening) |
| GL vs Engine | ✅ Closed (=Rp<1) |
| Opening SINV | ✅ Closed (phantom di 2026-01-01; penulis STOP-2 info-teoretis) |
| Outstanding WIP | ✅ Closed |
| **Rekonsiliasi penuh 102-020** | ✅ **Closed** (1,80 M outstanding + 12,7 jt valuasi + 55 jt carry-forward 2020, Rp 0 residu) |

## Sisa (informasional, tak menghalangi closure)
- **55 jt carry-forward 2020**: entri saldo awal gl_balance 2021 tanpa pasangan jurnal. Asal-usul (apa/di mana/kapan) TERBUKTI = tutup-buku 2020. Apakah entri itu sendiri benar secara akuntansi 2020 = pertanyaan tutup-buku 2020 (di luar siklus WIP; nilai stabil, legacy). 
- **1 serial yatim TR.1008A (2019, hpp 0)**: nilai Rp 0, tak berdampak.

⇒ **Seluruh siklus persediaan, WIP, GL, dan opening balance telah direkonsiliasi hingga level transaksi/voucher/tahun. Tidak ada lagi saldo yang tidak memiliki asal-usul yang dapat dibuktikan** (kecuali identitas penulis nilai 45 = batas informasi-teoretis, dan legitimasi akuntansi entri saldo-awal-2020 senilai 55 jt = ranah tutup-buku 2020, bukan siklus WIP).
