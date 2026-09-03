# AUDIT KANDIDAT — Penjualan HPP=0 (Movement Gap Costing 2026)

> **READ-ONLY. Belum ada koreksi.** Daftar untuk review accounting. Recovery opening 2026 / Des 2025 / WIP tidak disentuh.
> Sumber: `tsales2` TIPE '22' (jual), `HPP=0`, Jan–Feb 2026, akun persediaan 102%. Detail lengkap: **`HPP0_candidates_2026.csv`** (kolom: tgl, bukti, voucher, item, akun, qty, user, avg_awal_bln, beli_unit_bln, avg_ref, est_nilai_hilang, klasifikasi).

## Ringkasan per akun

| Akun | Jual HPP=0 | Kandidat BUG (ada avg) | Est. nilai hilang | Gap movement | Status rekonsiliasi |
|---|--:|--:|--:|--:|---|
| **102-203** | 2 | 2 | **117.500.000** | 117.500.000 | ✅ **COCOK PERSIS** (100% = HPP=0) |
| **102-103** | 1 | 1 | **2.172.480** | 2.172.480 | ✅ **COCOK PERSIS** |
| 102-010 | 15 | 3 | 10.796.000 | 30.796.000 | ⚠️ sebagian (sisa = 12 jual `TYU-001` base avg=0 + nuansa beli-jual sebulan) |
| 102-101 | 9 | 7 | 34.887.557 | 45.520.154 | ⚠️ sebagian (sisa perlu telaah) |
| 102-110 | 8 | 3 | 749.994 | 1.561.594 | ⚠️ sebagian |
| 102-102 | 2 | 0 | 0 | 13.500.000 | ❓ belum terjelaskan HPP=0 (perlu telaah lain) |
| **102-001** | **117** | **0** | 0 | 0 (MATCH) | ✅ **HPP=0 by design (WIP reefer)** — BUKAN bug |
| 102-003 | 2 | 0 | 0 | 0 | HPP=0 avg 0 (cek) |

**Total kandidat BUG (ada moving-avg): ~Rp166 jt** pada 5 akun (203/101/010/103/110).

## Interpretasi (bukti, bukan asumsi)
- **102-203 & 102-103: gap = HPP=0 (ada avg) PERSIS** → root cause costing terbukti 1:1.
- **102-001: 117 jual HPP=0 tapi semua avg=0 = WIP reefer (by design)** — akun ini MATCH, jadi HPP=0-nya benar (cost via mekanisme WIP '88'). **Jangan diperlakukan sebagai bug.** ← contoh penting "HPP=0 memang nol".
- **102-010/101/110: sebagian** — kandidat BUG menjelaskan sebagian gap; sisanya = item base (`TYU-001`) avg=0 (mungkin sengaja) atau nuansa beli-jual dalam bulan yang sama (cost dari pembelian bulan itu, kolom `beli_unit_bln` di CSV). Perlu telaah per item.
- **102-102: 2 jual HPP=0 tapi avg=0 & gap 13,5jt belum terjelaskan** → perlu investigasi terpisah (bukan pola HPP=0-with-avg).

## Klasifikasi (kolom `klasifikasi` di CSV)
- **BUG-kandidat (isi average)** — `avg_ref>0` (ada moving-avg / harga beli bulan itu). Kandidat koreksi HPP.
- **CEK-0 (keputusan accounting)** — `avg_ref=0` (tak ada cost basis). Termasuk WIP reefer 102-001 (by design) & base model. **Jangan otomatis dikoreksi.**

## Langkah berikut (belum eksekusi)
1. **Accounting review** daftar CSV: pisahkan BUG vs sengaja-nol vs perlu keputusan.
2. Untuk item base/varian (`TYU-001` vs `TYU-001A/B`): konfirmasi kebijakan cost (apakah base sengaja 0).
3. Telaah 102-102 (gap 13,5jt di luar pola HPP=0-with-avg).
4. **Setelah approval:** isi `tsales2.HPP` = average (hanya baris disetujui) → refresh resmi → validasi (GL=stok, WIP/HPP-WIP tetap, idempotent). **Tanpa jurnal balancing.**

> **Dampak akuntansi:** koreksi menaikkan COGS (yang selama ini understated) → **turun laba** periode terkait → butuh **sign-off manajemen**. Ini keputusan akuntansi, bukan teknis. **Belum ada UPDATE dilakukan.**
