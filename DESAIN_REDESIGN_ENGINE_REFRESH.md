# DESAIN REDESIGN ENGINE REFRESH — HPP WIP-Out *Immutable* & Refresh *Idempotent*

> **⚠️ REVISI FINAL — VARIAN TANPA TABEL (keputusan Pak Wira).** Mekanisme freeze **tidak** lagi memakai tabel `tsales_wipout_freeze` (agar tak menambah objek DB; laporan existing aman). Freeze memakai **guard `ISNULL(tsales2.hpp,0)=0`** (hitung sekali saat kosong, lalu beku). Semua penyebutan "ledger / freeze-ledger / Opsi A / G6/G7/G8 berbasis ledger" di bawah **SUDAH DIGANTIKAN**: integritas '88' kini oleh **G3** (WIP-Out vs basis SINV-awal). Panduan pakai: **`IMPORT_AND_DONE.md`**. Immutability/idempotensi/I8/I9 tetap berlaku (tak bergantung tabel — bergantung guard + R6/R7 OFF + C2/C3 tak menyentuh '88').

**Status:** DESAIN ACC-bersyarat. **FASE 1A + 1B = Build/Verification Candidate** (source + runbook + detektor + acceptance selesai; belum di-build/di-run Pak Wira). **FASE 2** (hapus permanen R6/R7 + flag, di modern **dan** journal) menunggu evidence EC1–EC7 + I8 lulus.
**Scope implementasi:** `n_cst_closing_stock.sru` + `w_refresh_transaksi_modern.srw` + `w_refresh_journal.srw` (FASE 1B, penonaktifan penulis HPP).
**Tanggal:** 2026-07-31.

## Rencana bertahap (revisi atas masukan Pak Wira)
- **FASE 1A** (selesai): C1–C4 di NVO + ledger + acceptance + parallel-run (modern).
- **FASE 1B** (selesai): eliminasi `w_refresh_journal.srw` sebagai penulis HPP (flag `ib_nvo_sole_hpp_authority` → R6/R7 journal OFF) → **I8 tercapai se-sistem**.
- **ACC Produksi**: setelah 1A+1B lulus seluruh acceptance + DETEKTOR G1–G8.
- **FASE 2**: hapus permanen R6/R7 + flag di **modern & journal** (tanpa dead code).

## Artefak FASE 1 (Build Candidate)
| Artefak | Isi |
|---|---|
| `n_cst_closing_stock.sru` (+`.bak_redesign`) | C1a guard + C1b registrasi ledger; C2 NON-WIP; C3 WIP=MAX '88'; C4 WIP-In MAX |
| `w_refresh_transaksi_modern.srw` (+`.bak_redesign`) | flag `ib_nvo_sole_hpp_authority` (SEMENTARA); R6/R7 dibungkus OFF |
| `w_refresh_journal.srw` (+`.bak_redesign`) | **FASE 1B** — flag sama; R6/R7-journal (L2088/L2529) dibungkus OFF → HPP via NVO |
| `RUNBOOK_create_freeze_ledger.sql` | DDL `tsales_wipout_freeze` (jalan SEBELUM build) |
| `RUNBOOK_cutover_freeze_wipout.sql` | cutover tanpa nol-kan '88'; recovery |
| `RUNBOOK_rollback_fase1.md` | rollback R-A/R-B/R-C + wajib uji non-prod |
| `DETEKTOR_residu_hpp_bulanan.sql` | +G5 (WIP≠WIP-Out), G6 (anti-tamper), G7 (integritas ledger), **G8 (nilai freeze pertama)** |
| `ACCEPTANCE_TEST_fase1.sql` | SIGNATURE checksum + T5/T6 |
| `ACCEPTANCE_crossperiod.sql` | uji lintas-periode: refresh Jul → Jan tetap, jual Jul = WIP-Out Jan |
| `ACCEPTANCE_journal_authority.sql` | **I8** — refresh via journal ≡ NVO (bukan otoritas kedua) |
| `PARALLELRUN_classify.sql` | diff per-baris: UNCHANGED / EXPECTED / UNEXPECTED |
| `EVIDENCE_source_search_hpp_writers.md` | bukti pencarian source: semua penulis `tsales2.hpp` terklasifikasi |

**Cleanup FASE 2 (wajib):** hapus permanen blok R6 & R7 **dan** instance var `ib_nvo_sole_hpp_authority` di **modern & journal** — jangan tinggalkan dead code/flag permanen. (Menu di luar refresh — Stock Opname/Posting — di luar cakupan I8 "engine refresh"; dijaga G6, bisa jadi pekerjaan lanjutan terpisah.)

---

## 0. Ringkasan Eksekutif (1 paragraf)

Penyakit inti: **HPP satu baris penjualan/WIP-Out ditulis oleh 5–6 penulis yang saling bersaing di setiap refresh**, dan sebagian penulis memakai *moving-average* yang nilainya bergantung pada saldo penutup bulan sebelumnya. Karena itu (a) nilai final bergantung urutan eksekusi, (b) me-refresh bulan sebelumnya menggeser basis bulan berikutnya, sehingga (c) angka baru "settle" setelah beberapa kali putaran. Obatnya **bukan** menambah patch, melainkan menjadikan **HPP WIP-Out beku (immutable): dihitung sekali saat pertama, lalu dikunci**, dan menetapkan **satu sumber kebenaran tunggal** (NVO closing) yang: NON-WIP → average, WIP → baca nilai WIP-Out beku (lintas-bulan). Semua penulis yang bersaing dihapus. Hasilnya: satu kali refresh Jan→Des langsung benar, dan menjalankannya 1× = 10× (idempotent).

---

## 0.1 BUSINESS INVARIANT — KONTRAK SISTEM (WAJIB, mengikat)

> Seluruh perubahan (C1–C6) dinilai terhadap kontrak ini. Bila sebuah perubahan melanggar salah satu invariant, perubahan itu **salah**, apa pun alasan teknisnya.

| # | Invariant |
|---|---|
| **B1** | HPP WIP-Out dihitung **satu kali** pada saat transaksi WIP-Out terjadi (= moving-average awal bulan WIP-Out). |
| **B2** | Setelah tersimpan pada `tsales2.hpp`, nilai tersebut **immutable**. |
| **B3** | Seluruh transaksi yang berasal dari unit WIP **wajib** memakai HPP WIP-Out tersebut. |
| **B4** | Seluruh transaksi yang **bukan** dari unit WIP **wajib** memakai HPP Moving Average. |
| **B5** | Refresh bulan berikutnya **boleh membaca** HPP historis, tetapi **tidak boleh mengubahnya**. |
| **B6** | Refresh harus **idempotent** (menjalankan 1× = 10×, DB identik). |

## 0.2 ATURAN PENJUALAN — ATURAN BISNIS UTAMA (WAJIB)

> Ini aturan inti, bukan sekadar catatan diagram. Diskriminator unit WIP = ada baris WIP-Out ber-`evap` (`evap <> ''`).

```
IF EXISTS WIP-Out untuk unit tsb (baris '88', evap <> '')
THEN
    HPP Penjualan = HPP WIP-Out        // nilai beku, lintas-bulan
ELSE
    HPP Penjualan = HPP Moving Average // avg akhir bulan (existing)
END IF
```

**Tidak boleh** ada satu pun kondisi di mana unit WIP memakai HPP Moving Average.

## 0.3 Arsitektur satu-halaman & System Boundary

### Alur HPP (lahir sekali, dibaca semua)
```
                  +--------------------+
                  |   Moving Average   |
                  +---------+----------+
                            |
                            v
                      WIP-Out ('88')
                      (Freeze Once)              <- dihitung SEKALI, lalu beku
                            |
                            v
                     tsales2.hpp
                  (Single Operational Source)    <- SATU-SATUNYA sumber nilai HPP
                            |
          +-----------------+-----------------+
          |                 |                 |
          v                 v                 v
      WIP-In           Penjualan         CONSOUT/GL
          |                 |                 |
          +-----------------+-----------------+
                            |  (semua membaca nilai yg SAMA)
                            v
                tsales_wipout_freeze
             (State / Audit / Validation)        <- BUKAN sumber HPP
```

### System Boundary — apa yang termasuk "engine refresh" (tempat I8/I9 berlaku)
```
  ┌──────────────  REFRESH ENGINE BOUNDARY  ──────────────┐
  │  Modern Refresh (w_refresh_transaksi_modern)          │
  │  Journal Refresh (w_refresh_journal, deprecated)      │   Single HPP Authority
  │  NVO n_cst_closing_stock  ..............  = NVO       │   = NVO
  │  CONSOUT / posting GL                                 │
  │  tsales_wipout_freeze (ledger: state/audit/validasi)  │
  └───────────────────────────────────────────────────────┘
        DI LUAR boundary — ADMINISTRATIVE TOOLS (external writers):
        - Stock Opname (w_closing_stok)
        - Posting HPP (w_posting_hpp)
        - Recovery utility / script manual / developer
        => bukan bagian refresh engine; dijaga G6 (Tamper Detector).
```
**Kebijakan rilis (keputusan Pak Wira):** refresh ke depan **HANYA** via `w_refresh_transaksi_modern`; `w_refresh_journal` **deprecated / tidak dipakai lagi** (di FASE 1B sudah dinetralkan sbg penulis HPP; SOP di `SOP_refresh_deprecate_journal.md`).

---

## 1. DELIVERABLE 1 — Diagram Dependency Seluruh Engine Refresh

### 1.1 Level orkestrasi (window modern)
`w_refresh_transaksi_modern.srw`, tombol Refresh → baris 3066–3074, **tiap modul dipanggil SEKALI untuk rentang periode** (tanpa loop bulan):

```
         [ Tombol REFRESH — periode [ldt1 .. ldt2] ]
                          |
   +------+------+------+-----+-----+-----+-----+---------+---------+
   |  SO  |  PO  | NON- | EXP |  AR |  AP | ADJ | CONSOUT | CONSIN  |
   |      |      | ITEM |     |     |     |     |         |         |
   +--+---+------+------+-----+-----+-----+-----+----+----+----+----+
      |                                              |         |
      | of_refresh_so()                              |         |
      v                                              |         |
  (A) NVO n_cst_closing_stock.of_run(f_bom(ldt1))    |         |
      = CLOSING STOK + tulis HPP + tulis SINV bln+1  |         |
      |                                              |         |
  (B) UPDATE tsales2 "WIP-Out-first" (baris 1657) ***|         |   <-- penulis bersaing
      |                                              |         |
  (C) loop f_transfer_so() + f_insert_cons_in()      |         |
      = posting GL SO/COGS + bangun WIP-In (tstok88) |         |
                                                     |         |
                              of_refresh_cons_out() -+         |
                                = loop f_transfer_cons(voucher,'OUT')
                                  posting GL 102-020 dari tsales2.hpp '88'
                                                               |
                              of_refresh_cons_in() ------------+
                                = PATCH WIP-IN YATIM  -> f_insert_cons_in()
                                  PATCH HPP WIP-OUT DRIFT (baris 1953) *** <-- penulis bersaing
                                  PATCH GL-CONSIN YATIM
                                  NVO sync sinv (ab_sinv_only=true)
```
`***` = penulis HPP yang bersaing dengan NVO (sumber non-determinisme; dihapus di desain baru).

### 1.2 Level dalam NVO `n_cst_closing_stock.of_run` (dipanggil di SO)

```
 of_run(periode)  [ tgl1 = f_bom, tgl2 = f_eom, next = f_bom bln+1 ]
   |
   S-A  UPDATE TSTOK2 '19' (mutasi keluar)  = SINV avg AWAL bln (tgl1)   [baris 72-85]  idempoten
   |
   S-B  UPDATE TSALES2 '88' WIP-Out (evap)  = SINV avg AWAL bln          [baris 98-109]  << recompute
   |         fallback: HPP WIP-In -> biarkan lama
   |
   S-C  ids_view.retrieve('dw_refresh_stok') -> loop -> tulis SINV bln+1 [baris 118-233]
   |         akhir_rpxx/hppx = mesin MOVING AVERAGE; CONSOUT_RP kurangi nilai '88'*qty
   |         (guard: qty=0 => nilai=0,hpp=0)
   |
   S-D  UPDATE TSALES2 SEMUA sale bln       = SINV avg AKHIR bln (next)  [baris 354-366]  << recompute, TANPA filter evap
   |
   S-E  UPDATE TSALES2 ber-evap (WIP)       = AVG(hpp '88' per stok+evap)[baris 381-397]  << baca '88'
   |
   S-F1 UPDATE TSTOK2 adjustment (non '19') = SINV avg AKHIR bln         [baris 412-428]
   |
   S-F2 UPDATE TSTOK2 WIP-In '88'           = AVG(hpp '88' per stok+evap)[baris 443-464]  << baca '88'
```

### 1.3 Ketergantungan tabel/nilai (siapa membaca apa)

```
   SINV(periode)  --awal-->  S-A, S-B (avg awal bln)        SINV = snapshot moving-average bulanan
        ^                                                    (periode = 1-tiap-bulan)
        |  ditulis S-C (periode bln+1)
        |
   tsales2.hpp('88' WIP-Out)  <== S-B (tulis)  <== S-D (timpa!)  ==> dibaca S-E, S-F2, CONSOUT, drift
        |                                                             ==> dibaca f_insert_cons_in (WIP-In)
   tsales2.hpp('22' jual WIP) <== S-D (timpa avg) <== S-E (koreksi ke '88') <== (B) 1657 <== drift 1953
        |
   tstok2.hpp('88' WIP-In)    <== S-F2, f_insert_cons_in   ==> dibaca dw_rpt_cons, rekon
        |
   gl_journal(102-020)        <== f_transfer_cons  (baca tsales2.hpp '88')
   gl_journal(402 COGS)       <== f_transfer_so    (baca tsales2.hpp '22')
```

**Simpul kritis:** `tsales2.hpp` pada baris `'88'` adalah **akar rantai**. Semua (WIP-In, penjualan, CONSOUT, GL, rekon) bermuara ke sana. Bila akar ini stabil/beku, seluruh hilir stabil. Hari ini akar ini **ditulis-ulang & ditimpa** beberapa kali per refresh → seluruh hilir ikut goyang.

---

## 2. DELIVERABLE 2 — Diagram Alur HPP: unit WIP vs NON-WIP

### 2.1 Diskriminator (kunci aturan bisnis)
> **`ISNULL(tsales2.evap,'') <> ''`  ⟺  unit WIP** (evap = nomor serial EVAP/COND).
> Baris penjualan/WIP tanpa evap = barang reguler NON-WIP.

Diskriminator ini sudah dipakai konsisten di S-E, (B) 1657, drift, dan f_insert_cons_in. Kita jadikan **satu-satunya** aturan cabang.

### 2.2 Alur unit NON-WIP (target: HPP = moving average) — sudah benar, dipertahankan

```
  Beli (tstok '02')                          Jual (tsales '22', evap='')
       |                                            |
       v                                            v
  SINV moving-average  ----(avg akhir bln)---->  HPP jual = SINV avg akhir bln (S-D)
                                                     |
                                                     v
                                          GL COGS 402 = qty * avg   (f_transfer_so)
```

### 2.3 Alur unit WIP — target: HPP jual = HPP WIP-Out BEKU (lintas-bulan)

```
  Bln M: WIP-Out (tsales '88', evap=serial)
       |
       |  (1) hitung SEKALI = moving-average awal bln M  (SINV periode f_bom(M))
       v
  tsales2.hpp['88', serial]  ====== BEKU / IMMUTABLE =========================\
       |                                                                       |
       |  (2) f_insert_cons_in: bangun WIP-In (tstok '88') pakai nilai beku    | dibaca,
       v                                                                       | TAK
  tstok2.hpp['88' WIP-In, coa_id=serial] = nilai beku                          | dihitung
       |                                                                       | ulang
       |  (3) CONSOUT: GL 102-020 = qty * nilai beku (f_transfer_cons)         |
       v                                                                       |
  Bln M+k: Jual serial (tsales '22', evap=serial)                             |
       |                                                                       |
       |  (4) HPP jual = nilai beku dari bln M  <=============================/
       v          (S-E: MAX hpp '88' per stok+evap, LINTAS-BULAN, tanpa filter tgl)
  GL COGS 402 = qty * nilai beku   (walau moving-average bln M+k sudah berbeda)
```

Contoh (sesuai requirement): WIP-Out Serial A Jan HPP 249.707.668 → Jual A Juli → HPP jual = **249.707.668** (bukan avg Juli).

---

## 3. DELIVERABLE 3 — SEMUA lokasi yang me-*recompute* / menulis `tsales2.hpp` (jalur refresh aktif)

| Kode | File | Baris | Menulis | Basis nilai | Kapan | Idempotent? | Masalah |
|---|---|---|---|---|---|---|---|
| **R1** | n_cst_closing_stock.sru | 98–109 | `tsales2.hpp` '88' WIP-Out (evap) | SINV avg **awal** bln → WIP-In → biarkan | tiap refresh SO (NVO S-B) | **TIDAK** (dihitung ulang tiap kali) | tak ada guard beku → nilai bisa berubah bila SINV awal berubah |
| **R2** | n_cst_closing_stock.sru | 354–366 | `tsales2.hpp` **SEMUA** sale bln (termasuk '88' & '22' WIP) | SINV avg **akhir** bln (`:ldt_next`) | tiap refresh SO (NVO S-D) | **TIDAK** | **TANPA filter evap** → menimpa '88' beku & memberi WIP average |
| **R3** | n_cst_closing_stock.sru | 381–397 | `tsales2.hpp` baris ber-evap (WIP) | **AVG**(hpp '88' per stok+evap), lintas-bulan | tiap refresh SO (NVO S-E) | sebagian | benar secara konsep, tapi membaca '88' yang baru saja dirusak R2 |
| **R4** | n_cst_closing_stock.sru | 443–464 | `tstok2.hpp` '88' WIP-In | AVG(hpp '88') | tiap refresh (NVO S-F2) | tergantung '88' | ikut goyang bila '88' goyang |
| **R5** | n_cst_closing_stock.sru | 72–85 | `tstok2` '19' | SINV avg awal | tiap refresh (NVO S-A) | ya (non-sirkular) | — (sudah difix idempoten) |
| **R6** | w_refresh_transaksi_modern.srw | 1656–1726 | `tsales2.hpp` '22/32/26/36/88' | MAX('88' hpp) → **moving-avg** fallback | tiap refresh SO (setelah NVO) | **TIDAK** | penulis bersaing dgn NVO; fallback = average untuk WIP |
| **R7** | w_refresh_transaksi_modern.srw | 1953–2004 (drift) | `tsales2.hpp` '22/32/26/36' evap menyimpang | MAX('88' hpp) | tiap refresh CONSIN | patch reaktif | menambal gejala, bukan akar; bikin hasil bergantung urutan |
| R8 | f_insert_cons_in.srf | 183/366 | `tsales2.hpp` (write-back WIP-In) | tstok2 WIP-In by stok | tiap panggil | **inert di modern** (overload 1-arg, `ls_stok=''` → 0 baris) | jadi bahaya bila overload 4-arg dipakai |

> Ada pula banyak file **non-aktif** yang menulis `tsales2.hpp` (copy/versi lama: `w_refresh_journal*.srw`, `w_closing_stok*.srw`, `w_posting_*.srw`, `w_refresh_hppstok*.srw`, `w_trace_stok.srw`, `n_cst_closing_stock_upd.sru`, `f_insert_cons_in_ori/_original.srf`). **Tidak** di jalur refresh modern; diabaikan untuk redesign ini, tapi *dilarang* dipakai memproses WIP agar tidak menabrak invariant beku.

---

## 4. DELIVERABLE 4 — SEMUA lokasi yang masih memakai HPP Average untuk unit WIP

| Kode | Lokasi | Bagaimana average bocor ke WIP |
|---|---|---|
| **R2** | NVO S-D, baris 354–366 | Set **semua** baris sale bulan itu = SINV avg akhir bln **tanpa mengecualikan evap** → baris '88' & '22' WIP ikut jadi average (transien, sebelum R3 mengoreksi). Inilah sumber utama "WIP pakai average". |
| **R6** | modern 1657, cabang fallback | `ISNULL( MAX('88' hpp) , (rumus moving-average) )` → bila pasangan '88' belum beku / lintas-bulan belum di-refresh, WIP jatuh ke **moving-average**. |
| (turunan) | S-E/S-F2 saat membaca '88' yang sudah dirusak R2 | Karena '88' sempat ditimpa average oleh R2, AVG yang dibaca S-E/S-F2 = average → menyebar ke '22' & WIP-In. |

Setelah redesign, **tidak boleh** ada satu pun jalur di atas: R2 dibatasi `evap=''` (khusus NON-WIP), R6 dihapus.

---

## 5. DELIVERABLE 5 — Mengapa refresh sekarang butuh > 1 kali

1. **Banyak penulis bersaing atas satu sel `tsales2.hpp`.** Dalam satu refresh SO: R1 (avg awal) → R2 (avg akhir, menimpa) → R3 (koreksi ke '88') → R6 (WIP-Out-first / fallback) → lalu R7 drift di modul CONSIN. Nilai final = fungsi **urutan** eksekusi, bukan fungsi data saja. Tidak deterministik terhadap isi DB.

2. **Basis average bergantung bulan sebelumnya.** R2 memakai `SINV periode = akhir bulan`. SINV akhir bulan M = SINV awal bulan M+1. Me-refresh M mengubah penutup M → mengubah basis M+1. Karena '88' **dihitung ulang** (bukan beku), nilai WIP-Out bulan M+1 ikut bergeser **setelah** M di-refresh → M+1 harus di-refresh lagi → efek beruntun Jan→Des baru "settle" setelah beberapa putaran.

3. **WIP lintas-bulan menangkap nilai transisi.** WIP-Out di bln M, jual di bln M+k. Bila saat memproses bln M+k nilai '88' bln M masih dalam kondisi transisi (belum beku / sempat ditimpa R2), maka '22' M+k membeku ke nilai salah; baru benar setelah putaran berikutnya.

4. **Patch reaktif menutupi, bukan menyembuhkan.** R6 dan R7(drift) ada justru untuk "membetulkan lagi" setelah R2 merusak. Selama akar (R2 menimpa '88', '88' tidak beku) masih ada, sistem hanya konvergen secara iteratif — persis gejala "harus bolak-balik refresh".

**Kesimpulan:** non-idempotensi berasal dari **(i) '88' tidak beku** dan **(ii) R2 menimpa '88'/'22' WIP dengan average**, diperparah **(iii) penulis-penulis bersaing**. Ketiganya dihapus di desain baru → cukup 1× jalan, dan 1×=10×.

---

## 6. DELIVERABLE 6 — Desain Baru

### 6.1 Prinsip
1. **Diskriminator tunggal:** `evap<>''` = WIP; `evap=''` = NON-WIP.
2. **Satu sumber kebenaran HPP = NVO `n_cst_closing_stock`.** Tidak ada penulis HPP lain di window refresh.
3. **HPP WIP-Out beku (immutable):** dihitung **sekali** saat pertama, = moving-average **awal bulan** WIP-Out (SINV `f_bom(tgl)`). Sesudah beku, **refresh rutin tidak pernah menghitung ulang**. Nilai immutable **hanya dapat berubah melalui prosedur *administrative recovery* yang eksplisit** (mis. aksi "unfreeze/re-freeze" terarah oleh administrator) — **bukan** melalui refresh bulanan. (Definisi ini menghindari salah tafsir "tidak pernah dihitung ulang" secara mutlak: yang tidak boleh adalah refresh rutin; recovery resmi tetap mungkin & tercatat.)
4. **Penjualan WIP = nilai WIP-Out beku**, dibaca **lintas-bulan** (MAX hpp '88' per stok+evap, tanpa filter tanggal). Tidak pernah average.
5. **Penjualan NON-WIP = moving-average** akhir bulan (aturan existing, dibatasi `evap=''`).
6. **Semua tulis di-scope ke bulan yang di-refresh** (`TGL BETWEEN tgl1 AND tgl2`, SINV `periode=next`). Tidak ada satu pun UPDATE yang menyentuh transaksi/GL bulan lain ⇒ tak ada *backward propagation*.
7. **Self-healing bersifat aditif:** refresh hanya mengisi WIP-Out yang **belum** beku (hpp=0) — mis. WIP-Out baru dientri. Nilai historis yang sudah beku **tidak** disentuh. Nilai historis yang *salah* **tidak** ditimpa otomatis; ia **dideteksi** (DETEKTOR) lalu dikoreksi lewat runbook terarah + aksi "re-freeze" eksplisit — bukan oleh refresh rutin.

### 6.2 Bagaimana tiap requirement dipenuhi

| Requirement | Mekanisme di desain baru |
|---|---|
| Refresh bln X hanya ubah bln X | Semua UPDATE di NVO sudah `TGL BETWEEN tgl1..tgl2` / `periode=next`. Ditegaskan; tak ada tulis ke bulan lain. |
| Boleh baca historis | S-E membaca '88' **semua bulan** (MAX, tanpa filter tgl) — hanya baca. |
| Tak ubah hasil final bln sebelumnya | '88' beku (guard hpp>0 skip) + scope bulanan ⇒ refresh Jul tak mengubah '88'/GL/tsales Januari. |
| Sekali jalan Jan→Des benar | Penulis tunggal + '88' beku urut Jan→Des ⇒ tiap bulan membaca penutup bulan sebelumnya yang sudah final di pass yang sama. |
| Idempotent (1×=10×) | Pass ke-2: guard hpp>0 skip R1; R2 `evap=''` deterministik dari input bulan; '88' tak berubah ⇒ DB identik. |
| WIP selalu WIP-Out | S-E (MAX '88' lintas-bulan); R6/R7 dihapus ⇒ tak ada jalur average untuk WIP. |
| NON-WIP tetap average | R2 dibatasi `evap=''`. |
| Self-heal tanpa ubah historis | Guard hpp=0 hanya mengisi yang kosong; DETEKTOR + runbook untuk koreksi historis. |

### 6.3 Invarian teknis yang harus selalu benar (turunan dari B1–B6)
- **I1:** untuk tiap `(stok,evap)` WIP, `tsales2.hpp` pada '88' bernilai sama di setiap refresh (beku). *(→ B1,B2)*
- **I2:** untuk tiap '22/32/26/36' ber-evap, `hpp = MAX(hpp '88' (stok,evap))`. *(→ B3)*
- **I3:** untuk tiap sale `evap=''`, `hpp = SINV avg akhir bulannya`. *(→ B4)*
- **I4:** `tstok2.hpp` '88' WIP-In = nilai beku '88' pasangannya. *(→ B3)*
- **I5:** GL 102-020 (CONSOUT) & GL 402 (COGS WIP) = `qty * nilai beku`. *(→ B3)*
- **I6 (paling kuat):** refresh periode M **tidak boleh menghasilkan perubahan data apa pun pada periode < M** — `tsales2`, `tstok2`, `sinv`, `gl_journal`. Lebih tegas daripada "tidak ada backward propagation": bukan hanya nilai HPP, tetapi **seluruh** artefak periode sebelumnya harus byte-identik sebelum & sesudah refresh M. *(→ B5,B6)*
- **I7 (integritas ledger):** untuk **setiap** WIP-Out beku, `COUNT(tsales_wipout_freeze)` harus **= 1** — tidak boleh **0** (beku tapi tak teregistrasi) dan tidak boleh **2** (dicegah PRIMARY KEY). Ledger itu sendiri **immutable**: 1 WIP-Out ↔ tepat 1 record freeze, sekali dibuat tak berubah kecuali via recovery. *(→ B1,B2)*
- **I8 (SINGLE HPP AUTHORITY — per SISTEM, bukan per window):** di **seluruh** engine refresh, **tepat satu** komponen berhak menulis HPP = **NVO `n_cst_closing_stock`**. Tidak ada window/fungsi lain (modern **maupun** journal, maupun jalur lain) yang menulis `tsales2.hpp` secara independen. Ini invariant global, bukan sekadar "jalur Modern bersih". *(→ B3,B4; direalisasikan C1–C6 + FASE 1B)*
- **I9 (writer eksklusif SELAMA refresh):** **selama proses Refresh Engine berlangsung**, tidak boleh ada writer lain terhadap `tsales2.hpp` selain NVO. Kalimatnya presisi: **bukan** "tidak boleh ada writer lain" (administrator tetap boleh menjalankan *recovery* di luar refresh), melainkan **selama refresh berlangsung**. Ini menegaskan **batas tanggung jawab** engine refresh — external writer (Stock Opname/Posting/utility) berada di luar boundary dan **tidak** boleh berjalan bersamaan dengan refresh. *(→ B3,B5)*

DETEKTOR memverifikasi I1–I7 tiap selesai refresh; semua harus 0 selisih. I6 diverifikasi lewat *snapshot-diff* periode < M (lihat §8); I7 lewat G7; **I8 lewat EVIDENCE source-search (semua penulis independen OFF) + acceptance journal (§8.5)**; **I9 lewat G6 (Tamper Detector) — bila ada external writer menimpa nilai beku, G6 berbunyi**.

### 6.5 Peran `tsales_wipout_freeze` (batas tegas — syarat ACC Pak Wira)
```
   tsales2.hpp              = SINGLE OPERATIONAL SOURCE (semua runtime baca sini)
                              WIP-sale, CONSOUT, WIP-In, posting GL, laporan, rekon
   tsales_wipout_freeze     = STATE + AUDIT + VALIDATION saja
                              - state : dibaca C1 guard ("sudah beku?")
                              - audit : freeze_date / freeze_by / freeze_source / hpp_frozen
                              - valid : DETEKTOR G6 (TAMPER DETECTOR — tangkap external writer), G7 (I7)
                              BUKAN sumber HPP kedua; hpp_frozen tak pernah dipakai menghitung.
```
Alasan: bila runtime membaca dua tabel untuk nilai HPP, risiko inkonsistensi bertambah. Karena itu ledger **hanya** gerbang-state & jejak-audit; nilai operasional selalu dari `tsales2.hpp`.

### 6.4 Catatan migrasi (cutover satu kali) — dengan freeze-ledger, TANPA "nol-kan '88'"
Karena freeze memakai **ledger** (bukan `hpp=0`), cutover jadi lebih sederhana & tak destruktif:
- **M1 (tak perlu clear):** biarkan ledger **kosong**. Di pass pertama guard C1 `NOT EXISTS(ledger)` benar untuk **semua** '88' → C1 **menghitung ulang** '88' dari SINV-awal bulan itu (SINV-awal = saldo pembuka = penutup bulan sebelumnya, tak bergantung nilai '88' → rantai konvergen 1× pass), lalu **C1b** meregistrasi ke ledger. Nilai lama yang keliru otomatis tertimpa nilai benar; zero-opening (SINV-awal=0) memakai HPP WIP-In; seed manual tanpa basis dipertahankan.
- **M2:** Jalankan refresh **berurutan Jan→Des sekali** (Jan dari saldo awal 2026 yang tetap; Feb dari penutup Jan yang baru final; dst). Ledger terisi otomatis.
- **M3:** Jalankan DETEKTOR (I1–I7). Harus bersih. Sesudah ini refresh berikutnya idempoten (ledger sudah terisi → C1 skip).
- **Recovery** (bila cutover perlu diulang): `DELETE FROM tsales_wipout_freeze;` lalu pass Jan→Des lagi. Runbook: `RUNBOOK_cutover_freeze_wipout.sql`.

---

## 7. DELIVERABLE 7 — Daftar Perubahan Kode Lengkap + Alasan Teknis

> Perubahan bersifat **bedah presisi** (menambah predikat WHERE / menghapus 2 blok patch), **bukan** menulis ulang. Semua di dua file yang Bapak tunjuk.

### A. `n_cst_closing_stock.sru`

**C1 — Bekukan WIP-Out (R1, S-B, baris 98–109). DIPUTUSKAN: Opsi A — freeze-ledger (ACC Pak Wira 2026-07-31).**
Tujuan: satu WIP-Out dibekukan tepat **sekali** lalu dilewati selamanya oleh refresh rutin (B1,B2,I1). Freeze menjadi **state sistem eksplisit**, bukan inferensi dari nilai `hpp`.

**Tabel registri baru** (bukan `ALTER tsales2` → tidak menggeser posisi kolom yang bisa merusak DataWindow PB yang bind by-position):
```
CREATE TABLE tsales_wipout_freeze (
   bukti_id     varchar(20),
   stok_id      varchar(20),
   evap         varchar(30),
   hpp_frozen   numeric(18,2),   -- SNAPSHOT nilai beku: audit + validasi (BUKAN sumber operasional)
   freeze_date  datetime,        -- kapan dibekukan
   freeze_by    varchar(30),     -- user/proses yang membekukan (mis. 'REFRESH', gs_user)
   freeze_source varchar(30),    -- asal nilai: 'SINV_AWAL' | 'WIPIN' | 'MANUAL_SEED' | 'RECOVERY'
   PRIMARY KEY (bukti_id, stok_id, evap) );
```
- **C1 (NVO S-B) berubah:** tambah pada WHERE `AND NOT EXISTS (SELECT 1 FROM tsales_wipout_freeze f WHERE f.bukti_id=TSALES2.BUKTI_ID AND f.stok_id=TSALES2.STOK_ID AND ISNULL(f.evap,'')=ISNULL(TSALES2.EVAP,''))`. Guard membaca ledger **hanya sebagai state** ("sudah beku?"), bukan sebagai nilai HPP.
- **Sesudah UPDATE**, **INSERT** baris ledger untuk tiap '88' evap yang baru dibekukan: `freeze_date=now, freeze_by='REFRESH', freeze_source='SINV_AWAL'/'WIPIN', hpp_frozen = tsales2.hpp` hasil beku.
- **Administrative recovery** (B2): `DELETE FROM tsales_wipout_freeze WHERE bukti_id=...` (terarah, tercatat) → refresh berikutnya membekukan ulang. **Tidak** dilakukan dengan meng-`UPDATE tsales2 SET hpp=0` (mengubah nilai bisnis untuk memicu logika engine = berisiko & kabur maksudnya).
- Formula nilai beku tetap: SINV avg awal → fallback HPP WIP-In → biarkan.

**SYARAT ACC yang dikunci di desain (Pak Wira):**
1. **`tsales2.hpp` tetap SATU-SATUNYA operational source** untuk seluruh runtime (WIP-sale C3, CONSOUT, WIP-In, posting GL, laporan, rekon). Tidak ada jalur runtime yang mengambil nilai HPP dari ledger.
2. **`tsales_wipout_freeze` HANYA** = *freeze state* (dibaca C1 guard) + *audit trail* (freeze_date/by/source/hpp_frozen) + *validator* (DETEKTOR G6/G7). **Bukan** sumber HPP kedua. `hpp_frozen` adalah **snapshot audit**, tidak pernah dibaca untuk menghitung apa pun — hanya dibandingkan (anti-tamper).
3. Ledger bersifat **immutable**: baris tidak di-UPDATE/di-DELETE oleh refresh rutin; hanya bertambah (INSERT saat beku) atau dihapus oleh prosedur recovery eksplisit.
- **DETEKTOR G6 = TAMPER DETECTOR** (bukan bug detector): `tsales2.hpp('88') <> tsales_wipout_freeze.hpp_frozen` → langsung berbunyi bila **external writer** (Stock Opname, Posting HPP, utility lama, script manual, developer) menimpa nilai beku. Penjaga I9 & boundary.
- **DETEKTOR G7** (I7): `COUNT(ledger) per WIP-Out beku` harus **= 1** (tak boleh 0 = beku tapi tak teregistrasi; tak boleh 2 = dicegah PK, tapi tetap dicek utk orphan).

> Opsi `hpp=0` (freeze-by-convention) **DITOLAK** sebagai mekanisme utama — hanya dicatat sebagai alternatif nol-skema yang lebih lemah (tidak auditable, tak bisa bedakan beku-benar vs terisi-salah). Ditinggalkan.

**C2 — Batasi average hanya untuk NON-WIP (R2, S-D, baris 364–366).**
Tambah predikat pada WHERE:
```
   AND ( ISNULL(TSALES2.EVAP,'') = '' )
```
*Alasan:* menghentikan average menimpa '88' beku **dan** memberi WIP nilai average. Sekaligus meng-implement aturan "NON-WIP = average" secara eksplisit. Ini menghapus sumber kerusakan #1 dan pelanggaran #1 (Deliverable 4).

**C3 — Pertegas propagasi WIP = nilai beku, deterministik (R3, S-E, baris 381–397).**
- Ganti `AVG(isnull(b.hpp,0))` → `MAX(isnull(b.hpp,0))` (dan SET pakai `HPP.HPP`).
- Tambah pada WHERE target: `AND ( TSALES1.TIPE_TRANS <> '88' )`.
*Alasan:* `MAX` deterministik dan cocok dengan pembaca lain (1657 lama, f_insert_cons_in) → satu nilai yang sama persis di seluruh sistem; hindari rata-rata bila ada >1 '88'. Pengecualian '88' pada target memastikan '88' **hanya** ditulis C1 (single-writer untuk akar rantai). Subquery tetap **tanpa filter tgl** ⇒ lintas-bulan tetap jalan (jual Juli baca '88' Januari).

**C4 (opsional, konsistensi) — WIP-In pakai MAX (R4, S-F2, baris 451–457).**
Ganti `AVG(isnull(b.HPP,0))` → `MAX(isnull(b.HPP,0))`.
*Alasan:* menyamakan WIP-In dengan I2/I4 (nilai beku, bukan rata-rata). Aman; nilai sama untuk serial tunggal.

*(S-A '19' dan guard qty=0 tetap — sudah idempoten.)*

### B. `w_refresh_transaksi_modern.srw`

**C5 — Hapus penulis bersaing "WIP-Out-first" (R6, baris 1655–1726). [FASE 2 — setelah T10 lulus]**
*Fase 1:* nonaktifkan (comment) blok untuk parallel-run. *Fase 2:* hapus seluruh blok `st_2.text='Menghitung & update HPP...'` + `UPDATE tsales2 SET hpp = isnull((select max ...), isnull(nullif((rumus moving-avg...),0),0)) WHERE bukti_id IN (...) USING sqlca;` s/d `COMMIT USING sqlca;`.
*Alasan:* NVO (C2 non-WIP + C3 WIP) sudah menetapkan HPP dengan benar **sebelum** `f_transfer_so` (NVO dipanggil baris 1647, transfer mulai 1728). R6 hanya penulis kedua yang bersaing dan memuat jalur fallback moving-average untuk WIP (pelanggaran #2). Menghapusnya menjadikan NVO **satu-satunya** penentu HPP → deterministik.

**C6 — Hapus patch "HPP WIP-OUT DRIFT" (R7, baris 1953–2004). [FASE 2 — setelah T10 lulus]**
*Fase 1:* nonaktifkan (comment) untuk parallel-run. *Fase 2:* hapus blok dari `//===== PATCH HPP WIP-OUT DRIFT =====` s/d `//===== END PATCH HPP WIP-OUT DRIFT =====`.
*Alasan:* patch ini reaktif — memperbaiki '88' yang "menyimpang". Dengan '88' beku (C1) dan tanpa perusak (C2), penyimpangan tak lagi terjadi; patch jadi mati fungsi dan hanya menambah penulis + ketergantungan-urutan. Pembangunan WIP-In tetap berjalan lewat `f_insert_cons_in` di modul SO (baris 1746) dan patch WIP-IN YATIM (baris 1944); patch GL-CONSIN YATIM (2024–2063) **tetap**.

*(Tidak ada perubahan `f_insert_cons_in.srf`: overload 1-arg yang dipakai modern membuat write-back baris 366 inert. Cukup dijaga agar modern tak memanggil overload 4-arg untuk WIP.)*

### 7.2 Penelusuran kode sebelum menghapus R6 & R7 (menjawab catatan Pak Wira)

Penghapusan dilakukan **hanya setelah** trace membuktikan tak ada jalur tersembunyi yang bergantung padanya. Hasil trace (sudah dilakukan):

**R6 (baris 1657):** dijalankan **setelah** NVO (`of_run` baris 1647) tetapi **sebelum** `f_transfer_so` (baris 1728). Artinya NVO sudah menetapkan `tsales2.hpp` lebih dulu; R6 hanya **penulis kedua** yang menimpanya. Formula average inline R6 (baris 1658–1714) adalah **rekonstruksi manual** weighted-average; sumber resmi moving-average sistem = **SINV** (yang dipakai NVO S-D). Tidak ada pembaca yang butuh nilai R6 sebelum NVO menuliskannya. **Kesimpulan: R6 redundant terhadap NVO (C2+C3).**

**R7 (drift, baris 1953–2004):** memanggil `f_insert_cons_in` (baris 1996) hanya untuk voucher yang '22'-nya **menyimpang** dari '88'. Pembangunan WIP-In **normal** terjadi di **modul SO baris 1746** (`f_insert_cons_in(ls_bukti)` untuk tiap faktur reguler), dan kasus **lintas-bulan yatim** ditangani **PATCH WIP-IN YATIM baris 1917–1952** (tetap dipertahankan). Jadi menghapus R7 **tidak** menghilangkan pembangunan WIP-In mana pun; drift-nya sendiri tak muncul lagi setelah '88' beku (C1). **Kesimpulan: R7 menambal gejala yang tak akan ada lagi.**

**GATE WAJIB sebelum hapus permanen (parallel-run):**
1. Terapkan C1–C4 (NVO) dulu. **Nonaktifkan** R6 & R7 secara sementara (comment, belum hapus).
2. Refresh satu periode uji → bandingkan `tsales2.hpp` hasil NVO-only vs hasil lama (R6/R7 aktif).
3. **Kriteria lulus:** baris **NON-WIP** (`evap=''`) **identik**; baris **WIP** hanya boleh berbeda ke arah **nilai beku benar** (I2). Bila ada baris NON-WIP yang berubah → ada dependensi tersembunyi R6 (mis. stok tanpa baris SINV) → **fungsi itu digabung ke NVO**, bukan dibuang.
4. Hanya setelah gate lulus, R6 & R7 **dihapus** permanen.

### C. Pendukung (di luar 2 file, untuk jaminan — tidak wajib disubmit bersamaan)
- **DETEKTOR** `DETEKTOR_residu_hpp_bulanan.sql`: tambah tiga gate baru — **G5** = penjualan WIP (`'22/32/26/36'` ber-evap) dengan `hpp=0` **atau** `hpp <> MAX('88' hpp (stok,evap))` → out-of-order/immutable-miss (I2); **G6** = `tsales2.hpp('88') <> tsales_wipout_freeze.hpp_frozen` → penimpaan nilai beku di luar recovery (anti-tamper); **G7** = `COUNT(ledger) per WIP-Out beku <> 1` → integritas ledger (I7, tangkap beku-tak-teregistrasi & orphan). G1–G4 existing tetap.
- **Runbook cutover** `RUNBOOK_cutover_freeze_wipout.sql`: implement M1 (nol-kan '88' yang dapat diturunkan ulang, kecuali seed manual) **lalu isi ledger** untuk seluruh '88' beku hasil pass Jan→Des (backfill freeze state + snapshot). Dijalankan sekali sebelum/berbarengan pass Jan→Des.

### 7.1 Ringkasan dampak per invariant
| Perubahan | Menjamin |
|---|---|
| C1 | I1 (beku), idempotensi, no-backward-propagation |
| C2 | I3 (NON-WIP=avg), stop korupsi '88' & WIP-average |
| C3 | I2 (WIP=WIP-Out, lintas-bulan, deterministik), single-writer '88' |
| C4 | I4 (WIP-In=beku) |
| C5 | hapus penulis bersaing + jalur average-untuk-WIP |
| C6 | hapus patch reaktif → determinisme |

---

## 8. Rencana Verifikasi — ACCEPTANCE TEST (bukti idempotensi & kebenaran)

### 8.1 Tabel acceptance (harus semua LULUS sebelum dinyatakan selesai)

| # | Test | Expected | Verifikasi ke invariant |
|---|---|---|---|
| T1 | Refresh **Jul** | Januari **tidak berubah** (tsales2/tstok2/sinv/gl_journal) | I6, B5 |
| T2 | Refresh **Aug** | Januari–Juli **tidak berubah** | I6, B5 |
| T3 | Refresh **Jan–Des 2×** berturut | `diff` pass ke-2 = **0** | B6, I1 |
| T4 | Penjualan **WIP** (sampel) | `HPP jual = HPP WIP-Out` (nilai beku) | B3, I2 |
| T5 | Penjualan **Non-WIP** (sampel) | `HPP jual = Moving Average` (SINV avg akhir bln) | B4, I3 |
| T6 | **CONSOUT** | `GL 102-020 = qty × HPP WIP-Out` | B3, I5 |
| T7 | **CONSIN** | `WIP-In (tstok88) = HPP WIP-Out` | B3, I4 |
| T8 | **DETEKTOR G1–G7** tiap bulan | **kosong** | I1–I7 |
| T9 | **Rekon** | Konsinyasi Out=In; Stok/AR/AP vs Ledger dalam toleransi | — |
| T10 | **Parallel-run** (§8.4) mode lama vs mode baru | NON-WIP identik 100%; WIP hanya bergeser ke nilai WIP-Out benar; tak ada transaksi lain berubah | prasyarat hapus R6/R7 |
| T11 | **Integritas ledger** | 1 WIP-Out ↔ 1 record freeze; G6=G7=kosong | I7, B2 |

### 8.2 Cara uji I6 (paling kuat) — snapshot-diff periode < M
Sebelum refresh M: simpan hash/`checksum` baris `tsales2, tstok2, sinv, gl_journal` untuk **semua periode < M**. Sesudah refresh M: hitung ulang. **Harus identik** (0 baris berubah). Ini bukti langsung "refresh M tak mengubah periode sebelumnya", lebih kuat daripada sekadar mengklaim tak ada backward propagation.

### 8.3 Gate parallel-run (§7.2) — prasyarat sebelum R6/R7 dihapus permanen.

### 8.4 Protokol parallel-run (T10) — bukti, bukan keyakinan (syarat ACC Pak Wira)
```
   Mode LAMA  (R6/R7 aktif, NVO belum diubah)
        └── refresh periode uji ──► SNAPSHOT-A (tsales2.hpp, tstok2.hpp, gl_journal)
   Mode BARU  (C1–C4 terpasang; R6/R7 DINONAKTIFKAN/comment, belum dihapus)
        └── refresh periode uji ──► SNAPSHOT-B
   COMPARE A vs B:
        ✓ NON-WIP (evap='')      : IDENTIK 100%
        ✓ WIP (evap<>'')         : hanya berubah menuju nilai WIP-Out beku yang BENAR (I2)
        ✓ Tidak ada transaksi lain di luar scope tsb yang berubah
```
Hasil perbandingan **didokumentasikan** (mis. `EVIDENCE_parallelrun_R6R7.md`). Hanya bila ketiga kriteria lulus, R6 & R7 dihapus permanen (C5/C6). Bila ada baris NON-WIP berubah → dependensi tersembunyi → fungsi digabung ke NVO, bukan dibuang.

### 8.5 Acceptance Single HPP Authority — journal (I8, FASE 1B)
`ACCEPTANCE_journal_authority.sql`: snapshot HPP baseline (pasca-refresh Modern) → **refresh periode sama via `w_refresh_journal` (window LAMA)** → verifikasi:
- **3a:** 0 baris `tsales2.hpp` berubah (journal ≡ NVO; bukan otoritas kedua).
- **3c:** DETEKTOR **G6=0** (anti-tamper) & **G8=0** (nilai freeze pertama) tetap.
LULUS = perilaku journal **eksplisit**: ia mendelegasikan HPP ke NVO (redirect ke otoritas tunggal), bukan menulis independen. Membuktikan **I8 per-sistem**, bukan hanya jalur Modern.

## 9. Rollback
Tiap file di-backup sebelum edit (`.bak_redesign`). Perubahan murni source PowerBuilder → rollback = restore backup + Full Build. Cutover M1 reversibel (snapshot '88' sebelum nol-kan). Tanpa DDL, tanpa ubah struktur tabel.

---

## 10. Yang TIDAK termasuk redesign ini (agar cakupan jelas)
- Residu **saldo awal 2026** (TR/TB/MT ~10,2 M) = warisan tutup buku 2025, kebijakan terpisah (Opsi A/B/C).
- Bug **delete lintas-bulan** by doc_reff/voucher di `f_transfer_*` (sudah difix terpisah `.bak_docreffscope`) — invariant "scope bulanan" di sini bergantung padanya; dipastikan tetap terpasang.
- Unit **zero-opening** (`CIM1096206`) yang butuh konfirmasi nilai fisik — ditangani seed manual + DETEKTOR, bukan oleh engine.

---
**Keputusan yang diminta:** setujui desain ini (C1–C6 + pendukung). Setelah **ACC**, saya implementasikan menyeluruh ke `n_cst_closing_stock.sru` dan `w_refresh_transaksi_modern.srw` sekaligus (bukan patch parsial), lalu siapkan runbook cutover + DETEKTOR G5, dan protokol uji idempotensi 2×.
