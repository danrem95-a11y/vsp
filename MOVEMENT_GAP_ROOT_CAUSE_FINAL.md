# MOVEMENT GAP ROOT CAUSE — FINAL (GL vs Stok, Jan–Feb 2026, PROD SERVER-NEW)

> Recovery opening 2026 = **CLOSED/TERKUNCI, tidak disentuh**. Dokumen ini **hanya** audit *movement* Jan–Feb 2026. 100% **READ-ONLY** (SELECT saja; tanpa UPDATE/INSERT/DELETE, tanpa jurnal koreksi). Tiap kesimpulan disertai **nomor voucher + bukti query** (`audit_movement_gap.sql`). Tanggal audit: 2026-08-01.

---

## 1. EXECUTIVE SUMMARY

Selisih movement 2026 (opening sudah balance) berasal dari **3 akar terbukti transaksional**, semuanya di sisi **input transaksi/valuasi**, **BUKAN jurnal manual** (semua voucher bermodul **PO/HP** yang digenerate program, bukan GJ/MEMO):

| RC | Akar (bukti) | Jenis masalah | Kategori status |
|---|---|---|---|
| **RC-1** | **100% BTB terima-barang input tanpa `tstok2.produk_id`** → GL persediaan terbukukan, stok tak terbentuk | **BUG PROGRAM** (form BTB tak simpan produk_id) | **GL ONLY** |
| **RC-2** | **BTB impor USD: `tstok2.NETTO` disimpan valas mentah**, GL = valas×kurs (IDR) | **CURRENCY** (konversi tak diterapkan ke stok) | **SALAH NILAI** |
| **RC-3** | **TL.203.0504: qty sinv tak reproducible dari transaksi** (+24.030 unit tanpa pembelian/mutasi) | **DATA/LEDGER INTEGRITY** | **SALAH QTY** |

**Bukti sistemik RC-1:** dari **81 BTB (TIPE='02') Jan–Feb 2026, yang punya produk valid = 0** (`audit_movement_gap.sql` bag. B2). Bukan sporadis → bug proses input.

---

## 2. TABEL MOVEMENT — SELURUH AKUN (bukti: `audit_movement_gap.sql` bag. A / query Q7)

Stock Movement = Δ sinv nilai (closing 2026-03-01 − opening 2026-01-01). GL Movement = Σ(debet−kredit) Jan–Feb.

| Akun | Grup | GL Movement | Stock Movement | Selisih | Status |
|---|---|--:|--:|--:|---|
| 102-001 | TR reefer (serial) | 1.243.686.543,78 | 1.243.686.543,76 | **−0,02** | **MATCH** |
| 102-006 | TB | 0,00 | 0,00 | **0,00** | **MATCH** |
| 102-201 | MT | −141.282,86 | −141.282,86 | **0,00** | **MATCH** |
| **102-203** | BOX FIBERGLASS | 117.500.000,00 | 0,00 | **−117.500.000,00** | **GL ONLY** |
| **102-101** | SPARE PART Thermo King | −196.687.276,63 | −242.207.430,27 | **−45.520.153,64** | **GL ONLY + SALAH NILAI** |
| **102-010** | TOYO UNIT | 30.796.000,00 | 0,00 | **−30.796.000,00** | **GL ONLY** |
| **102-102** | — | 38.016.327,92 | 24.516.327,92 | **−13.500.000,00** | **GL ONLY + SALAH QTY** |
| 102-103 | — | −158.417,08 | −2.330.897,08 | **−2.172.480,00** | **GL ONLY** (residu) |
| 102-110 | L-LOKAL | 26.564.675,43 | 25.003.081,38 | **−1.561.594,05** | GL ONLY (mayoritas MATCH) |

**STOCK ONLY = tidak ada** (tak ada gerakan stok berproduk-valid tanpa GL). **WIP** (tsales/tstok '88') hanya material di **102-001** (reefer, MATCH) — **bukan penyebab** gap ke-6 akun (Q2: tak ada '88' di akun target).

---

## 3. ROOT CAUSE + BUKTI VOUCHER per akun

### 3.1 — 102-203 (GL ONLY, tuntas 100%) — investigasi khusus D.1
GL bertambah 117,5 jt, stok = 0. Kedua BTB **produk_id KOSONG**:

| Tanggal | Akun | Voucher | Modul | Debet | Kredit | User | Referensi | Pasangan Stok | Status |
|---|---|---|---|--:|--:|---|---|--:|---|
| 02-Feb | 102-203 | 101BTB260200022 | PO | 50.500.000 | (226-001) 56.055.000 | alfa | 001/MAS-PRO.INV/2026 | **0** (tstok2 qty 1, produk kosong) | GL ONLY |
| 27-Feb | 102-203 | 101BTB260400004 | PO | 67.000.000 | (226-001) 74.370.000 | ALFA | 201/KW/IV/2026 | **0** (tstok2 qty 1, produk kosong) | GL ONLY |

Kesimpulan: **BTB tanpa produk_id → GL pembelian masuk, stok tidak terbentuk.** Bukan non-stock adjustment (ini terima barang riil). Bukti: `audit_movement_gap.sql` bag. E.

### 3.2 — 102-101 (SALAH NILAI + GL ONLY) — investigasi khusus D.2
2 impor USD (vendor 4SL.0305, Thermo King). **Formula terbukti: USD × kurs = GL (IDR):**

| Tanggal | Akun | Voucher | Modul | GL Dr (IDR) | Stok NETTO (USD) | Kurs | USD×kurs | User | Status |
|---|---|---|---|--:|--:|--:|--:|---|---|
| 20-Jan | 102-101 | 101BTB260100016 | PO | 42.620.996,88 | 2.539,08 | 16.786 | **42.620.996,88 ✓** | super | SALAH NILAI |
| 28-Jan | 102-101 | 101BTB260100027 | PO | 189.756.288,24 | 11.212,26 | 16.924 | **189.756.288,24 ✓** | super | SALAH NILAI |

Kesimpulan: **konversi valuta, BUKAN opening.** GL sudah IDR benar; stok simpan USD mentah (+ produk kosong). Sisa 102-101 = BTB IDR blank (H-TECH/MULIA JAYA/TK) & sisi jual (HP/tsales '22' = 236,95 jt) yang **MATCH**. Bukti: `audit_movement_gap.sql` bag. C.

### 3.3 — 102-010 (GL ONLY) — investigasi khusus D.3
3 BTB TOYO UNIT, produk_id KOSONG:

| Tanggal | Akun | Voucher | Modul | Debet | Kredit | User | Referensi | Pasangan Stok | Status |
|---|---|---|---|--:|--:|---|---|--:|---|
| 07-Jan | 102-010 | 101BTB260100019 | PO | 5.336.000 | (226-001) | alfa | THERMO ASRI MANDIRI 006/FK-TA | **0** | GL ONLY |
| 13-Jan | 102-010 | 101BTB260100021 | PO | 24.570.000 | (226-001) | alfa | THERMO ASRI MANDIRI 010/FK-TA | **0** | GL ONLY |
| 28-Feb | 102-010 | 101BTB260200036 | PO | 20.000.000 | (226-001) | alfa | THERMO ASRI MASYUR TAM/055 | **0** | GL ONLY |

Sisi HP = COGS jual TOYO UNIT (Cr 102-010 2.730.000/unit) dari saldo awal nyata → gap = pembelian blank tak masuk stok (49,9 − 19,1 COGS = 30,8 jt ✓).

### 3.4 — 102-102 / TL.203.0504 (SALAH QTY) — investigasi khusus D.4 (TERTRACE, bukan asumsi)
**Rekonsiliasi engine (query Q11):**

| opening Jan | − jual Jan | + beli Jan | = seharusnya | sinv aktual | selisih tak bersumber |
|--:|--:|--:|--:|--:|--:|
| 4.472,80 | 3.000,00 | **0,00** | **1.472,80** | **25.502,80** | **+24.030,00** |

- **tstok pembelian/mutasi TL.203.0504 (semua tipe, 2026) = 0 baris** (Q6/Q9, termasuk varian `LIKE`).
- **tsales hanya jual '22'** (Jan 3.000, Feb 3.750; tak ada retur/mutasi masuk) (Q5/Q8).
- sinv qty tinggi bertahan sepanjang 2026 (25k–41k) (Q10).

Kesimpulan: **qty sinv TL.203.0504 TIDAK dapat direproduksi dari transaksi** — ada **+24.030 unit di ledger stok tanpa satu pun transaksi pembelian/mutasi**. Jenis: **DATA/LEDGER INTEGRITY** (qty stok di-set di luar jalur transaksi, mis. stock-opname/legacy), bukan pembelian yang hilang. Plus 102-102 punya 6 BTB blank (Rp57 jt, GL ONLY). Bukti: `audit_movement_gap.sql` bag. D.

### 3.5 — 102-103 & 102-110 (GL ONLY, residu kecil)
BTB blank-produk (mis. 102-103 `101BTB260200025` 2.172.480 = gap; 102-110 37 BTB bruto 266 jt ter-offset COGS/retur → gap bersih 1,56 jt). Bukti: `audit_movement_gap.sql` bag. B/F.

---

## 4. TABEL REKONSILIASI PER-VOUCHER (format wajib) — |Tanggal|Akun|GL Movement|Stok Movement|Selisih|Voucher|Status|

| Tanggal | Akun | GL Movement | Stok Movement | Selisih | Voucher | Status |
|---|---|--:|--:|--:|---|---|
| 02-Feb | 102-203 | 50.500.000 | 0 | 50.500.000 | 101BTB260200022 | GL ONLY |
| 27-Feb | 102-203 | 67.000.000 | 0 | 67.000.000 | 101BTB260400004 | GL ONLY |
| 20-Jan | 102-101 | 42.620.997 | 2.539 (USD) | 42.618.458 | 101BTB260100016 | SALAH NILAI |
| 28-Jan | 102-101 | 189.756.288 | 11.212 (USD) | 189.745.076 | 101BTB260100027 | SALAH NILAI |
| 10-Feb | 102-101 | 11.200.000 | 0 | 11.200.000 | 101BTB260200019 | GL ONLY |
| 07-Jan | 102-010 | 5.336.000 | 0 | 5.336.000 | 101BTB260100019 | GL ONLY |
| 13-Jan | 102-010 | 24.570.000 | 0 | 24.570.000 | 101BTB260100021 | GL ONLY |
| 28-Feb | 102-010 | 20.000.000 | 0 | 20.000.000 | 101BTB260200036 | GL ONLY |
| 26-Jan | 102-102 | 15.020.000 | 0 | 15.020.000 | 101BTB260100040 | GL ONLY |
| Jan | 102-102 | — | +24.030 unit tanpa sumber | (SALAH QTY) | stok_id TL.203.0504 | SALAH QTY |
| 05-Feb | 102-103 | 2.172.480 | 0 | 2.172.480 | 101BTB260200025 | GL ONLY |
| Jan-Feb | 102-101/010/102/110 | (HP=COGS jual) | = tsales '22' | 0 | modul HP | MATCH |

---

## 5. BUKTI SQL (query yang menemukan)
Semua di **`audit_movement_gap.sql`** (read-only):
- **A** ringkas gap + GL per modul; **A2/F** GL per voucher (voucher/tgl/account/debet/kredit/modul/ref/**user**/keterangan/pasangan-stok).
- **B** rekon per (akun,voucher) `stok_valid_akun`; **B2** control (BTB produk-valid = 0 dari 81).
- **C** BTB valuta asing (USD×kurs = GL).
- **D** TL.203.0504 (sinv history + tstok=0 + tsales, rekon Q11).
- **G** breakdown stok tstok/tsales per tipe (Q1 tstok valid=0; Q2 tsales).

## 6. PERLU KOREKSI ATAU BUKAN?
**Perlu koreksi data** (BUKAN jurnal non-stock yang benar): semua adalah **terima barang / valuasi / qty** yang seharusnya tercermin di stok. **Tidak diusulkan bentuk koreksinya di sini** (sesuai batasan — koreksi hanya setelah root cause disepakati). Bukan jurnal manual (tak ada voucher GJ/MEMO; semua PO/HP program).

## 7. REKOMENDASI PERMANENT FIX
1. **BUG PROGRAM (utama):** entri BTB **wajib** menyimpan `tstok2.produk_id` — tambahkan validasi *non-null* sebelum commit di form/proses PO-BTB. (0 dari 81 BTB menyimpan produk → cacat di jalur simpan.)
2. **CURRENCY:** untuk `CURR_ID<>'IDR'`, konversi `tstok2.NETTO`/`HPP` × `KURS` saat simpan agar valuasi stok = GL (yang sudah IDR).
3. **DATA/LEDGER:** telusuri & koreksi qty **TL.203.0504** (+24.030 unit tak bersumber) via jalur stock-opname resmi; audit stok lain dengan qty tanpa transaksi.
4. **GOVERNANCE:** validasi tiap closing **GL movement vs stock movement per akun** (Q7); selisih>Rp1 → tolak/peringatkan → cacat tertangkap saat input, bukan pasca-refresh.

---

## Definition of Done — status
- ✓ **Setiap selisih punya akun penyebab** — tabel §2 (9 akun).
- ✓ **Setiap akun punya voucher penyebab** — §3 & §4 (nomor voucher).
- ✓ **Setiap voucher punya bukti query** — §5 (`audit_movement_gap.sql`).
- ✓ **Jenis masalah diketahui:** RC-1 = **bug program + transaksi**; RC-2 = **currency**; RC-3 = **data/ledger integrity**; **bukan** jurnal manual, **bukan** costing-sebab-utama, **bukan** opening.

**Recovery opening 2026 = CLOSED. Audit ini murni movement 2026, read-only, tanpa koreksi.**
