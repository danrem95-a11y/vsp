# ROOT CAUSE FINAL — Gap Persediaan Reefer Rp 16.762.544.094,50

Ditulis karena **100% gap sudah terpecah** ke bucket mutually-exclusive (WATERFALL_REKONSILIASI_GAP.md, MATRIKS_BUCKET_SELISIH.md). Satu bucket mencapai kondisi STOP-2 (identitas penulis tak dapat dibuktikan karena sistem tak punya audit trail); didokumentasikan penuh di §D.

## Total gap = Rp 16.762.544.094,50 → terpecah 2 root cause:

---

## ROOT CAUSE A — Outstanding WIP-Out (Rp 1.512.525.638) — TERBUKTI
**Apa:** 16 serial reefer yang sudah WIP-Out ('88' tsales) tetapi belum ada WIP-In ('88' tstok) per 31-12-2025. Unit ini **fisik keluar konsinyasi/WIP**, nilainya **benar tercatat di GL 102-020** (Unit Work in Process).
**Bukti:** GL 102-020 saldo awal 2026 = 1.867.691.016 ≈ Total Outstanding WIP-Out 1.799.966.015 (residu 67,7 jt, sub-akun WIP). Counterpart posting 102-020 ↔ 102-001 (Dr 102-020/Cr 102-001) terbukti.
**Sifat:** BUKAN error. Ini WIP sah. Muncul sebagai "gap" hanya bila rekonsiliasi 102-001 **tidak** menyertakan 102-020. **Hipотesis Pak Wira ("Selisih WIP-Out = saldo 102-020") TERBUKTI untuk porsi ini.**
**Confidence: TINGGI.**

---

## ROOT CAUSE D — Phantom Quantity di Saldo Awal SINV 2026-01-01 (Rp 15.250.018.456,50) — SEBAGIAN TERBUKTI (STOP-2)

### Yang TERBUKTI (Confidence TINGGI)
1. **Bentuk selisih = QTY, bukan nilai.** engine_qty × hpp = GL persis (selisih < Rp 1 per akun) → valuasi 0; gap 100% qty. (Bukti: LANGKAH engine=GL.)
2. **Nilai benar = engine = GL.** `dw_refresh_stok` (engine closing) dijalankan langsung untuk Des-2025 → AKHIR = 9 (TR.038A) dst; sama dengan GL sampai rupiah, untuk **ketiga akun** 102-001/003/006.
3. **First Point of Divergence = 2026-01-01.** Rekonsiliasi bulanan konsisten **23 bulan** (Jan-2024…Nov-2025, DIVERG=0), putus **serentak hanya** di 2026-01-01 (DIVERG = phantom qty). Bukan akumulasi, bukan mutasi Jan–Jul.
4. **Opening 2026 ≠ Closing 2025 (transaksi/engine).** Closing Des-2025 (engine) = 9; saldo awal 2026 (stored) = 45; selisih +36 **tanpa** transaksi Des pendukung dan **bukan** outstanding WIP (outstanding TR.038A hanya 2). Phantom 109 unit total (di luar 16 outstanding).
5. **Bukan bug engine kini, bukan posting GL hilang.** Semua jalur aplikasi kini (`n_cst_closing_stock` NVO, `w_closing_stok` yang memakai `dw_view=dw_refresh_stok`) menghitung 9; kode entri-fisik manual di `w_closing_stok` (L263-417) ter-comment mati. GL cocok transaksi.

### Yang TIDAK DAPAT DIBUKTIKAN (kondisi STOP-2) — PENULIS BELUM TERIDENTIFIKASI
Siapa/kapan/kenapa saldo awal 2026 di-set 45 (bukan 9).
- **Bukti yang sudah dicari:** (a) USER_LOG — hanya 6 baris, semua Jul-2026; (b) refresh_jurnal_log — 34 baris, semua Jul-2026; (c) transaksi adjustment/opname pada tstok/tsales Des-2025/Jan-2026 — tak ada (hanya '02'/'05'/'88'); (d) kode penulis sinv (call-graph 6 window) — semua menghitung 9; (e) pola nilai (serial/outstanding/kelipatan) — tak ada yang cocok dengan +36/+18/…
- **Mengapa tak bisa dibuktikan:** tabel `sinv` **tidak punya audit trail** (tak ada kolom user/tanggal-tulis/asal-proses); log aplikasi tak mencakup periode tutup-tahun 2025→2026 (mulai Jul-2026). Nilai phantom tak terderivasi dari transaksi mana pun sehingga tak bisa ditelusuri ke voucher.
- **Nilai bucket:** Rp 15.250.018.456,50.
- **Mengapa tak mungkin memperoleh bukti lebih lanjut dari data yang tersedia:** tak ada sumber lain yang merekam penulisan `sinv` historis (bukan di gl_journal, bukan di tstok/tsales, bukan di log). Untuk identifikasi penulis diperlukan artefak di luar database (backup lama, catatan operasional, wawancara) — di luar jangkauan data yang ada.
- **Label yang TIDAK dipakai** (sesuai aturan Bapak): tidak disebut "manual", "override sengaja", atau "anomali" tanpa bukti. Yang terbukti: **selisih QTY di saldo awal SINV 2026-01-01, di luar rantai transaksi; penulis belum teridentifikasi.**

**Confidence:** asal (apa/di mana/kapan/besaran) = **TINGGI**; agen/niat penulis = **TIDAK DAPAT DIBUKTIKAN (STOP-2)**.

---

## Rekonsiliasi akhir
```
TOTAL GAP                         16.762.544.094,50
  Root Cause A (WIP, GL 102-020)   1.512.525.638      TERBUKTI
  Root Cause D (Phantom opening)  15.250.018.456,50   asal TERBUKTI; penulis STOP-2
  Bucket B/C/E/F/G                          0
                                 ──────────────────
  REMAINING                                 0,00      ← 100% terjelaskan
```
Tak ada rupiah yang tanpa asal-usul: 100% = A (WIP sah) + D (phantom qty di saldo awal, asal terbukti, penulis tak dapat dibuktikan karena tak ada audit trail).

## Batas (sesuai arahan)
- **Tidak** ada usulan koreksi / jurnal / update di dokumen ini (murni forensik).
- **Tidak** mengubah engine refresh (sudah disetujui, terbukti benar — menghitung 9).
- Residu sub-akun WIP 67,7 jt (GL 102-020 vs Outstanding) = di luar gap 16,76 M; dapat dipecah terpisah bila diminta.
