# AUDIT ENGINE COSTING & REFRESH — Backdate/Immutability Rule

Tanggal: 2026-08-11 (revisi 2 — verifikasi tambahan atas urutan eksekusi modul & mekanisme posting GL)
Objek yang diaudit (source code aktif, dibaca langsung — bukan asumsi):
- `w_refresh_transaksi_modern.srw` (3376 baris)
- `w_refresh_journal.srw` (2591 baris)
- `n_cst_closing_stock.sru`
- `f_transfer_cons.srf` (246 baris)
- `f_insert_cons_in.srf`
- `d_trace_get_hpp.srd` (DataWindow retrieve SQL)
- `_engine_sql.txt` (extracted retrieve SQL dari `dw_refresh_stok.srd`)

Semua nomor baris merujuk ke file aktif di `C:\BTV\debug\` per tanggal audit ini.

---

## A. FLOW COSTING AKTUAL SAAT INI (dari source)

### A.1 — WIP-Out (`tipe_trans='88'`)
```
n_cst_closing_stock.of_run(), baris 150-162 (FREEZE '88')
  tier1: SINV.HPP_AVG WHERE PERIODE=:ldt_tgl1 (awal bulan transaksi)
  tier2 (fallback bila tier1=0): MAX(HPP) dari TSTOK2 tipe_trans='88' dgn COA_ID=EVAP yg sama
  tier3 (fallback bila tier1&tier2=0): baris 171-209, GL_JOURNAL kredit / qty baris HPP=0 se-voucher
  GUARD: WHERE ISNULL(TSALES2.HPP,0) = 0   <-- baris 162
```
**Begitu HPP terisi non-zero SEKALI, guard ini membuatnya TIDAK PERNAH disentuh lagi oleh refresh apa pun, selamanya** — tidak ada kondisi "kecuali ada backdate" di mana pun dalam guard ini.

### A.2 — Penjualan reguler non-EVAP (`tipe_trans='22'`, EVAP kosong)
```
n_cst_closing_stock.of_run(), baris 502-513 (step "4a")
  HRG = ISNULL(NULLIF(closing_avg,0), fallback opening+beli helper)
  closing_avg diambil dari: SUM(HPP_AVG) FROM SINV WHERE PERIODE=:ldt_next   <-- baris 485-488
```
`:ldt_next` = SALDO PENUTUPAN bulan yang SEDANG diproses (menjadi saldo awal bulan berikutnya). Saldo penutupan ini dihitung oleh retrieve (`_engine_sql.txt` baris 67: `NILAI = B.QTY * ISNULL(B.HPP,0)`) — yaitu MENGURANGI dengan qty×HPP penjualan bulan itu SENDIRI.

**TIDAK ADA GUARD** pada UPDATE ini — dieksekusi ulang, menimpa HPP semua penjualan reguler bulan tsb, SETIAP KALI refresh dijalankan.

### A.3 — Penjualan EVAP (unit yang sebelumnya WIP-Out lalu terjual, `tipe_trans<>'88'` tapi EVAP terisi)
```
n_cst_closing_stock.of_run(), baris 527-545 (step "4b")
  HPP = MAX(HPP) dari TSALES1/TSALES2 tipe_trans='88' dgn EVAP sama
```
Sumbernya adalah HPP '88' yang SUDAH terkunci (A.1) — jadi otomatis konsisten dgn A.1, tapi mewarisi keterbatasan yang sama (kalau A.1 salah/beku, ini ikut salah/beku).

### A.4 — Jalur GL Posting (`f_transfer_cons.srf`)
```
f_transfer_cons.srf baris 80: ldec_hpp = lds_po.object.ttl_hpp[i]   (dari d_trace_consout / d_trace_consout_real)
f_transfer_cons.srf baris 13,26,38,45,230,239: lds_hpp (d_trace_get_hpp) DIBUAT tapi TIDAK PERNAH di-retrieve — DEAD CODE
f_transfer_cons.srf baris 221: DELETE FROM gl_journal WHERE voucher=:arg_order_client AND modul_id='AS'
                                 AND month(tgl)=month(:ldt_tgl) AND year(tgl)=year(:ldt_tgl)
f_transfer_cons.srf baris 222-224: lds_update.accepttext(); lds_update.update(); commit;  -- INSERT ulang
```
Fungsi ini murni menyalin HPP yang SUDAH ada di TSALES2 ke GL_JOURNAL (**tidak menghitung ulang** — SESUAI requirement "hanya transfer"). **Revisi penting**: fungsi ini BUKAN read-only terhadap GL — ia **DELETE lalu INSERT ULANG** baris GL untuk voucher tsb, sehingga GL 102-020 SELALU mengikuti nilai TSALES2.HPP TERKINI **setiap kali fungsi ini dipanggil untuk voucher itu**.

**Syarat agar mekanisme ini benar-benar meng-cascade ke GL**: fungsi ini hanya terpanggil untuk voucher X ketika voucher X ikut ter-retrieve oleh `d_trace_consout_all` (dipanggil dari `of_refresh_cons_out()`), yang di-filter berdasarkan rentang tanggal **yang dipilih user** (`ldt1`/`ldt2`), BUKAN otomatis mendeteksi "voucher mana yang HPP-nya berubah". Jadi: **update GL akan mengikuti HPP terbaru HANYA JIKA user secara manual memilih rentang tanggal yang mencakup bulan voucher tsb dan menjalankan ConsOUT/ConsIN refresh lagi** — bukan otomatis ter-trigger oleh perubahan HPP di tempat lain.

### A.5 — Ketergantungan Urutan Modul (temuan tambahan — verifikasi eksplisit)
```
w_refresh_transaksi_modern.srw baris 695-714 (of_run_modul, choose case):
  case 'SO'      -> of_refresh_so()       -- baris 884-897: memanggil n_cst_closing_stock.of_run()
  case 'CONSOUT' -> of_refresh_cons_out()  -- baris 1797-1836: HANYA retrieve d_trace_consout_all + f_transfer_cons(...,'OUT')
  case 'CONSIN'  -> of_refresh_cons_in()   -- baris 1838+: HANYA f_transfer_cons(...,'IN') + patch WIP-in yatim
```
**Dikonfirmasi eksplisit**: `of_refresh_cons_out()` dan `of_refresh_cons_in()` **TIDAK PERNAH memanggil `n_cst_closing_stock.of_run()`**. Mekanisme freeze/tier1-2-3 dan "Update HPP Average" HANYA berada di dalam `of_refresh_so()`.

**Risiko nyata**: checkbox modul di UI (`cb_so`, `cb_consout`, dst — baris 3046-3054) bersifat **independen**, tidak ada validasi kode yang memaksa `cb_so` tercentang saat `cb_consout` dijalankan. Jika user HANYA mencentang "Cons OUT" (tanpa "SO") dan menjalankan refresh, maka WIP-Out yang HPP-nya masih 0 **tidak akan pernah dibekukan** pada eksekusi tsb — `of_refresh_cons_out()` akan mem-posting HPP apa pun yang SAAT ITU ada di TSALES2 (bisa jadi masih 0) ke GL, TANPA pernah menjalankan freeze/average terlebih dahulu. Urutan "SO wajib jalan duluan" adalah **disiplin prosedural/kebiasaan pemakaian**, bukan jaminan teknis dari kode.

### A.6 — Dua Jalur Refresh Paralel (temuan tambahan, di luar 4 poin di atas)
Ditemukan **DUA implementasi costing yang BERBEDA dan TERPISAH**:

| | `w_refresh_transaksi_modern.srw` | `w_refresh_journal.srw` |
|---|---|---|
| Update HPP Average | Baris 884-897: memanggil `n_cst_closing_stock.of_run()` | Baris 2021-2091: UPDATE SQL **sendiri**, inline, TIDAK memanggil `n_cst_closing_stock` sama sekali |
| Guard immutable utk '88' | ADA (lihat A.1) | **TIDAK ADA** — baris 2084: `tipe_trans IN ('22','32','26','36','88')`, HPP tipe '88' ikut ditimpa tanpa syarat apa pun |
| Formula average | tier1/2/3 + helper (opening+beli+ekspedisi+mutasi_masuk+retur_jual) | Formula sendiri (opening+beli+mutasi_in+retur_jual, TANPA ekspedisi terpisah dgn cara sama) |

Konfirmasi: `grep "n_cst_closing_stock"` pada `w_refresh_journal.srw` = **0 hasil**. Window ini beroperasi 100% independen dari engine `n_cst_closing_stock.sru` yang sudah diperbaiki sepanjang sesi ini.

**Risiko nyata**: jika `w_refresh_journal.srw` (bukan versi modern) pernah/akan dijalankan untuk periode yang mencakup transaksi WIP-Out yang sudah dikunci, HPP EVAP yang sudah benar (termasuk 66 baris yang baru saja diperbaiki sesi ini) **akan tertimpa ulang tanpa guard**, berpotensi merusak kembali data yang sudah diperbaiki.

### A.7 — Deteksi Backdate
```
grep "backdate" pada keempat file utama: HANYA 1 hasil, sebuah KOMENTAR
  n_cst_closing_stock.sru baris 1 (area lain, tidak terkait costing '88'/'22'):
  "// hapus data lama (kemungkinan closing backdate); cek akhir tahun utk replace saldo"
```
**TIDAK DITEMUKAN DI SOURCE** mekanisme deteksi backdate otomatis, penanda "periode terdampak", atau trigger cascade apa pun. Recalculation HANYA terjadi jika user secara MANUAL memilih ulang rentang tanggal yang mencakup periode backdate tsb dan menjalankan refresh.

---

## B. FLOW COSTING YANG SEHARUSNYA (per business rule final)

```
WIP-Out terjadi
   -> ambil average periode SAAT ITU -> lock per EVAP
        -> [IMMUTABLE] selama tidak ada backdate
        -> [JIKA ADA backdate periode terdampak]:
             1. deteksi periode terdampak
             2. hitung ulang weighted average periode tsb
             3. cascade update:
                - HPP EVAP WIP-Out (termasuk yang SUDAH terkunci)
                - outstanding EVAP (belum terjual)
                - TSALES2.hpp (penjualan yg sudah terjadi, EVAP maupun reguler)
                - SINV
                - TSTOK2
                - journal 102-020
```

---

## C. GAP ANTARA A DAN B

| # | Gap | Bukti |
|---|---|---|
| 1 | Freeze '88' bersifat **immutable PERMANEN**, tidak ada exception utk backdate — begitu terkunci, TIDAK ADA jalur di source manapun yang bisa membukanya kembali | Guard `ISNULL(TSALES2.HPP,0)=0`, baris 162; tidak ditemukan UPDATE lain yg menyentuh TSALES2.HPP utk tipe_trans='88' di keempat file, KECUALI `w_refresh_journal.srw` yang justru menimpanya TANPA syarat backdate (bukan cascade terkontrol, tapi overwrite buta) |
| 2 | Penjualan reguler (4a) justru **TERLALU mutable** — bukan "rebuild terkontrol saat backdate", tapi ditimpa ulang SETIAP refresh via referensi sirkular (`closing_avg` dari saldo penutupan yang mengandung penjualan itu sendiri) | Baris 485-488 + 502-513 (of_run) vs `_engine_sql.txt` baris 67; terbukti empiris: TS.066-8344C & TS.102-1081 rusak membesar setiap kali direfresh ulang |
| 3 | Tidak ada deteksi backdate otomatis di source manapun | Grep 4 file: 0 mekanisme nyata ditemukan |
| 4 | Tidak ada cascade update ke SINV/TSTOK2/ledger 102-020 yang dipicu OLEH perubahan HPP historis — update SINV/TSTOK2 hanya terjadi sbg efek samping refresh biasa (bukan cascade terarah dari satu titik perubahan) | Tidak ditemukan trigger/prosedur cascade; SINV ditulis ulang massal oleh retrieve tiap refresh (bukan cascade selektif dari titik backdate) |
| 5 | Dua mesin costing paralel (`n_cst_closing_stock.sru` vs `w_refresh_journal.srw`) dengan formula BERBEDA dan level proteksi BERBEDA — melanggar prinsip single-source-of-truth dan menciptakan risiko regresi tersembunyi | A.6 di atas |
| 6 | "Update HPP Average" (freeze + weighted-avg) hanya terpasang di modul 'SO', TIDAK ada di 'CONSOUT'/'CONSIN' — tidak ada jaminan teknis modul SO selalu jalan lebih dulu, hanya kebiasaan pemakaian | A.5 di atas: `of_refresh_cons_out()`/`of_refresh_cons_in()` (baris 1797-1909) tidak memanggil `n_cst_closing_stock` |
| 7 | GL 102-020 (via `f_transfer_cons`) memang delete+insert-ulang mengikuti TSALES2.HPP terkini (BUKAN read-only seperti dugaan awal), TAPI hanya ter-trigger bila voucher tsb ikut ter-retrieve pada rentang tanggal yang DIPILIH MANUAL user — bukan otomatis terpicu oleh perubahan HPP di tempat lain | A.4 di atas: `f_transfer_cons.srf` baris 221-224 |

---

## D. TABEL STATUS RULE

| Rule | Status | Evidence Source |
|---|---|---|
| WIP-Out mengambil average periode saat transaksi | ✅ SESUAI (dgn fallback tier2/tier3 saat avg=0) | `n_cst_closing_stock.sru` baris 150-209 |
| HPP lock per EVAP/Serial | ⚠️ SESUAI tapi **immutable permanen**, bukan conditional-terhadap-backdate | `n_cst_closing_stock.sru` baris 162 (guard) |
| Refresh recalculation (average dihitung ulang saat refresh) | ⚠️ ADA, tapi **desain sirkular** utk penjualan reguler — bukan recalculation yang benar | `n_cst_closing_stock.sru` baris 485-488, 502-513; `_engine_sql.txt` baris 67 |
| Backdate rebuild (deteksi + recalculation terarah) | ❌ **TIDAK DITEMUKAN DI SOURCE** | Grep 4 file utama, 0 mekanisme |
| Update sales HPP (existing, dipicu backdate) | ❌ TIDAK ADA utk EVAP/'88' (diblokir guard permanen); ⚠️ ADA tapi salah-arah (sirkular, bukan backdate-triggered) utk reguler/'22' | Sda poin di atas |
| Update outstanding EVAP saat backdate | ❌ **TIDAK DITEMUKAN DI SOURCE** — freeze membuatnya tidak pernah diproses ulang, backdate atau tidak | `n_cst_closing_stock.sru` baris 162 |
| Update ledger 102-020 mengikuti HPP historis yang berubah | ⚠️ **ADA MEKANISMENYA** (delete+insert-ulang, baris 221-224) tapi **TIDAK OTOMATIS** — hanya jalan jika user manual pilih rentang tanggal mencakup voucher tsb & jalankan ulang ConsOUT/ConsIN. Tidak ada trigger yang mendeteksi "HPP voucher X berubah, maka re-post GL voucher X" | `f_transfer_cons.srf` baris 80 (sumber HPP), 221-224 (delete+insert GL) |
| Modul SO wajib jalan sebelum ConsOUT/ConsIN (agar freeze/average ter-eksekusi) | ⚠️ **HANYA disiplin prosedural, TIDAK ADA enforcement teknis** — checkbox independen, tidak ada validasi kode | `w_refresh_transaksi_modern.srw` baris 695-714, 1797-1909, 3046-3054 |

---

## E. KESIMPULAN PER SKENARIO

1. **Transaksi normal (tanpa backdate)**: ⚠️ **SEBAGIAN AMAN**. Jalur WIP-Out (EVAP) aman by-design (freeze bekerja seperti dimaksud). Jalur penjualan reguler **TIDAK aman** — desain sirkular (4a) berisiko merusak diri sendiri bahkan tanpa ada backdate sama sekali, cukup dengan refresh berulang pada bulan yang sama (terbukti empiris: TS.066-8344C rusak sejak April, sebelum ada backdate apa pun terlibat).

2. **Pembelian setelah WIP-Out**: ❌ **TIDAK AMAN** dalam dua arah — (a) untuk EVAP yang SUDAH terkunci: pembelian baru TIDAK PERNAH memicu update ulang HPP EVAP tsb (sesuai jika HPP lama benar, tapi tidak ada jalan koreksi jika salah); (b) untuk EVAP yang WIP-Out terjadi SEGERA setelah pembelian dalam bulan yang sama: tier1 gagal (saldo awal=0), sistem jatuh ke tier3 (GL-fallback) yang terbukti empiris bisa salah (kasus NR: 3 dari 5 transaksi salah dalam batch yang sama).

3. **Koreksi plus**: ❌ **TIDAK ADA cascade ke EVAP yang terkunci**. Untuk penjualan reguler, memang ter-refresh ulang tiap kali proses refresh dijalankan, TAPI melalui mekanisme sirkular yang berisiko memperbesar kesalahan alih-alih memperbaikinya secara terarah.

4. **Koreksi minus**: sama seperti poin 3 — EVAP terkunci tidak tersentuh; jalur reguler tetap berisiko sirkular yang sama.

5. **Backdate bulan sebelumnya**: ❌ **TIDAK ADA deteksi otomatis** di source manapun. Recalculation hanya terjadi jika user memilih ulang rentang tanggal secara manual dan menjalankan refresh — dan bahkan itu pun TIDAK men-cascade ke EVAP yang sudah terkunci, dan untuk jalur reguler prosesnya adalah overwrite sirkular, bukan rebuild yang benar dan terarah.

6. **Penjualan setelah perubahan histori**: Untuk EVAP (WIP): tetap memakai HPP lama tanpa pengecualian — benar HANYA jika HPP lama itu sudah akurat; jika perlu dikoreksi karena backdate, TIDAK ADA jalan untuk memperbaikinya lewat refresh. Untuk penjualan reguler: HPP BISA berubah setiap refresh (4a selalu re-run), tapi arah perubahannya tidak terjamin benar — bisa memperbaiki, bisa juga memperburuk (compounding), tergantung kondisi data saat itu.

---

## RINGKASAN UNTUK PAK WIRA

Kesimpulan sesuai konfirmasi Bapak: **prinsip freeze/immutable pada WIP-Out sudah benar secara konsep**, dan **akar kerusakan 102-110 (TS.066-8344C, TS.102-1081) ada di jalur penjualan reguler (step 4a)** — bukan di WIP-Out. Audit ini menambahkan detail:

- Step 4a rusak karena **desain sirkular** (referensi ke saldo penutupan yang mengandung dirinya sendiri), bukan sekadar "lupa cascade" — ini bug struktural yang aktif merusak data SETIAP kali refresh diulang pada bulan yang sama, dengan atau tanpa backdate.
- Freeze WIP-Out ternyata **immutable permanen tanpa pengecualian apa pun** (termasuk backdate) — sesuai temuan Bapak bahwa ini perlu diperbaiki menjadi conditional.
- Ditemukan **risiko tambahan**: `w_refresh_journal.srw` (window lama) punya mesin costing sendiri yang terpisah total dari `n_cst_closing_stock.sru`, dan TIDAK punya guard immutability sama sekali untuk WIP-Out — berpotensi merusak ulang HPP yang sudah benar jika window ini pernah dijalankan.

**Belum ada perubahan source yang saya terapkan** — laporan ini murni hasil pembacaan kode. Menunggu arahan Bapak untuk langkah perbaikan (step 4a, aturan backdate-cascade utk freeze '88', dan status `w_refresh_journal.srw`).
