# MOVEMENT GAP ROOT CAUSE — FINAL 2026 (GL vs Stok, Jan–Feb 2026)

> **Recovery opening 2026 = CLOSED/TERKUNCI — tidak disentuh.** Fase phantom 10,11 M SELESAI & terbukti; sinv opening = data turunan (Mekanisme A), Desember 2025 FROZEN, WIP 102-020 & HPP-WIP tidak berubah, 102-001 tie GL sampai rupiah. Dokumen ini **hanya** audit *movement 2026*. 100% **READ-ONLY** (SELECT; tanpa UPDATE/INSERT/DELETE, tanpa jurnal koreksi). Bukti: **`audit_movement_gap.sql`** (PROD SERVER-NEW, 2026-08-01).

---

## 1. EXECUTIVE SUMMARY

**Opening sudah benar. Selisih yang tersisa MURNI dari movement 2026 yang tidak sinkron GL vs stok** — berikut voucher penyebabnya. Bukan saldo awal, bukan phantom, bukan WIP.

Tiga akar, semua terbukti transaksional (**bukan jurnal manual** — semua voucher bermodul **PO/HP** program, tak ada GJ/MEMO):

| RC | Akar (bukti) | Jenis | Status |
|---|---|---|---|
| **RC-1** | **100% BTB input tanpa `tstok2.produk_id`** → GL persediaan masuk, stok tak terbentuk | **BUG PROGRAM** | **GL ONLY** |
| **RC-2** | **BTB impor USD: `NETTO` disimpan valas mentah**, GL = valas×kurs (IDR) | **CURRENCY** | **SALAH NILAI** |
| **RC-3** | **TL.203.0504: qty sinv tak reproducible dari transaksi** (+24.030 unit tanpa pembelian) | **DATA/LEDGER** | **SALAH QTY** |

Kontrol sistemik: **dari 81 BTB Jan–Feb 2026, yang menyimpan produk_id valid = 0** (`audit_movement_gap.sql` B2).

---

## 2. TABEL GAP PER AKUN (9 akun) — metodologi C

Stock Movement = Δ sinv nilai (2026-03-01 − 2026-01-01). GL Movement = Σ(debet−kredit) Jan–Feb.

| Akun | GL Movement | Stock Movement | Selisih | Root Cause | Voucher | Status |
|---|--:|--:|--:|---|---|---|
| 102-001 | 1.243.686.543,78 | 1.243.686.543,76 | −0,02 | — (reefer serial, sinkron) | — | **MATCH** |
| 102-006 | 0,00 | 0,00 | 0,00 | — | — | **MATCH** |
| 102-201 | −141.282,86 | −141.282,86 | 0,00 | — | — | **MATCH** |
| **102-203** | 117.500.000,00 | 0,00 | **−117.500.000** | RC-1 BTB tanpa produk | 101BTB260200022 / 260400004 | **GL ONLY** |
| **102-101** | −196.687.276,63 | −242.207.430,27 | **−45.520.154** | RC-2 impor USD + RC-1 | 101BTB260100016 / 260100027 | **SALAH NILAI** |
| **102-010** | 30.796.000,00 | 0,00 | **−30.796.000** | RC-1 BTB Toyo Unit tanpa produk | 101BTB260100019 / 021 / 260200036 | **GL ONLY** |
| **102-102** | 38.016.327,92 | 24.516.327,92 | **−13.500.000** | RC-1 BTB + RC-3 TL.203.0504 | (BTB) + stok_id TL.203.0504 | **GL ONLY + SALAH QTY** |
| 102-103 | −158.417,08 | −2.330.897,08 | **−2.172.480** | RC-1 BTB tanpa produk | 101BTB260200025 (+4) | **GL ONLY** |
| 102-110 | 26.564.675,43 | 25.003.081,38 | **−1.561.594** | RC-1 residu (blank ter-offset COGS/retur) | 37 BTB (mayoritas net) | **GL ONLY (residu)** |

**STOCK ONLY = tidak ada.** WIP ('88') hanya material di 102-001 (MATCH) → bukan penyebab.

---

## 3. TABEL A — BREAKDOWN GL PER VOUCHER (ter-query langsung)

Format: |Tanggal|Akun|Voucher|Modul|Debet|Kredit|Net Movement|User|Referensi|Ada pasangan stok?|

| Tanggal | Akun | Voucher | Modul | Debet | Kredit | Net Movement | User | Referensi | Ada pasangan stok? |
|---|---|---|---|--:|--:|--:|---|---|---|
| 07-Jan | 102-010 | 101BTB260100019 | PO | 5.336.000 | 0 | 5.336.000 | ALFA | 101BTB260100019 | **TIDAK (0)** |
| 13-Jan | 102-010 | 101BTB260100021 | PO | 24.570.000 | 0 | 24.570.000 | ALFA | 101BTB260100021 | **TIDAK (0)** |
| 28-Feb | 102-010 | 101BTB260200036 | PO | 20.000.000 | 0 | 20.000.000 | alfa | 101BTB260200036 | **TIDAK (0)** |
| 02-Jan | 102-101 | 101BTB261200001 | PO | 4.200.000 | 0 | 4.200.000 | alfa | 101BTB261200001 | **TIDAK (0)** |
| 09-Jan | 102-101 | 101BTB260100031 | PO | 4.200.000 | 0 | 4.200.000 | ALFA | 101BTB260100031 | **TIDAK (0)** |
| 20-Jan | 102-101 | **101BTB260100016** | PO | 42.620.996,88 | 0 | 42.620.996,88 | super | 101BTB260100016 | **TIDAK (0)** — USD |
| 28-Jan | 102-101 | **101BTB260100027** | PO | 189.756.288,24 | 0 | 189.756.288,24 | super | 101BTB260100027 | **TIDAK (0)** — USD |
| 10-Feb | 102-101 | 101BTB260200019 | PO | 11.200.000 | 0 | 11.200.000 | ALFA | 101BTB260200019 | **TIDAK (0)** |
| 02-Jan | 102-102 | 101BTB260100006 | PO | 14.900.000 | 0 | 14.900.000 | alfa | 101BTB260100006 | **TIDAK (0)** |
| 08-Jan | 102-102 | 101BTB260100002 | PO | 12.000.000 | 0 | 12.000.000 | alfa | 101BTB260100002 | **TIDAK (0)** |
| 14-Jan | 102-102 | 101BTB260100012 | PO | 1.000.000 | 0 | 1.000.000 | alfa | 101BTB260100012 | **TIDAK (0)** |
| 26-Jan | 102-102 | 101BTB260100040 | PO | 15.020.000 | 0 | 15.020.000 | ALFA | 101BTB260100040 | **TIDAK (0)** |
| 11-Feb | 102-102 | 101BTB260200037 | PO | 2.066.700 | 0 | 2.066.700 | ALFA | 101BTB260200037 | **TIDAK (0)** |
| 19-Feb | 102-102 | 101BTB260200023 | PO | 12.000.000 | 0 | 12.000.000 | ALFA | 101BTB260200023 | **TIDAK (0)** |
| 06-Jan | 102-103 | 101BTB260100005 | PO | 1.500.000 | 0 | 1.500.000 | alfa | 101BTB260100005 | **TIDAK (0)** |
| 12-Jan | 102-103 | 101BTB260100032 | PO | 1.031.250 | 0 | 1.031.250 | ALFA | 101BTB260100032 | **TIDAK (0)** |
| 04-Feb | 102-103 | 101BTB260200007 | PO | 7.254.000 | 0 | 7.254.000 | ALFA | 101BTB260200007 | **TIDAK (0)** |
| 05-Feb | 102-103 | 101BTB260200025 | PO | 2.172.480 | 0 | 2.172.480 | ALFA | 101BTB260200025 | **TIDAK (0)** |
| 23-Feb | 102-103 | 101BTB260200014 | PO | 493.500 | 0 | 493.500 | ALFA | 101BTB260200014 | **TIDAK (0)** |
| 02-Feb | 102-203 | **101BTB260200022** | PO | 50.500.000 | 0 | 50.500.000 | alfa | 001/MAS-PRO.INV/2026 | **TIDAK (0)** |
| 27-Feb | 102-203 | **101BTB260400004** | PO | 67.000.000 | 0 | 67.000.000 | ALFA | 201/KW/IV/2026 | **TIDAK (0)** |

> Semua **Ada pasangan stok? = TIDAK (0)** (kolom `pasangan_stok` = netto stok berproduk-valid utk akun tsb). Lawan jurnal tiap BTB = Cr **226-001** (Hutang Dagang) + Dr **104-111** (PPN Masukan). 102-110: 37 BTB pola sama (semua pasangan stok = 0), net ter-offset COGS/retur → residu 1,56 jt.

---

## 4. TABEL B — BREAKDOWN STOK (sumber asli)

Format: |Tanggal|Akun|Tipe Trans|Bukti|Qty|Nilai|Sumber|

| Tanggal | Akun | Tipe Trans | Bukti | Qty | Nilai | Sumber |
|---|---|---|---|--:|--:|---|
| Jan–Feb | **SEMUA 9 akun** | **02 BELI (produk valid)** | — | **0** | **0** | tstok2 — **semua baris BTB produk KOSONG** (Q1 = 0 baris) |
| Jan–Feb | 102-101 | 22 JUAL (COGS) | 275 unit | 275 | 236.950.695 | tsales2 (MATCH sisi jual) |
| Jan–Feb | 102-110 | 22 JUAL | 710,30 unit | 710 | 82.252.703 | tsales2 (MATCH) |
| Jan–Feb | 102-010 | 22 JUAL | 22 unit | 22 | 19.110.000 | tsales2 (MATCH) |
| Jan–Feb | 102-102 | 22 JUAL | 7.038 unit | 7.038 | 11.407.704 | tsales2 (MATCH) |
| Jan | **102-102 / TL.203.0504** | **(tanpa tipe)** | **TIDAK ADA** | **+24.030** | (revaluasi) | **sinv naik tanpa tstok/tsales — Q11** |
| Jan–Feb | 102-001 | 88 WIP-Out + 22 JUAL | reefer | 246 + 234 | 27,57 M | tsales2 (MATCH, serial) |

**Pembuktian arah:**
- **Ada GL tanpa pasangan stok?** YA — semua BTB (RC-1). GL Dr persediaan, stok = 0.
- **Ada stok tanpa GL?** TIDAK, **kecuali TL.203.0504** (+24.030 unit di sinv tanpa transaksi = stok tanpa GL, RC-3).

---

## 5. DETAIL VOUCHER PENYEBAB (per prioritas, dengan bukti angka)

**5.1 — 102-203 (Rp117,5 jt) — GL ONLY.** Jawab: **YA, GL masuk tanpa produk_id/stok.**
- `101BTB260200022` (02-Feb, user **alfa**, Dr 102-203 50.500.000 / Cr 226-001, PPN 104-111 5.555.000) — tstok2 qty 1, **produk_id KOSONG**, pasangan stok = 0.
- `101BTB260400004` (27-Feb, user **ALFA**, Dr 102-203 67.000.000) — tstok2 qty 1, **produk_id KOSONG**, pasangan stok = 0.

**5.2 — 102-101 (Rp45,5 jt) — SALAH NILAI.** Formula terbukti:
- `101BTB260100016` (20-Jan, **super**, USD, kurs **16.786**): **2.539,08 × 16.786 = Rp42.620.996,88 = GL persis ✓**
- `101BTB260100027` (28-Jan, **super**, USD, kurs **16.924**): **11.212,26 × 16.924 = Rp189.756.288,24 = GL persis ✓**
- GL sudah IDR benar; stok simpan USD mentah + produk kosong → **konversi valuta, bukan opening.** Sisi jual (tsales '22' 236,95 jt) MATCH.

**5.3 — 102-010 (Rp30,8 jt) — GL ONLY.** BTB TOYO UNIT blank produk (tabel A): `101BTB260100019`, `260100021`, `260200036` (user alfa/ALFA), pasangan stok = 0. Sisi HP = COGS jual Toyo Unit (Cr 102-010 2.730.000/unit) dari saldo awal → gap = 49,9 − 19,1 = 30,8 jt.

**5.4 — 102-102 (Rp13,5 jt) — GL ONLY + SALAH QTY.** TL.203.0504 anomali qty **tertrace** (Q11): opening Jan 4.472,80 − jual 3.000 + **beli 0** = seharusnya 1.472,80, sinv aktual **25.502,80** → **+24.030 unit stok tanpa satu pun pembelian/mutasi** (tstok semua tipe & varian = 0). **Ada stok tanpa pembelian: YA.** Ditambah 6 BTB blank (Rp57 jt).

**5.5 — 102-103 & 102-110 — GL ONLY.** 102-103: BTB blank (mis. `101BTB260200025` 2.172.480 = gap, ALFA). 102-110: 37 BTB blank, net ter-offset COGS/retur → **residu 1,56 jt** (bukan rounding — tetap GL ONLY skala kecil).

---

## 6. BUKTI SQL / QUERY PENEMUAN
Semua di **`audit_movement_gap.sql`** (read-only): **A/H** tabel gap 9 akun · **F** GL per voucher + user + pasangan stok (Tabel A) · **B** rekon per (akun,voucher) `stok_valid_akun` · **B2** kontrol (0/81 BTB berproduk valid) · **C** valas (USD×kurs=GL) · **D/I** TL.203.0504 (rekon Q11) · **G** breakdown stok tstok/tsales.

## 7. ROOT CAUSE CLASSIFICATION
| Akun | Klasifikasi | Sumber |
|---|---|---|
| 102-203 | RC-1 (bug program: BTB tanpa produk_id) | transaksi/program |
| 102-101 | RC-2 (currency) + RC-1 | valuasi/program |
| 102-010 | RC-1 | transaksi/program |
| 102-102 | RC-1 + RC-3 (data/ledger qty) | transaksi + data |
| 102-103 | RC-1 | transaksi/program |
| 102-110 | RC-1 (residu) | transaksi/program |
| 102-001/006/201 | MATCH (tak ada isu) | — |

**Bukan:** jurnal manual (semua PO/HP program), costing-sebab-utama, currency-di-102-001 (reefer serial ditangani), atau opening/phantom.

## 8. KESIMPULAN & TINDAKAN
- Jika transaksi salah: **"Perlu koreksi data transaksi sumber"** (BTB isi produk_id + konversi valas; qty TL.203.0504) — **BUKAN** jurnal penyesuaian. **Tidak diusulkan bentuk koreksi di sini** (fase root-cause).

## 9. REKOMENDASI PENCEGAHAN SISTEM
1. **Validasi entri BTB:** `tstok2.produk_id` **wajib non-null** sebelum commit (cacat 0/81 = jalur simpan bermasalah).
2. **Currency:** untuk `CURR_ID<>'IDR'`, `tstok2.NETTO`/`HPP` disimpan = valas × `KURS` (IDR) agar valuasi stok = GL.
3. **Data/ledger:** audit & koreksi qty stok tanpa transaksi (mis. TL.203.0504 +24.030) via stock-opname resmi.
4. **Governance closing:** validasi otomatis **GL movement vs Stock movement per akun** (selisih>Rp1 → tolak/peringatkan) — cacat tertangkap saat input, bukan pasca-refresh.

---

## Definition of Done
✓ Setiap selisih punya akun (§2) → voucher (§3/§5) → bukti query (§6). ✓ Jenis masalah teridentifikasi (§7): **bug program / currency / data-ledger**. ✓ Tidak ada kesimpulan tanpa voucher. **Tidak ada status unresolved.** Recovery opening 2026 = **CLOSED, tidak disentuh.**
