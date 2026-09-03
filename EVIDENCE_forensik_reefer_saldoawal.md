# FORENSIK — Divergence SINV vs GL persediaan reefer (102-001), gap ~Rp15,5 M

Investigasi read-only, prod vspnew (103.233.89.43), 2026-07-31. Tanpa jurnal/patch. Tujuan: temukan & buktikan akar penyebab.

## RINGKAS AKAR PENYEBAB (terbukti)
**Divergence = SATU peristiwa di titik pergantian tahun 2025→2026: entri SALDO AWAL SINV 2026-01-01 yang menggelembung Rp 15.495.112.972 di atas nilai transaksi-konsisten. GL mengikuti transaksi dengan benar (cocok sampai Rp 0,34). Alur transaksi bulanan 2024–2025 100% konsisten (23 bulan berturut).**
- Klasifikasi: **B — GL benar, SINV (saldo awal) salah** (dengan elemen C: divergence disuntik out-of-chain, bukan bug alur bulanan).
- Sumber tulisan: **BUKAN** refresh bulanan (konsisten), **BUKAN** oto-minus/`sinv_minus` (isinya 2026-07, kecil), **BUKAN** logika replace NVO (itu menghasilkan nilai transaksi-konsisten = GL). ⇒ **tulisan langsung ke sinv 2026-01-01 di luar rantai** — paling konsisten dengan **Stock Opname (`w_closing_stok`) / entri saldo awal 2026 manual** yang menghitung unit konsinyasi (WIP-Out outstanding) sebagai stok on-hand.

---

# STOK TR.038A (penyumbang terbesar: Rp 8,90 M dari 15,5 M)

## Timeline (SINV bulanan, kunci)
```
2024-01 .. 2025-11 : rekonsiliasi sinv[bln+1] = sinv[bln] + beli + consin − consout − jual  => DIVERG = 0 (SEMUA 23 bulan)
2025-12-01  qty=14  (= closing Nov, transaksi-konsisten)
   Des 2025: beli 12, consin(WIP-In) 15, consout(WIP-Out) 17, jual 15  => net −5  => expected closing = 9
2026-01-01  qty=45  (AKTUAL)   <-- seharusnya 9. Selisih +36 unit.
2026-02-01  qty=6   (= 9 + net Jan −3)  <-- kembali konsisten ke basis 9, BUKAN 45
```

## Divergence pertama
| Field | Nilai |
|---|---|
| Tanggal | **2026-01-01** (pergantian tahun 2025→2026) |
| Objek | saldo awal SINV `TR.038A` periode 2026-01-01 |
| Fungsi | penulisan saldo awal di luar rantai refresh (kandidat: `w_closing_stok` Stock Opname / entri saldo awal manual) — BUKAN `n_cst_closing_stock` refresh bulanan |
| Qty | expected **9** (transaksi) vs aktual **45** → **+36 unit** |
| Nilai | +36 × 247.123.579,07 = **+8.896.448.846,52** |
| GL sebelum/sesudah | GL 102-001 saldo awal 2026 = 12,99 M = **nilai transaksi-konsisten** (tak ikut menggelembung) |
| SINV sebelum/sesudah | rantai transaksi = 9; ditimpa jadi 45 |
| Kesimpulan | SINV saldo awal 2026 di-set 45 (memasukkan ~36 unit konsinyasi/WIP-Out outstanding sebagai stok), GL tetap 9-ekuivalen. Divergence murni di sisi SINV opening. |

---

## Tabel penyumbang (per stok, 102-001) — inflasi saldo awal 2026
| Stok | sinv Des | net Des | exp Jan (txn) | sinv Jan (aktual) | gap qty | gap nilai |
|---|--:|--:|--:|--:|--:|--:|
| TR.038A | 14 | −5 | 9 | 45 | +36 | 8.896.448.846,52 |
| TR.039A | 0 | +13 | 13 | 31 | +18 | 3.801.723.211,44 |
| TR.1006A | 28 | −10 | 18 | 42 | +24 | 950.063.916,96 |
| TR.040A | 7 | +2 | 9 | 13 | +4 | 807.661.680,76 |
| TR.910A | 35 | −7 | 28 | 51 | +23 | 624.799.360,80 |
| TR.1004A | 26 | −9 | 17 | 23 | +6 | 212.034.303,54 |
| TR.1007A | 11 | −6 | 5 | 9 | +4 | 202.381.652,08 |
| **TOTAL** | | | | | | **15.495.112.972,10** |

**Total inflasi = Rp 15.495.112.972 = 100% gap 102-001** (GL 12.999.133.239 vs sinv 28.494.246.211).

## Bukti arah (siapa yang benar) — cocok sampai rupiah
```
Nilai transaksi-konsisten 102-001 = 12.999.133.239,28
GL saldo awal 2026        102-001 = 12.999.133.239,62   (selisih −0,34 = NOL)
sinv saldo awal 2026 (aktual)     = 28.494.246.211,38   (inflasi +15.495.112.972,10)
```
⇒ **GL = alur transaksi (benar). SINV saldo awal 2026 = alur transaksi + inflasi (salah).**

## Yang SUDAH disingkirkan (bukan penyebab)
- ❌ Refresh bulanan / closing NVO: 23 bulan DIVERG=0 (konsisten).
- ❌ Double-count `CONSIN`+`CONSIN_BY_EVAP` & `JUAL`+`JUAL_BY_EVAP` di `dw_refresh_stok`: saling meniadakan (WIP-In di-generate dari tiap jual) → tak menimbulkan gap.
- ❌ Oto-minus / `sinv_minus`: entri hanya 2026-07-01, kecil (−3 dst), bukan year-end.
- ❌ Logika replace saldo awal NVO: menghasilkan nilai transaksi-konsisten (= GL).
- ❌ Transaksi hilang / posting hilang di GL: GL cocok transaksi sampai Rp 0,34.

## Klasifikasi root cause
| Stok | Penyebab | Nilai | Root Cause |
|---|---|--:|---|
| TR.038A/039A/040A/1006A/910A/1004A/1007A | Inflasi saldo awal SINV 2026-01-01 (unit konsinyasi dihitung on-hand) | 15.495.112.972 | **data/opening SINV** (entri saldo awal out-of-chain) — bukan bug alur, bukan GL |

Kelompok: **posting hilang** = tidak; **bug engine (alur)** = tidak; **data korup/entri saldo awal** = YA (SINV opening 2026); **transaksi manual/opname** = kandidat sumber; **belum diketahui** = identitas persis voucher opname (sinv tak ber-audit-trail).

## Karakter +36 (diuji): angka HANTU, bukan konsinyasi outstanding
Diuji kumulatif TR.038A s.d 2025-12-31: WIP-Out=532, Jual=598, WIP-In=530 → WIP-Out−Jual = **−66**, WIP-Out−WIP-In = **2**. **Tak satu pun = +36.** Artinya +36 **tidak** berkorelasi dengan besaran transaksi mana pun (bukan unit konsinyasi outstanding, bukan WIP outstanding). ⇒ inflasi saldo awal 2026 adalah **entri keliru tanpa dasar transaksi** (kesalahan Stock Opname / entri saldo awal manual year-end), **bukan** realita fisik yang belum tercatat.

## PROOF DECISIVE — engine menghitung 9, BUKAN 45 (mengeliminasi refresh sebagai penulis)
SQL `retrieve` asli `dw_refresh_stok.srd` diekstrak (9708 char) & dijalankan langsung untuk periode Des 2025 (`arg_tgl='2025-12-01'`, `arg_tgl2='2025-12-31'`), filter TR.038A:
```
AWAL=14  BELI=12  JUAL=0  JUAL_BY_EVAP=15  CONSOUT=17  CONSIN=15  CONSIN_BY_EVAP=0  ==> AKHIR = 9.00
```
- Double-count `CONSIN/CONSIN_BY_EVAP` & `JUAL/JUAL_BY_EVAP` **ter-partisi di praktik** (JUAL=0, CONSIN_BY_EVAP=0) → tak menimbulkan inflasi.
- **Engine (dw_refresh_stok → NVO closing, DAN w_closing_stok yang memakai dw_view=dw_refresh_stok) menghasilkan 9.** Maka nilai 45 **tidak mungkin** ditulis oleh perhitungan engine.

## Penulis nilai 45 (First Point of Divergence — analisis)
| Kandidat | Status |
|---|---|
| Refresh bulanan / NVO closing | **ELIMINATED** (hitung 9; SQL-proof di atas) — HIGH |
| w_closing_stok Stock Opname (mode hitung) | ELIMINATED (pakai dw_refresh_stok yang sama → 9) |
| **w_closing_stok Stock Opname (entri FISIK manual)** — override qty via `dw_sinv_update`(d_sinv) | **KANDIDAT** — satu-satunya jalur yang bisa meng-override hasil hitung dengan angka fisik manual |
| UPDATE sinv manual (SQL langsung) | KANDIDAT |
| Transaksi adjustment/opname (tstok) | ELIMINATED — tak ada tipe adjustment TR.038A di Des2025/Jan2026 (hanya 02/05/88); +36 bukan dari transaksi |

**Fungsi/Source penulis EKSAK: BELUM TERBUKTI** (tak ada audit-trail pada `sinv`; kandidat = entri fisik Stock Opname `w_closing_stok` atau UPDATE manual). Yang TERBUKTI (HIGH): refresh engine BUKAN penulisnya (menghitung 9), dan +36 adalah override out-of-chain tanpa dasar transaksi.

## AUDIT TAHAP AKHIR — matriks 4 pertanyaan
| # | Pertanyaan | Status | Bukti | Confidence |
|---|---|---|---|---|
| Q1 | Opening SINV 2026 dari proses aplikasi resmi (versi kini)? | **TERBANTAH** | Call-graph 6 penulis sinv (NVO, w_closing_stok, w_closing_harian, w_posting_stok, w_refresh_hppstok, w_trace_stok). SQL `dw_refresh_stok` dijalankan Des-2025 → AKHIR=9 (semua stok). w_closing_stok aktif L575/L628/L680-697 menulis `dw_view.object.akhir` (=9); kode entri-fisik manual L263-417 **ter-comment mati**. ⇒ tak ada proses kini yang menghasilkan 45 | TINGGI |
| Q2 | Override sengaja? Siapa? | **BELUM TERBUKTI** (tidak dapat dibuktikan) | USER_LOG = 6 baris (semua Jul-2026); refresh_jurnal_log = 34 baris (semua Jul-2026). **Tak ada cakupan Des-2025/Jan-2026.** Tak ada log/parameter/temp/script year-end | — |
| Q3 | Kenapa 9→45, 13→31, dst? Pola? | **BELUM TERBUKTI** | Delta (36,18,4,24,23,6,4) TAK = serial WIP-Out (532/265/16/757/225/601/106), TAK = konsinyasi outstanding (2,2,1,2,6,0,3), TAK = WIP-In-missing (0), TAK = kelipatan engine. Tak terderivasi dari metrik transaksi mana pun | TINGGI (bahwa TAK ada pola transaksi) |
| Q4 | Seluruh gap dari SATU event? | **TERBUKTI (periode tunggal)**; identitas transaksi-tulis tunggal BELUM TERBUKTI | Semua reefer: DIVERG Nov→Des = **0**, DIVERG Des→Jan = gap. Putus serentak **hanya** di periode 2026-01-01 | TINGGI (titik tunggal) |

## Klasifikasi final (+ total nilai)
| Kelompok | Nilai | Dasar |
|---|--:|---|
| Bug engine (kini) | Rp 0 | dw_refresh_stok & NVO hitung 9 (benar) |
| Bug historis | tak dapat dibuktikan | mungkin versi kode lama, tapi tak ada bukti |
| Posting GL hilang | Rp 0 | GL = transaksi Rp 0,34 |
| Manual correction / Stock Opname resmi | tak dapat ditelusuri ke proses resmi (semua proses kini hitung 9) & tak ada audit | |
| **Data anomaly / manual intervention** (SINV opening 2026-01-01) | **Rp 15.495.112.972** | override tak-tertelusur, tanpa dasar transaksi, single periode |
| Belum terbukti | identitas & niat penulis (siapa/kapan/kenapa) | tak ada audit trail |

**Per aturan Bapak:** karena override **tidak dapat ditelusuri ke proses resmi mana pun** (semua proses aplikasi kini menghitung 9) **dan** tak ada audit trail → diklasifikasikan **DATA ANOMALY / MANUAL INTERVENTION** pada SINV opening 2026-01-01. **BUKAN** bug engine kini (engine terbukti benar). Identitas & niat penulis = **tidak dapat dibuktikan**.

## Kesimpulan akhir (terbukti)
1. **GL benar** (mengikuti transaksi, cocok Rp 0,34). **SINV saldo awal 2026 salah** (menggelembung Rp 15.495.112.972).
2. Divergence = **satu peristiwa** di 2026-01-01 (out-of-chain), **bukan** akumulasi bug bulanan, **bukan** posting GL hilang.
3. Perubahan untuk menutup gap **cukup di sisi SINV saldo awal 2026** (2026-only, tak menyentuh transaksi 2025 maupun GL): turunkan sinv 2026-01-01 ke nilai transaksi-konsisten (= GL). TAPI **belum dieksekusi** — menunggu keputusan Bapak setelah bukti ini, dan idealnya 1 konfirmasi fisik cepat (apakah benar hanya ~9 unit TR.038A on-hand, bukan 45).
