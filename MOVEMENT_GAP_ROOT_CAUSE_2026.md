# MOVEMENT GAP ROOT CAUSE 2026 — GL vs Stok (PROD SERVER-NEW)

**Lingkup:** audit **movement 2026** (recovery opening 2026 = CLOSED/TERKUNCI, TIDAK disentuh). Semua gap tersisa = **pure movement gap**.
**Metode:** 100% **READ-ONLY** prod (SELECT saja). Tanpa UPDATE/INSERT/DELETE, tanpa jurnal koreksi. Bukti sampai **nomor voucher/transaksi**.
**Tanggal:** 2026-08-01. **Script bukti:** `audit_movement_gap.sql`.
**Linkage GL↔stok BTB:** GL voucher `101BTB{pppp}{sssss}` ↔ stok BUKTI_ID `101{pppp}02{sssss}` (terverifikasi ke rupiah).

---

## 1. RINGKASAN ROOT CAUSE (semua terbukti transaksional, bukan asumsi)

| RC | Akar (bukti transaksi) | Status kategori | Bukti kunci |
|---|---|---|---|
| **RC-1** | **100% BTB terima-barang `tstok2.produk_id` KOSONG** → GL bukukan persediaan, stok tak tercatat | **GL ONLY** | 81 BTB Jan-Feb Rp620.555.633; **BTB berproduk-valid = 0** |
| **RC-2** | **BTB valuta asing: `tstok2.NETTO` disimpan mata uang asing (belum dikonversi)**, GL pakai IDR (valas×kurs) | **SALAH NILAI** | 10126010200016 USD; 10126010200027 USD (Thermo King, 102-101) |
| **RC-3** | **TL.203.0504: qty sinv naik tanpa transaksi pembelian** | **SALAH QTY** | +21.030 unit Jan, tstok beli = 0 |

**Bukti sistemik RC-1 (control):** dari **81 BTB (TIPE_TRANS='02') Jan-Feb 2026, YANG PUNYA produk_id valid = 0**. Semua 81 blank. → **BUG SISTEM** (form/proses BTB tidak menyimpan `produk_id`), bukan kelalaian sporadis.

---

## 2. TABEL REKONSILIASI per akun (acuan = sinv closing Feb vs GL closing Feb)

| Akun | Grup | Gap Feb (sinv−GL) | Pendorong: BTB blank (GL) | COGS jual (offset) | Status dominan |
|---|---|--:|--:|--:|---|
| **102-203** | BOX FIBERGLASS | **−117.500.000** | 117.500.000 | 0 | **GL ONLY** (100% = 2 BTB) |
| **102-101** | SPARE PART Thermo King | **−45.520.148** | 251.977.285 (incl. **232 jt USD**) | 236.950.695 | **GL ONLY + SALAH NILAI** |
| **102-010** | TOYO UNIT | **−30.796.000** | 49.906.000 | 19.110.000 | **GL ONLY** (49,9−19,1 = 30,8 ✓) |
| **102-102** | — | **−13.499.772** | 56.986.700 | 11.407.704 | **GL ONLY + SALAH QTY (TL.203.0504)** |
| 102-103 | — | −2.172.479 | 12.451.230 | 492.995 | GL ONLY (residu kecil) |
| 102-110 | L-LOKAL | −1.561.536 | 266.479.567 | 82.252.703 | mayoritas MATCH; residu kecil (blank BTB ter-offset) |

**Rekonsiliasi bersih terbukti:** 102-203 (gap = blank BTB persis) & 102-010 (gap = blank BTB − COGS persis). 102-103/110 gap kecil (blank BTB ter-offset gerakan lain — perlu netting per-voucher untuk sisa ≤Rp2,2jt).

---

## 3. EVIDENCE per akun (nomor voucher penyebab)

### 3.1 — 102-203 (STATUS GL ONLY, tuntas 100%)
| Tanggal | Voucher GL | Bukti stok | Modul | User | Dr | Cr | Ref | Pasangan stok | Status |
|---|---|---|---|---|---|---|---|---|---|
| 02-Feb | 101BTB260200022 | 10126020200022 | PO | alfa | 102-203 50.500.000 + 104-111 5.555.000 | 226-001 56.055.000 | 001/MAS-PRO.INV/2026 | tstok2 qty 1, netto 50,5jt, **produk KOSONG** | **GL ONLY** |
| 27-Feb | 101BTB260400004 | 10126040200004 | PO | ALFA | 102-203 67.000.000 + 104-111 7.370.000 | 226-001 74.370.000 | 201/KW/IV/2026 | tstok2 qty 1, netto 67jt, **produk KOSONG** | **GL ONLY** |

### 3.2 — 102-101 (GL ONLY + SALAH NILAI) — 2 impor USD dominan
| Tanggal | Voucher GL | Bukti | User | CURR/KURS | GL Dr (IDR) | Stok netto (valas) | Bukti hitung | Status |
|---|---|---|---|---|--:|--:|---|---|
| 20-Jan | 101BTB260100016 | 10126010200016 | super | USD 16.786 | 42.620.996,88 | 2.539,08 | 2.539,08×16.786 = 42.620.996,88 ✓ | **SALAH NILAI** |
| 28-Jan | 101BTB260100027 | 10126010200027 | super | USD 16.924 | 189.756.288,24 | 11.212,26 | 11.212,26×16.924 = 189.756.288,24 ✓ | **SALAH NILAI** |

Vendor 4SL.0305 (impor Thermo King). GL = USD×kurs (IDR benar), stok simpan USD mentah + produk kosong. Sisa 102-101 = BTB IDR blank kecil (H-TECH, MULIA JAYA, TK) + modul AS(cons)/EX(freight)/HP(COGS, match tsales jual 236,95jt).

### 3.3 — 102-010 (GL ONLY)
| Tanggal | Voucher GL | Bukti | User | Dr | Cr | Ref | Status |
|---|---|---|---|--:|--:|---|---|
| 07-Jan | 101BTB260100019 | 10126010200019 | alfa | 102-010 5.336.000 | 226-001 | THERMO ASRI MANDIRI 006/FK-TA | GL ONLY (produk kosong) |
| 13-Jan | 101BTB260100021 | 10126010200021 | alfa | 102-010 24.570.000 | 226-001 | THERMO ASRI MANDIRI 010/FK-TA | GL ONLY |
| 28-Feb | 101BTB260200036 | 10126020200036 | alfa | 102-010 20.000.000 | 226-001 | THERMO ASRI MASYUR TAM/055 | GL ONLY |

Sisi HP = COGS jual/instalasi TOYO UNIT (Cr 102-010 2.730.000/unit / Dr 402-002). Unit terjual dari saldo awal (nyata), pembelian baru (blank) tak masuk → gap 30,8jt.

### 3.4 — 102-102 / TL.203.0504 (SALAH QTY)
| Periode | sinv qty | hpp_avg | temuan |
|---|--:|--:|---|
| 01-Jan (open) | 4.472,80 | 416,38 | |
| 01-Feb (closing Jan) | **25.502,80** | 435,50 | **+21.030 unit** padahal 28 penjualan; **tstok pembelian TL.203.0504 sepanjang 2026 = 0** |
| 01-Mar (closing Feb) | 20.627,80 | 506,04 | moving-avg terdistorsi |

Qty stok bertambah tanpa transaksi pembelian yang bisa ditelusuri → **SALAH QTY**. Ditambah 6 BTB blank-produk (Rp57jt) di 102-102.

---

## 3.5 TABEL REKONSILIASI PER-VOUCHER (format wajib) — |Tanggal|Akun|GL Movement|Stok Movement|Selisih|Voucher|Status|

| Tanggal | Akun | GL Movement | Stok Movement | Selisih | Voucher | Status |
|---|---|--:|--:|--:|---|---|
| 02-Feb | 102-203 | 50.500.000 | 0 | 50.500.000 | 101BTB260200022 | GL ONLY |
| 27-Feb | 102-203 | 67.000.000 | 0 | 67.000.000 | 101BTB260400004 | GL ONLY |
| 20-Jan | 102-101 | 42.620.997 | 2.539 (USD, tak dikonversi) | 42.618.458 | 101BTB260100016 | SALAH NILAI |
| 28-Jan | 102-101 | 189.756.288 | 11.212 (USD, tak dikonversi) | 189.745.076 | 101BTB260100027 | SALAH NILAI |
| 02-Jan | 102-101 | 4.200.000 | 0 | 4.200.000 | 101BTB261200001 | GL ONLY |
| 09-Jan | 102-101 | 4.200.000 | 0 | 4.200.000 | 101BTB260100031 | GL ONLY |
| 10-Feb | 102-101 | 11.200.000 | 0 | 11.200.000 | 101BTB260200019 | GL ONLY |
| 07-Jan | 102-010 | 5.336.000 | 0 | 5.336.000 | 101BTB260100019 | GL ONLY |
| 13-Jan | 102-010 | 24.570.000 | 0 | 24.570.000 | 101BTB260100021 | GL ONLY |
| 28-Feb | 102-010 | 20.000.000 | 0 | 20.000.000 | 101BTB260200036 | GL ONLY |
| Jan-Feb | 102-102 | (qty) | +21.030 unit tanpa beli | — | stok_id TL.203.0504 | SALAH QTY |
| 02-Jan | 102-102 | 14.900.000 | 0 | 14.900.000 | 101BTB260100006 | GL ONLY |
| 08-Jan | 102-102 | 12.000.000 | 0 | 12.000.000 | 101BTB260100002 | GL ONLY |
| 26-Jan | 102-102 | 15.020.000 | 0 | 15.020.000 | 101BTB260100040 | GL ONLY |
| 05-Feb | 102-103 | 2.172.480 | 0 | 2.172.480 | 101BTB260200025 | GL ONLY |
| 04-Feb | 102-103 | 7.254.000 | 0 | 7.254.000 | 101BTB260200007 | GL ONLY |
| (37 BTB) | 102-110 | ~266.479.567 (bruto) | 0 | (ter-offset COGS/retur → gap bersih 1,56 jt) | 101BTB2601/2602* | GL ONLY (residu MATCH) |
| Jan-Feb | 102-101/010/102/103/110 | HP (COGS jual) | = tsales '22' | 0 | modul HP | MATCH |

> **Baca:** "Stok Movement" = netto stok yang benar-benar masuk ledger persediaan akun tsb. **0** = baris BTB berproduk KOSONG (RC-1). Untuk SALAH NILAI, stok tercatat tapi dalam **valuta asing mentah** (2.539/11.212 USD), bukan IDR. Daftar lengkap 81 BTB per (akun,voucher) dihasilkan oleh `audit_movement_gap.sql` bagian **B**.

## 4. STATUS KATEGORI (rekap)
- **GL ONLY** = RC-1 (BTB blank produk): dominan, semua akun target. GL bukukan, stok tak bergerak.
- **SALAH NILAI** = RC-2 (BTB valas netto belum dikonversi): 102-101 (2 voucher USD, Rp232jt).
- **SALAH QTY** = RC-3 (TL.203.0504): qty naik tanpa pembelian.
- **STOCK ONLY** = tidak ditemukan (tidak ada gerakan stok yang tanpa jurnal GL pada sampel ini).
- **MATCH** = sisi penjualan/COGS (modul HP = tsales '22') cocok dua sisi; 102-110 mayoritas match.

**Catatan penting (jangan salah simpul):** akun **unit serial** (102-001 reefer, 102-018) **juga** punya BTB valas+blank (mis. 10126020200020 USD Dr 102-001 Rp3,586 M; 10126010200033 CNY Dr 102-018 Rp881 jt) TAPI **rekonsiliasi keduanya SEMPURNA** (gap ~0) — jalur valuasi unit serial menanganinya. Jadi defect RC-1/RC-2 **hanya menimbulkan gap pada akun spare-part/non-serial** (102-101/203/010/102/103/110). WIP **tidak** disebut sebagai penyebab (tak ada bukti transaksi WIP pada gap ini).

---

## 5. JAWABAN: perlu koreksi atau jurnal non-stock yang benar?
Ini **BUKAN** jurnal non-stock yang benar. Semua adalah **terima barang (BTB) yang SEHARUSNYA punya gerakan stok** tetapi stok tak tercatat (produk kosong / nilai valas). → **perlu koreksi data**, TETAPI (sesuai instruksi) **tidak diusulkan di sini** — menunggu keputusan setelah root cause disepakati.

## 6. REKOMENDASI PERBAIKAN SISTEM (ada bug)
1. **BUG-1 (utama): form/proses BTB tidak menyimpan `tstok2.produk_id`.** Bukti: 0 dari 81 BTB Jan-Feb punya produk valid. → perbaiki entri/simpan BTB agar `produk_id` wajib terisi (validasi non-null sebelum commit) supaya stok bergerak.
2. **BUG-2: BTB valuta asing — `tstok2.NETTO`/`HPP` tidak dikonversi ke IDR** (GL sudah IDR = valas×kurs). → konversi nilai stok dengan `KURS` saat CURR_ID<>'IDR' agar valuasi stok = GL.
3. **BUG-3 (data): TL.203.0504** qty naik tanpa pembelian — telusur sumber qty (mutasi/adjustment/input) & koreksi qty; selaras isu terdokumentasi sebelumnya.
4. **Governance:** tambahkan validasi closing bulanan **GL movement vs stock movement per akun** (selisih>Rp1 → warning) agar defect BTB tertangkap saat input, bukan pasca-refresh.

## 7. BELUM TUNTAS (read-only lanjutan bila diminta)
- Netting per-voucher 102-103/110 (residu ≤Rp2,2jt).
- 102-101 dekomposisi penuh modul AS(cons)/EX(freight).
- RC-3 sumber 21.030 unit TL.203.0504 (mutasi/adjustment).

**Recovery opening 2026 = CLOSED. Laporan ini murni audit movement 2026, read-only, tanpa koreksi.**
