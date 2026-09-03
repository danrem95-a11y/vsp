# MOVEMENT ROOT CAUSE REPORT — GL vs Stock Movement 2026 (PROD SERVER-NEW)

**Lingkup:** Rekonsiliasi *movement* (bukan opening — recovery phantom sudah CLOSED). Mencari sebab **GL movement 2026 ≠ Stock movement 2026** per akun persediaan.
**Metode:** 100% **READ-ONLY** di prod (hanya SELECT). Tidak ada perubahan sinv/GL, tidak ada adjustment, tidak ada transaksi koreksi. Audit trail + root cause saja.
**Tanggal audit:** 2026-08-01 (prod SERVER-NEW, tcp 103.233.89.43:2638, ENG=vspnew).
**Aturan:** TIDAK memberi solusi koreksi — hanya root cause transaksi.

---

## 1. RINGKASAN ROOT CAUSE

| # | Root cause | Sifat | Status | Dampak Jan-Feb |
|---|---|---|---|---|
| **RC-1** | **BTB (terima barang) dengan `tstok2.produk_id` KOSONG** | Sistemik (9 akun) | **B — missing stock movement** | ~Rp 620 jt bruto |
| **RC-2** | **TL.203.0504: qty sinv naik tanpa transaksi pembelian** | 1 item (102-102) | anomali qty (phantom stock qty) | distorsi HPP + gap 102-102 |
| RC-3 | 102-101 residu modul AS/EX/HP (cons/freight/COGS) | perlu telusur lanjut | belum diklasifikasi final | ~Rp 14 jt |

**Inti RC-1:** barang diterima → **GL dibukukan** (Dr persediaan 102-xxx / Cr 226-001 Hutang Dagang + 104-111 PPN Masukan, modul **PO**) — TAPI baris stok (`tstok2`) **tidak diisi produk** → unit **tak pernah masuk ledger persediaan (sinv)** → **GL movement > stock movement**. Dikonfirmasi ke rupiah pada 102-203 (100% gap).

---

## 2. RC-1 — Blank-produk BTB (sistemik). Atribusi per akun (Jan-Feb 2026)

| akun persediaan | grup | jml BTB | netto blank-produk |
|---|---|--:|--:|
| 102-110 | L-LOKAL | 53 | 255.120.566,80 |
| **102-203** | BOX FIBERGLASS | 2 | **117.500.000,00** |
| 102-003 | — | 2 | 96.000.000,00 |
| **102-102** | — | 6 | 56.986.700,00 |
| **102-010** | TOYO UNIT | 3 | 50.106.000,00 |
| **102-101** | — | 5 | 31.334.751,34 |
| 102-103 | — | 5 | 12.451.230,00 |
| 102-001 | TR (reefer) | 4 | 692.270,00 |
| 102-018 | — | 1 | 364.115,00 |
| **TOTAL** | | **81** | **~620 jt** |

**User input:** `alfa` / `ALFA` / `super`.
**Catatan netting:** netto blank ≠ gap bersih tiap akun. Bersih = blank-BTB (GL tanpa stok) − gerakan lain (issue/jual) yang meng-offset. **102-203 = 1:1** (paling bersih). **102-110** netto blank 255 jt tapi gap bersih hanya −1,56 jt → baris blank di sana sebagian besar ter-offset (kemungkinan baris biaya/freight pada BTB yang juga punya baris produk valid) → perlu netting per-BTB (sekunder).

---

## 3. EVIDENCE TABLE per prioritas

### Prioritas 1 — 102-203 Feb Rp 117.500.000 (STATUS B) ✅ root cause tuntas
| tgl | voucher GL | bukti stok | modul | user | Dr | Cr | ref dokumen | pasangan stok | status |
|---|---|---|---|---|---|---|---|---|---|
| 02-Feb-26 | 101BTB260200022 | 10126020200022 | PO | alfa | 102-203 50.500.000 + 104-111 5.555.000 | 226-001 56.055.000 | 001/MAS-PRO.INV/2026 (MITRA SUKSES ABADI) | tstok2 ADA (qty 1, netto 50,5 jt) **produk_id KOSONG** | **B** |
| 27-Feb-26 | 101BTB260400004 | 10126040200004 | PO | ALFA | 102-203 67.000.000 + 104-111 7.370.000 | 226-001 74.370.000 | 201/KW/IV/2026 (PEMBELIAN 1 UNIT FULL BOX) | tstok2 ADA (qty 1, netto 67 jt) **produk_id KOSONG** | **B** |

→ 100% gap 102-203 = 2 BTB blank-produk. **Anomali tambahan:** voucher `101BTB2604…` ber-kode periode **April** tapi tanggal **Feb** (penomoran lintas-periode).

### Prioritas 2 — 102-101 Jan-Feb (gap Feb −45.520.148)
Bagian ter-identifikasi = **5 BTB blank-produk (Rp 31.334.751)** — Dr 102-101 (+102-110) / Cr 226-001, modul PO:
| tgl | bukti stok | user | netto | ref dokumen | status |
|---|---|---|--:|---|---|
| 02-Jan-26 | 10126120200001 | alfa | 8.532.000 | H-TECH 15796 (⚠ bukti ber-kode Des `2612`) | B |
| 09-Jan-26 | 10126010200031 | ALFA | 8.544.000 | H-TECH 15916 | B |
| 20-Jan-26 | 10126010200016 | super | 2.539 | TK.001-040225 INV.1301926 | B |
| 28-Jan-26 | 10126010200027 | super | 11.212 | TK.001-070126 INV.1302426 | B |
| 10-Feb-26 | 10126020200019 | ALFA | 14.245.000 | MULIA JAYA 7979 | B |

Contoh pasangan (bukti MULIA JAYA, voucher 101BTB260200019): Dr **102-101 11.200.000** + Dr 102-110 3.045.000 / Cr 226-001 11.200.000 + 3.045.000.
**Residu ~Rp 14 jt (RC-3):** gap Feb 45,5 jt > blank-BTB 31,3 jt → sisa dari modul **AS** (consinyasi), **EX** (ekspedisi/freight), **HP** (COGS penjualan/instalasi) — perlu telusur per-voucher (belum diklasifikasi final; JANGAN diasumsikan).

### Prioritas 3 — 102-010 (TOYO UNIT) Jan-Feb (gap Feb −30.796.000)
**3 BTB blank-produk (Rp 50.106.000)** — Dr 102-010 / Cr 226-001, modul PO:
| tgl | bukti stok | user | qty | netto | ref dokumen | status |
|---|---|---|--:|--:|---|---|
| 07-Jan-26 | 10126010200019 | alfa | 1 | 5.336.000 | THERMO ASRI MANDIRI 006/FK-TA | B |
| 13-Jan-26 | 10126010200021 | alfa | 9 (+5) | 24.570.000 (+200.000) | THERMO ASRI MANDIRI 010/FK-TA | B |
| 28-Feb-26 | 10126020200036 | alfa | 1 (+1) | 20.000.000 | THERMO ASRI MASYUR TAM/055/02 | B |

Sisi issue (modul **HP**): saat unit dijual/dipasang → Cr 102-010 (Rp 2.730.000/unit = hpp TYU-001B) / Dr 402-002 (HPP). COGS valid, tetapi stok tak bisa berkurang wajar karena unit **tak pernah masuk** (BTB blank). → gap = akumulasi RC-1.

### Prioritas 4 — 102-102 TL.203.0504 (RC-2, anomali qty — BUKAN blank-produk)
| bukti | sinv qty | temuan |
|---|--:|---|
| sinv 01-Jan (opening) | 4.472,80 | hpp_avg 416,38 |
| sinv 01-Feb (closing Jan) | **25.502,80** | **+21.030 unit** padahal ada 11 penjualan Jan |
| sinv 01-Mar (closing Feb) | 20.627,80 | hpp_avg melonjak 435→506 (moving-avg terdistorsi) |

- **tsales '22' (penjualan) Jan-Feb: 28 transaksi** (turunkan stok) — normal.
- **tstok (pembelian) TL.203.0504 sepanjang 2026: 0 baris** → **stok bertambah 21.030 unit TANPA transaksi pembelian yang bisa ditelusuri.**
- → Qty sinv **tidak konsisten dengan transaksi** = anomali/korupsi qty (selaras isu terdokumentasi "TL.203.0504 salah input qty"). Plus 102-102 punya 6 BTB blank-produk (Rp 57 jt) dari RC-1.
- **Status:** anomali qty (phantom stock qty) — perlu telusur asal 21.030 unit (di luar tstok/tsales standar). BUKAN kategori A/B/C/D BTB; kelas tersendiri.

---

## 4. LEGENDA STATUS
- **A. jurnal non-stock valid** — tak ditemukan pada prioritas ini (semua BTB seharusnya berpasangan stok).
- **B. missing stock movement** — GL terbukukan, baris stok ada tapi **produk kosong** → tak masuk ledger. **(RC-1, dominan).**
- **C. duplicate posting** — tak ditemukan bukti pada sampel ini.
- **D. salah akun** — tak terkonfirmasi (akun GL & akun produk tak bisa dibandingkan karena produk kosong; bukan salah-akun melainkan tanpa-produk).
- **Anomali qty** (RC-2) — di luar A/B/C/D; qty stok berubah tanpa transaksi sumber.

## 5. KESIMPULAN
1. **Penyebab dominan (RC-1): BTB diinput tanpa `produk_id`** → GL membukukan nilai persediaan (Dr 102-xxx / Cr 226-001 + PPN) tetapi **perpetual stock (sinv) tidak mencatat unit** → GL movement > stock movement. Sistemik: 9 akun, ~Rp 620 jt (Jan-Feb), user alfa/super. Terbukti 1:1 di 102-203.
2. **RC-2: TL.203.0504** — qty sinv naik 21.030 tanpa pembelian → anomali qty, mendistorsi HPP & gap 102-102.
3. **RC-3: residu 102-101** dari modul AS/EX/HP — belum tuntas, perlu telusur per-voucher.

## 6. YANG BELUM TUNTAS (perlu telusur lanjutan, tetap read-only)
- Netting per-BTB 102-110 (255 jt blank vs gap −1,56 jt): pastikan apakah baris blank = baris biaya pada BTB berproduk-valid.
- 102-101 modul AS (consinyasi) / EX (freight) / HP (COGS): dekomposisi per-voucher.
- RC-2 TL.203.0504: asal 21.030 unit (tstok0/tsales0) — cek mutasi/adjustment/opening-carry atau jalur non-standar.

**TIDAK ada koreksi diusulkan** (sesuai instruksi) — laporan ini murni root cause & audit trail. Langkah koreksi menunggu keputusan setelah root cause per item disepakati.
