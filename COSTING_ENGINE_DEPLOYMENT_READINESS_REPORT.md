# COSTING ENGINE DEPLOYMENT READINESS REPORT

Tanggal: 2026-08-11

## STATUS: **NOT READY DEPLOY**

Alasan tunggal: **belum ada satu pun eksekusi live** (build + deploy + jalankan di aplikasi sungguhan). Seluruh bukti di bawah ini adalah code review + simulasi SQL terhadap data prod nyata (read-only) — kuat secara logika dan matematika, tapi **bukan pengganti** uji nyata lewat compiled EXE. Saya tidak punya akses compiler PowerBuilder, jadi status READY tidak bisa saya klaim jujur sampai Bapak build & jalankan sendiri.

---

## Tabel Skenario

| Scenario | Expected | Result (bukti) | Status |
|---|---|---|---|
| WIP-Out ambil average periode | HPP EVAP = average bulan transaksi | RC1: formula baru = 253.714.366,49 = HPP tersimpan (TR.038A, 6 EVAP April) | ✅ Terbukti (SQL, real data) |
| Purchase memengaruhi average | (200rb+400rb)/(100+100)=3000 | RC2: hasil aritmatika = 3.000,00 persis | ✅ Terbukti (matematika murni) |
| Backdate correction → rebuild | Average berubah, SEMUA EVAP asal bulan itu ikut berubah | RC3: 6 EVAP April sama-sama bergeser 253,7jt→260,3jt (hipotesis +Rp300jt); 6 penjualan real yg pakai EVAP ini teridentifikasi utk cascade 4b | ✅ Terbukti logika+data (BUKAN dieksekusi live) |
| EVAP immutable (scope periode) | Refresh Agustus TIDAK sentuh EVAP Juli | WHERE `TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2` — struktural, hanya bulan yg direfresh yg match | ✅ Terbukti (code review) |
| Refresh tak tergantung checkbox | ConsOUT saja tetap trigger costing | Baris 3025-3049 `w_refresh_transaksi_modern.srw`: costing SELALU jalan sebelum baris 3050 (dispatch checkbox) | ✅ Terbukti (code review) |
| Journal rebuild ikuti costing terbaru | Delete lalu insert journal baru | `f_transfer_cons.srf` baris 221-224: delete+insert, sumber HPP dari TSALES2 (baris 80) — TIDAK berubah, sudah benar sejak awal | ✅ Terbukti (code review, tidak diubah krn sudah sesuai) |
| Ledger 102-020 balance | Konsisten dgn hasil costing | 0 inkonsistensi step 4b di SELURUH Jan-Jun; saldo GL 102-020 tidak bisa dibandingkan 1:1 ke "Outstanding Jan-Jun" krn beda cakupan (GL kumulatif sejak sebelum 2026) — **BUKAN kegagalan, tapi keterbatasan cakupan uji** | ⚠️ Terbukti sebagian (lihat catatan) |
| Old refresh (w_refresh_journal) redirect | Redirect ke modern, tidak jalankan logic lama | `event open` baru: messagebox+`Open(w_refresh_transaksi_modern)`+`close(this)`; tidak terdaftar di menu manapun (`sysleftmenu`, `SYS_PROGRAM` dicek 0 hasil) | ✅ Terbukti (code review + DB) |

---

## Bukti Detail per Root Cause

### RC1 — WIP-Out pakai average periode ✅
Simulasi SQL memakai formula BARU (dari source aktif) terhadap 6 EVAP TR.038A April 2026 nyata:
```
opening_nilai=1.522.286.198,94 / opening_qty=6 / beli=0
formula_baru = 1.522.286.198,94 / 6 = 253.714.366,49
```
= **PERSIS SAMA** dengan `hpp_tersimpan_sekarang` untuk keenam EVAP. Ini bukan kebetulan — nilai ini adalah hasil koreksi manual Round 1-3 sebelumnya yang SUDAH memakai metodologi identik; kecocokan ini membuktikan formula baru di source SAMA dengan metodologi yang sudah divalidasi.

### RC2 — Average memasukkan transaksi bulan berjalan ✅
Verifikasi aritmatika murni (bukan simulasi data, murni cek rumus):
```sql
(200000+400000)/(100+100) = 3000.00  -- COCOK PERSIS contoh Bapak
```
Formula di source (`n_cst_closing_stock.sru` baris 509, 157, dst): `(opening_nilai+beli_nilai)/(opening_qty+beli_qty)` — identik strukturnya.

### RC3 — Backdate correction menyebabkan rebuild ✅ (logika+data, BELUM live)
Basis nyata TR.038A April (opening 6 unit/Rp1.522.286.198,94, beli=0 di bulan itu sekarang):
- Hipotesis: +1 unit koreksi plus Rp300.000.000 di bulan yg sama →
  `average_baru = (1.522.286.198,94+300.000.000)/(6+1) = 260.326.599,85`
- **Dibuktikan SEMUA 6 EVAP** (bukan sebagian) akan menerima nilai baru yang SAMA — karena WHERE clause tier1/4a/4c tidak filter per-EVAP, semua baca dari SATU baris `costing_helper_movavg` per stok_id+bulan.
- **Ditemukan bukti cascade nyata**: 6 transaksi penjualan REAL (bukan hipotesis) sudah memakai EVAP-EVAP ini — 5 tanggal April, **1 tanggal Mei** (CIM1090964, terjual 04/05/2026... koreksi: 05/04/2026). Ini catatan PENTING: cascade ke penjualan Mei HANYA akan ikut ter-update kalau Mei JUGA ikut direfresh (bukan April saja) — sesuai desain (scope = rentang refresh), tapi Bapak perlu tahu ini bukan otomatis lintas-bulan tanpa refresh eksplisit bulan itu.

**Batasan jujur**: ini adalah simulasi ARITMATIKA di atas data REAL, BUKAN transaksi backdate yang benar-benar dieksekusi lewat aplikasi. Saya tidak menyuntik data uji ke prod (melanggar prinsip proyek). Uji SESUNGGUHNYA wajib dilakukan Bapak: input koreksi plus asli di test/staging, jalankan refresh, cek hasilnya cocok prediksi di atas.

### RC4 — Refresh Cons OUT saja tetap trigger costing ✅
`w_refresh_transaksi_modern.srw` baris 3025-3049 (blok costing, SELALU dieksekusi) letaknya SEBELUM baris 3050 (`if cb_so.checked then...` — dispatch pertama). Tidak ada jalur untuk skip blok ini.

### RC5 — Dua engine aktif → sekarang SATU ✅
- `w_refresh_journal.srw`: `event open` baru menutup window SEBELUM tombol apa pun (termasuk yang berisi formula lama) bisa diklik — formula lama jadi dead code at runtime.
- Dikonfirmasi lewat DB: `w_refresh_journal` **tidak terdaftar di `sysleftmenu`** (menu navigasi aktual) maupun `SYS_PROGRAM` — 0 baris. Tidak ada jalur menu resmi menuju window ini.

### RC6 — Immutable diimplementasi dgn benar (per-periode, bukan permanen) ✅
Guard lama `ISNULL(HPP,0)=0` (permanen, salah paham) sudah diganti dgn batasan `TSALES1.TGL BETWEEN :ldt_tgl1 AND :ldt_tgl2` (per-periode, benar) — dikonfirmasi via code review baris 158-162.

---

## Checkpoint Code Review (Ringkas)

| File | Bukti |
|---|---|
| `n_cst_closing_stock.sru` | Formula average final baris 157/509/569 (identik, non-sirkular); tier1 FREEZE baris 152-162 (scope periode); update EVAP di baris yg sama, tanpa guard HPP status |
| `w_refresh_transaksi_modern.srw` | Urutan final: baris 3025 costing (selalu) → 3050+ dispatch modul (checkbox) → (di luar scope perubahan ini) journal rebuild via `f_transfer_cons` per modul |
| `w_refresh_journal.srw` | Baris 543-547: `event open` → messagebox → `Open(w_refresh_transaksi_modern)` → `close(this)`. Status: OBSOLETE/REDIRECT ONLY, terverifikasi |
| `f_transfer_cons.srf` | Baris 221-224: delete+insert journal, sumber HPP baris 80 dari TSALES2 (via `d_trace_consout`) — tidak diubah, sudah sesuai |

---

## Database Reconciliation Test

| Cek | Hasil |
|---|---|
| Penjualan HPP ≠ EVAP asal '88' (Jan-Jun, SELURUH data bukan cuma yg dikoreksi) | **0 baris** ✅ |
| WIP Outstanding Jan-Jun (14 unit belum terjual) | Rp643.787.759,92 |
| Saldo GL 102-020 akhir Juni (kumulatif sejak sebelum 2026) | Rp1.388.098.743,26 — **selisih dgn Outstanding Jan-Jun BUKAN error**, beda cakupan waktu (sudah dikonfirmasi pola ini normal di sesi-sesi sebelumnya) |

---

## Yang TIDAK Boleh Diklaim READY Sampai Terbukti

- [ ] Build PowerBuilder berhasil tanpa error compile
- [ ] Refresh Juli nyata (test/staging) → EVAP tetap 2.000 kalau tidak ada perubahan data (idempotency LIVE, bukan simulasi)
- [ ] Input koreksi plus asli + refresh Juli asli → average berubah ke 3.000 SESUAI prediksi RC3
- [ ] Buka `w_refresh_journal` lewat cara apa pun di app yg sudah di-build → pesan+redirect benar-benar muncul
- [ ] Refresh dgn HANYA checkbox Cons OUT tercentang → costing tetap jalan (observasi log/waktu proses bertambah)
- [ ] Regresi: seluruh 63 baris TR+NR yang sudah dikoreksi manual sesi-sesi sebelumnya, setelah build baru + refresh ulang, KONVERGEN ke nilai yang sama (tidak berubah lagi)

## Rekomendasi Langkah Berikut

1. Build PowerBuilder (Full Build, bukan cuma syntax check).
2. Deploy ke **salinan test DB** dulu (bukan langsung prod) — sesuai praktik yang sudah pernah dipakai proyek ini (`dbunload` non-destruktif).
3. Jalankan ke-6 checklist di atas satu per satu di test DB.
4. Kalau semua lolos → baru pertimbangkan deploy prod, dan re-refresh Jan-Jun penuh secara berurutan sambil dipantau (bukan langsung dianggap selesai).

**Kesimpulan**: perubahan source SECARA LOGIKA DAN MATEMATIKA sudah menjawab keenam root cause, didukung bukti dari data prod nyata. Tapi tanpa satu pun eksekusi live, saya tidak bisa dan tidak akan menyatakan READY DEPLOY.
