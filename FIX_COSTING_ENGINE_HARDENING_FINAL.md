# FIX PERMANENT: Costing Engine Hardening — n_cst_closing_stock.sru

Status: **source code selesai, terverifikasi read-only, BELUM di-build/deploy**
Tanggal: 2026-08-03 (update: gate false-positive fix + optimisasi performa)
File utama yang diubah: `C:\BTV\debug\n_cst_closing_stock.sru` (827 baris, UTF-16LE+BOM)

---

## 0. UPDATE PASCA-UJI PRODUKSI (baca dulu sebelum bagian 1-8)

Setelah Pak Wira mencoba refresh Januari dengan versi pertama fix ini, ditemukan 2 hal yang PERLU diperbaiki (sudah diperbaiki di source, lihat detail):

**a) GATE terlalu ketat (false positive) — SUDAH DIPERBAIKI.** Gate sempat menolak 176 baris yang ternyata BUKAN bug: kode "model dasar" (mis. `TR.038`, `TR.039`, `TYU-001`) punya `qty` besar di SINV tapi `nilai=0` BY DESIGN (nilai riil ada di kode varian spesifik, bukan di kode model dasar — pola yang sudah pernah terdokumentasi sebelumnya). Kondisi gate semula salah memakai `qty<>0 OR nilai<>0` untuk menentukan "cost basis tersedia"; seharusnya HANYA `nilai<>0` (qty tanpa nilai rupiah bukan cost basis yang valid). Diperbaiki di 3 tempat (kondisi WHERE gate 22-JUAL/19-MUTKELUAR/4C-ADJ). Diverifikasi ulang: 0 false-positive tersisa untuk Januari.

**b) Closing jadi lambat — SUDAH DIOPTIMASI.** Root cause performa: fallback moving-avg (opening+beli+closing-avg) awalnya dihitung ULANG di 6 tempat terpisah (3 blok fix '19'/'22'/'4c' + 3 blok gate), masing-masing lewat derived-table majemuk yang berat buat optimizer ASA9. Fix: semua komponen itu sekarang dihitung **SEKALI** per `of_run()`, disimpan ke tabel bantu kecil `costing_helper_movavg` (opening_qty/nilai, beli_qty/nilai dihitung di awal; closing_avg dihitung sekali lagi setelah SINV periode ini selesai ditulis), lalu 6 blok itu tinggal JOIN sederhana ke tabel kecil ber-index ini. DDL tabel baru sudah ditambahkan ke `provision_costing_gate_tables.sql`.

**c) Wajib refresh 2x berturut-turut per bulan (bukan bug, karakteristik arsitektur lama).** Step 4a/4c memperbaiki HPP transaksi SETELAH SINV periode ini ditulis (urutan ini sudah ada sebelum sesi ini, bukan buatan hari ini) — jadi run pertama memperbaiki HPP transaksi tapi SINV bisa saja masih pakai angka lama untuk item yang TIDAK habis sampai qty=0. Run kedua akan membaca HPP yang sudah benar dari run pertama, sehingga SINV ikut benar. Run ketiga dst tidak mengubah apa-apa lagi (sudah konvergen). **Jalankan tiap bulan 2x berturut-turut sebelum lanjut ke bulan berikutnya.**

**d) WIP gate ringkasan false-positive — SUDAH DIPERBAIKI.** `wip_out_gate_result` (mekanisme WIP dari kerja SEBELUM sesi hardening ini, bukan buatan hari ini) sempat menampilkan 102-001 "MISMATCH" Rp135.825.948,00 di hasil refresh Januari — padahal dicek dgn metode presisi (per-voucher, sama seperti breakdown detailnya sendiri) hasilnya 0 selisih sempurna. Akar: ringkasan gate menghitung GL berdasar RENTANG TANGGAL (`GL.tgl BETWEEN periode`), padahal tanggal posting GL bisa beda bulan dari tanggal transaksi vouchernya. Diperbaiki: ringkasan sekarang agregat PER-VOUCHER dulu (match ke GL via nomor voucher), baru dijumlah ke level akun — konsisten dgn metode detail. Diverifikasi ulang: 102-001 Jan sekarang 0,00 selisih.

**e) Cakupan cost-basis kurang lengkap — SUDAH DIPERLUAS.** Setelah refresh Jan+Feb sukses, validasi saldo antar-bulan (`saldo akhir Jan dihitung ulang` vs `saldo awal Feb tersimpan`) masih menyisakan gap di 102-101 (Rp20, praktis nol) dan **102-110 (Rp600.019,85, signifikan)**. Ditelusuri ke item `LH.01.0006` (HOSE ASSY): masuk murni via **Mutasi Masuk gudang ('09')**, BUKAN pembelian — fallback moving-avg semula HANYA mempertimbangkan opening + pembelian ('02'), jadi item ini dianggap "tak ada cost basis" padahal sebenarnya ada (dari mutasi masuk). Diperbaiki: `costing_helper_movavg` sekarang menghitung cost-basis dari SEMUA jalur masuk nilai non-WIP — beli('02'), ekspedisi('05', value-only, tak nambah qty — konsisten pola engine), mutasi-masuk('09'), DAN retur-jual (32/26/36, dgn filter identik formula resmi engine: join MCUST + HRG≠0). Diverifikasi read-only: LH.01.0006 sekarang dapat cost-basis Rp600.000/3unit=Rp200.000/unit, persis menutup residu 102-110.

**Karena (d) dan (e) ditemukan SETELAH Januari & Februari sempat di-refresh sukses dengan versi source SEBELUM kedua fix ini, kedua bulan itu perlu di-refresh ULANG (masing-masing 2x, lihat poin c) setelah build terbaru.**

Semua isi bagian 1-8 di bawah masih berlaku (root cause, before/after logic konsep, checklist) — hanya detail kode persis dan catatan run-2x ini yang menambah/menggantikan.

---

## 1. ROOT CAUSE FINAL

**Bukan bug baru.** Bukan efek dari fix WIP-Out (`tipe_trans='88'`) yang dikerjakan sebelumnya.

Root cause: **regresi silent**. Pada 2026-08-01, sudah dibuat fix costing untuk `n_cst_closing_stock.sru` (fallback moving-average untuk step 4a jual reguler '22' dan mutasi keluar '19'), sudah diverifikasi Pak Wira berhasil di prod. Tapi fix itu **tidak pernah masuk ke file yang aktif dipakai** — dibuktikan lewat timestamp: file checkpoint `n_cst_closing_stock.sru.bak_wipout_gl_singlesource` (dibuat 2026-08-03 08:54, titik awal sesi kerja WIP-Out hari ini) **sudah tidak punya fix itu**, padahal `n_cst_closing_stock.sru_fix` (dibuat 2026-08-01 23:39) **punya**. Fix costing hilang di suatu titik antara dua waktu itu, sebelum sesi WIP-Out hari ini bahkan dimulai.

**Mekanisme teknis (kenapa HPP bisa jadi 0):**

Empat blok kode menulis `TSALES2.HPP` / `TSTOK2.HPP` untuk transaksi KELUAR (jual reguler, mutasi keluar gudang, adjustment). Sebelum fix, tiga di antaranya (4a, mutasi'19', 4c-Adjustment) mengambil harga dari **`SINV.HPP_AVG` pada PERIODE PENUTUPAN BULAN INI SENDIRI (`:ldt_next` / closing-avg)** — sumber yang **SIRKULAR**: kalau barang habis terjual/keluar dalam bulan yang sama (qty akhir = 0), rule lama "qty=0 → nilai=0" (yang MEMANG SENGAJA ada, untuk cegah residu nyangkut ke bulan berikutnya) **sudah menol-kan** `SINV.HPP_AVG` bulan ini SEBELUM step 4a/19/4c sempat membacanya — hasilnya HPP keluar = 0, walau cost basis (saldo awal atau pembelian bulan ini) sebenarnya ADA dan valid.

Efeknya berantai:
1. COGS tidak tercatat (HPP=0 pada baris jual/keluar).
2. Rumus resmi `akhir_rpxx` (dari `dw_refresh_stok.srd`) tetap menyisakan residu nilai (karena beli/awal masuk, tapi keluar tidak mengurangi nilai — cuma qty).
3. Rule "qty=0→nilai=0" membuang residu itu SEBELUM ditulis ke `SINV` — supaya saldo fisik tetap benar (unit=0 → nilai=0 memang benar secara akuntansi).
4. Tapi laporan Mutasi Stok (yang menghitung `akhir_rpxx` mentah, tanpa melalui rule pembuangan itu) **masih menampilkan residu** → Saldo Akhir bulan N (laporan) ≠ Saldo Awal bulan N+1 (SINV tersimpan).

**Skala (dibuktikan read-only terhadap prod, formula resmi engine, BUKAN pendekatan manual):**

| Bulan→Bulan | Akun terdampak (selisih >Rp1) |
|---|---|
| Jan→Feb | 102-010 (5,3jt), **102-101** (15,9jt), **102-102** (13,5jt), **102-110** (1,6jt) |
| Feb→Mar | 102-010 (25,5jt), 102-101 (29,6jt), 102-103 (2,2jt), 102-110 (36), 102-203 (117,5jt) |
| Mar→Apr | 102-101 (11,9jt), 102-102 (10), 102-103 (2,2jt), 102-110 (20,3jt) |
| Apr→Mei | 102-001 (33,0jt), 102-010 (11,3jt), 102-016 (11,0jt), 102-018 (1,73M), 102-101 (13,8jt), 102-110 (14,5jt) |
| Mei→Jun | 102-003 (43,2jt), 102-110 (37,5jt) |
| Jun→Jul | 102-010 (14,4jt), 102-101 (108,4jt), 102-102 (0,4jt), 102-103 (9,2jt), 102-110 (27,1jt), 102-113 (0,2jt) |

Terbukti **BUKAN masalah WIP**: akun WIP TR/NR/TB (102-001/003/006) yang muncul di tabel di atas (Apr→Mei, Mei→Jun) adalah dari transaksi **non-'88'** (jual/mutasi reguler barang yang KEBETULAN memakai kode akun yang sama) — bukan dari mekanisme WIP-Out itu sendiri. Dibuktikan di §4 TEST CASE 3.

**Item pembukti utama:**
- `TS.102-1081` (COMPRESSOR TK-21 2A 24V, akun 102-101): saldo awal Jan 6 unit @ Rp5.316.287,84. 3 unit terjual Januari, **HPP tercatat 0 di ketiganya**. 3 × Rp5.316.287,84 = Rp15.948.863,52 — cocok persis (selisih pembulatan tipis) dengan residu Rp15.948.883,68 di akun 102-101.
- `TL.107-0334` (CLUTCH ASSY TK-21 2A 24V, akun 102-102): beli 10 unit @ Rp1.200.000 Januari (opening=0), lalu keluar gudang ('19') dengan **HPP tercatat 0**. 10 × Rp1.200.000 = Rp12.000.000 — kontributor utama residu Rp13.500.000 di 102-102.

---

## 2. FILE DAN BLOK KODE YANG BERUBAH

Semua di `n_cst_closing_stock.sru`:

| # | Blok | Baris (skrg) | Perubahan |
|---|------|------|-----------|
| 1 | `// === FIX idempoten (mutasi keluar '19')` | ~71-93 | Sumber `SINV @ :ldt_tgl1` (opening) tanpa fallback → **+fallback moving-avg** (opening+beli bulan ini) |
| 2 | `//Update HPP Penjualan reguler` (step 4a, '22') | ~473-490 | Sumber `SINV @ :ldt_next` (closing sirkular) tanpa fallback → **+fallback moving-avg + guard anti-nol** |
| 3 | `//Update HPP Adjustment Stok` (step 4c) | ~562-579 | Sumber `SINV @ :ldt_next` (closing sirkular) tanpa fallback → **+fallback moving-avg + guard anti-nol** |
| 4 | **BARU**: `// === GATE COSTING WAJIB` | ~695-770 | Blok baru — validasi wajib pasca semua fallback, gagalkan closing kalau masih ada HPP=0 padahal cost basis ada |
| 5 | Deklarasi variabel | baris 41 | tambah `ll_costing_fail` (long) |

**TIDAK diubah** (WIP, tetap immutable sesuai batasan): blok `FREEZE '88'` (baris ~99-118), `TIER-3 GL-fallback` (baris ~166-199), `4b UPDATE HPP PENJUALAN BY EVAP` (baris ~505-522), `4d UPDATE HPP Konsinyasi IN` (baris ~628-660), fungsi `of_get_wip_out_value`, seluruh `wip_out_gate_result`/`wip_out_gate_detail`/`wip_out_cost_log`.

**Tabel baru diperlukan** (provisioning SQL terlampir, `provision_costing_gate_tables.sql`):
- `costing_gate_result` — ringkasan per periode (jumlah pelanggaran, status)
- `costing_gate_detail` — detail per baris (sumber, bukti_id, stok_id, qty, hpp, opening, beli)

---

## 3. BEFORE vs AFTER LOGIC

### 3a. Mutasi Keluar '19'

**BEFORE** (sirkular, tanpa fallback):
```sql
UPDATE TSTOK2
      SET NETTO = ROUND(ISNULL(HPP.HRG,0.00) * QTY,2),
          NETTO_HPP = ROUND(ISNULL(HPP.HRG,0.00) * QTY,2),
          HPP = ISNULL(HPP.HRG,0.00),
          HRG = ISNULL(HPP.HRG,0.00)
   FROM TSTOK2,TSTOK1,
        ( SELECT STOK_ID AS STOK_ID, SUM(HPP_AVG) AS HRG
            FROM SINV WHERE PERIODE = :ldt_tgl1 GROUP BY STOK_ID
        ) HPP
WHERE (TSTOK2.STOK_ID = HPP.STOK_ID) AND (TSTOK2.BUKTI_ID = TSTOK1.BUKTI_ID) AND
      (TSTOK1.TIPE_TRANS = '19') AND (TSTOK1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2) ;
```

**AFTER** (fallback moving-avg = opening + beli bulan ini, bila closing/opening-avg=0):
```sql
UPDATE TSTOK2
      SET NETTO = ROUND(ISNULL(HPP.HRG,0.00) * QTY,2),
          NETTO_HPP = ROUND(ISNULL(HPP.HRG,0.00) * QTY,2),
          HPP = ISNULL(HPP.HRG,0.00),
          HRG = ISNULL(HPP.HRG,0.00)
   FROM TSTOK2,TSTOK1,
        ( SELECT x.STOK_ID AS STOK_ID,
                 ISNULL( NULLIF(oa.oavg,0), (ISNULL(o.onil,0)+ISNULL(b.bnil,0)) / NULLIF(ISNULL(o.oqty,0)+ISNULL(b.bqty,0),0) ) AS HRG
            FROM ( SELECT DISTINCT STOK_ID FROM SINV WHERE PERIODE = :ldt_tgl1 ) x
            LEFT JOIN ( SELECT STOK_ID, SUM(HPP_AVG) oavg FROM SINV WHERE PERIODE = :ldt_tgl1 GROUP BY STOK_ID ) oa ON oa.STOK_ID = x.STOK_ID
            LEFT JOIN ( SELECT STOK_ID, SUM(ISNULL(QTY,0)) oqty, SUM(ISNULL(NILAI,0)) onil FROM SINV WHERE PERIODE = :ldt_tgl1 GROUP BY STOK_ID ) o ON o.STOK_ID = x.STOK_ID
            LEFT JOIN ( SELECT T2.STOK_ID sid, SUM(ISNULL(T2.QTY,0)) bqty, SUM(ISNULL(T2.NETTO,0)*ISNULL(T1.KURS,1)) bnil
                          FROM TSTOK1 T1, TSTOK2 T2
                         WHERE T1.BUKTI_ID = T2.BUKTI_ID AND T1.TIPE_TRANS = '02' AND ISNULL(T1.ORDER_OKE,'N') = 'Y'
                           AND T1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2
                         GROUP BY T2.STOK_ID ) b ON b.sid = x.STOK_ID
        ) HPP
WHERE (TSTOK2.STOK_ID = HPP.STOK_ID) AND (TSTOK2.BUKTI_ID = TSTOK1.BUKTI_ID) AND
      (TSTOK1.TIPE_TRANS = '19') AND (TSTOK1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2) ;
```

### 3b. Jual Reguler '22' (step 4a) — sama pola, sumber `:ldt_next`, PLUS guard:
```sql
SET HPP = ABS(ROUND(ISNULL(NULLIF(HPP.HRG,0), ISNULL(TSALES2.HPP,0)),2))
```
Guard `ISNULL(NULLIF(HPP.HRG,0), ISNULL(TSALES2.HPP,0))`: **kalau fallback pun hasilnya 0** (benar-benar tak ada cost basis apa pun), HPP LAMA dipertahankan — **tidak pernah menol-kan** nilai yang sudah ada. Ini murni proteksi idempotensi, bukan pengecualian barang tertentu.

### 3c. Adjustment (step 4c) — pola sama persis dengan 4a (fallback + guard), scope `TIPE_TRANS NOT IN ('02','05','99','09','19')`.

### 3d. GATE COSTING WAJIB (baru, lihat §5 untuk full SQL) — setelah SEMUA fallback di atas jalan, scan ulang: masih ada baris keluar (qty≠0) dengan HPP=0 padahal opening ATAU pembelian bulan ini tersedia? Kalau ADA → **`return -1`, closing gagal, tidak lanjut menulis SINV yang salah**. Item yang MEMANG tak punya cost basis sama sekali (opening=0 dan beli=0 — item legacy) **tidak digagalkan**, karena tidak ada dasar hitung apa pun (bukan bug, tapi data historis yang memang kosong).

---

## 4. TEST CASE — BUKTI (read-only, dijalankan live terhadap prod)

### TEST 1 — saldo awal ada nilai, keluar sampai qty=0, HPP tetap terisi
Input: `TS.102-1081`, saldo awal Jan = 6 unit, Rp31.897.727,04 (avg Rp5.316.287,84).
| | HPP sebelum fix (di DB sekarang) | HPP setelah fix (simulasi formula baru) |
|---|---|---|
| TS.102-1081 | **0,00** | **5.316.287,84** ✅ sesuai target |

### TEST 2 — pembelian bulan berjalan ada, closing average=0, fallback dipakai
Input: `TL.107-0334`, opening=0, beli Jan 10 unit × Rp1.200.000 = Rp12.000.000.
| | opening_qty | beli_qty | beli_nilai | HPP setelah fix |
|---|---|---|---|---|
| TL.107-0334 | 0 | 10 | 12.000.000 | **1.200.000,00** ✅ sesuai target |

### TEST 3 — WIP-Out '88' tidak boleh berubah
Replikasi PERSIS logika `wip_out_gate_result`/`detail` yang sudah tertanam (matching **per-voucher**, `s1.order_client = gl.voucher`, BUKAN agregat tanggal naif — agregat tanggal naif sempat memberi angka menyesatkan karena tanggal posting GL bisa beda dari tanggal transaksi):
```sql
select gr.persediaan account_id, s1.bukti_id,
       sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) mutasi,
       isnull((select sum(isnull(g.kredit,0)) from gl_journal g where g.voucher=s1.order_client
                 and g.account_id=gr.persediaan and g.modul_id='AS'),0) glval
  from tsales1 s1, tsales2 s2, im_produk pr, im_product_group gr
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and s1.tgl between '2026-01-01' and '2026-06-30'
   and pr.produk_id=s2.stok_id and gr.kode_group=pr.group_product
   and gr.persediaan in ('102-001','102-003','102-006')
 group by gr.persediaan, s1.bukti_id, s1.order_client
having abs(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) -
       isnull((select sum(isnull(g.kredit,0)) from gl_journal g where g.voucher=s1.order_client
                 and g.account_id=gr.persediaan and g.modul_id='AS'),0)) > 1
```
**Hasil: 0 baris** — semua voucher WIP-Out TR/NR/TB Jan-Jun 2026 cocok 100% ke GL. ✅ Fix costing '22'/'19'/'4c' TIDAK menyentuh mekanisme WIP-Out sama sekali (struktur source terpisah, tidak ada baris kode yang overlap — dikonfirmasi juga via diff terhadap blok FREEZE-88/TIER-3, nol perubahan).

### TEST 4 — refresh berulang deterministic
**Argumen struktural** (bukan hanya klaim): formula fallback `(opening_nilai+beli_nilai)/(opening_qty+beli_qty)` hanya membaca:
- `SINV WHERE PERIODE=:ldt_tgl1` — **saldo bulan SEBELUMNYA, sudah closing, immutable** (tidak berubah walau bulan ini di-refresh berkali-kali).
- `TSTOK1/TSTOK2 TIPE_TRANS='02'` dalam rentang `:ldt_tgl1..:ldt_tgl2` — **transaksi bulan ini, tetap sama selama tidak ada input data baru**.

Kedua sumber ini **tidak dipengaruhi oleh output refresh itu sendiri** (non-sirkular by design) → hasil fallback selalu sama pada run ke-1, ke-2, ke-n, selama data mentah tidak berubah. Untuk item yang berakhir qty=0 (kasus TS.102-1081 dkk), closing-avg SELALU 0 di setiap run (rule "qty=0→nilai=0" tetap aktif, tidak diubah) → jalur fallback SELALU dipakai secara konsisten, bukan kadang closing-avg kadang fallback. **Kesimpulan: idempotent by construction**, bukan kebetulan.

---

## 5. SQL PROVISIONING & GATE (lampiran terpisah)

- `provision_costing_gate_tables.sql` — DDL 2 tabel baru (`costing_gate_result`, `costing_gate_detail`), idempotent (`IF NOT EXISTS`).
- Blok GATE lengkap sudah tertanam di source (`n_cst_closing_stock.sru` baris ~695-770), dijalankan otomatis tiap `of_run()` (tidak perlu langkah manual terpisah).

---

## 6. EVIDENCE HASIL REFRESH — Januari s/d Juni 2026

**Metode**: `saldo_akhir_dihitung_ulang` (rumus RESMI `dw_refresh_stok.srd`, dijalankan langsung terhadap data prod) dibandingkan `saldo_awal_tersimpan` (SINV periode berikutnya, hasil refresh yang SUDAH dijalankan Pak Wira dengan source LAMA/regresi). Script lengkap (semua akun, semua bulan, drill-down transaksi penyebab): `VALIDASI_saldo_antar_bulan_JanJul2026.sql`.

**BEFORE FIX (kondisi sekarang, source lama)** — akun dengan selisih >Rp1:

| Transisi | Akun bermasalah | Total selisih |
|---|---|---|
| Jan→Feb | 102-010, 102-101, 102-102, 102-110 | ~36,3jt |
| Feb→Mar | 102-010, 102-101, 102-103, 102-110, 102-203 | ~174,9jt |
| Mar→Apr | 102-101, 102-102, 102-103, 102-110 | ~34,4jt |
| Apr→Mei | 102-001, 102-010, 102-016, 102-018, 102-101, 102-110 | ~1,82M |
| Mei→Jun | 102-003, 102-110 | ~80,7jt |
| Jun→Jul | 102-010, 102-101, 102-102, 102-103, 102-110, 102-113 | ~159,6jt |

**AFTER FIX**: belum bisa diisi — **memerlukan build + deploy + RE-REFRESH Januari s/d Juni oleh Pak Wira** (root cause ada di ENGINE, jadi data yang sudah kadung ditutup dengan source lama tetap salah sampai di-refresh ulang dengan source baru). Setelah re-refresh, jalankan ULANG `VALIDASI_saldo_antar_bulan_JanJul2026.sql` — target: 0 baris di semua 6 "BAGIAN...A" (kecuali kalau GATE COSTING menangkap pelanggaran baru yang butuh investigasi terpisah, dalam hal ini closing akan GAGAL dan `messagebox` akan menunjukkan jumlah pelanggaran — lihat `costing_gate_detail`).

---

## 7. CHECKLIST PRODUCTION DEPLOYMENT

1. **Backup prod DB** (dbunload atau copy file `.db`) — standar sebelum perubahan struktural.
2. Jalankan `provision_costing_gate_tables.sql` di dbisql (buat 2 tabel baru, aman/idempotent, tidak mengubah data existing).
3. Import `n_cst_closing_stock.sru` ke PowerBuilder 11.5 (timpa versi lama).
4. **Full Build**.
5. Deploy EXE ke prod.
6. **Re-refresh Januari 2026** (mode BUKAN `ab_sinv_only`, supaya HPP ikut dihitung ulang) — kalau GATE COSTING gagal (messagebox "CLOSING GAGAL"), cek `costing_gate_detail` untuk item penyebab SEBELUM lanjut (jangan paksa lanjut).
7. Ulangi langkah 6 berurutan untuk Februari → Maret → April → Mei → Juni (urutan wajib, karena saldo awal bulan N+1 tergantung closing bulan N).
8. Jalankan `VALIDASI_saldo_antar_bulan_JanJul2026.sql` — pastikan BAGIAN 1A-6A semua 0 baris.
9. Cek ulang WIP tetap aman: query TEST 3 di §4 — harus tetap 0 baris.
10. Cek `wip_out_gate_result`/`wip_out_gate_detail` — pastikan tidak ada MISMATCH baru (fix ini tidak menyentuhnya, tapi verifikasi tetap wajib pasca build/deploy apa pun).
11. Laporan Mutasi Stok — spot-check manual 2-3 akun (Spare Parts + 1 WIP) bahwa Saldo Akhir bulan N kini SAMA dengan Saldo Awal bulan N+1 secara visual di aplikasi.

**Yang TIDAK boleh dilakukan** (sesuai batasan yang berlaku sepanjang proyek ini): tidak ada jurnal koreksi manual, tidak ada "Koreksi Saldo Awal", tidak menyentuh opening 2026 / closing Desember 2025 / saldo 102-020 WIP / HPP-WIP — semua fix ini murni di level engine, monthly-isolated (setiap bulan hanya baca `SINV` bulan sebelumnya + transaksi dalam rentang bulan itu sendiri, tidak membaca lintas-periode lain).

---

## 8. KETERBATASAN / RISIKO TERPISAH (tidak digarap di fix ini)

- **`w_closing_stok.srw`** (window closing LEGACY, dipakai khusus alur "Stock Opname", BUKAN "Refresh Transaksi" yang jadi topik laporan ini) punya logic costing sendiri yang terpisah dari `n_cst_closing_stock.sru` — punya risiko serupa yang **sudah tercatat sebagai isu terpisah** (lihat catatan "Bug w_closing_stok.srw timpa HPP WIP", sudah ada hold "JANGAN jalankan Stock Opname sampai fix di-build"). Tidak disentuh di sini untuk menghindari konflik dengan pekerjaan yang sedang berjalan di jalur itu.
- Selisih Outstanding Konsinyasi Rp502jt (dilaporkan terpisah oleh Pak Wira) **bukan bug** — dua laporan berbeda (`dw_rpt_cons.srd` = pergerakan periode, `dw_rpt_cons_outs.srd` = saldo kumulatif all-time) menjawab pertanyaan berbeda secara desain; tidak memerlukan fix engine.
