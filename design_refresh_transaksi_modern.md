# Reengineering — Refresh Transaksi Jurnal (w_refresh_transaksi_modern)

Sumber lama (LIVE): `w_refresh_journal.srw` (2677 baris, UTF-16). Source-tree copy
`source_powerbuilder_11.5\transfer_data\Window\w_refresh_journal.srw` = **0 byte (export rusak)** —
JANGAN dipakai. Function LIVE = `f_transfer_*.srf` di root (versi `_original`/`_ori`/`_bckp` = pembanding).

Prinsip induk: **hasil jurnal WAJIB 100% identik**. Karena itu strategi = *move code, jangan rewrite*.
Business logic (SQL di function + DataWindow trace) TIDAK disentuh di Fase 1. UI/orkestrasi/monitoring saja.

---

## 1. ANALISA PROSES LAMA

### 1.1 Peta tombol → logika (17 CommandButton)

| Btn | Caption | Visible | Isi event (ringkas) |
|-----|---------|---------|---------------------|
| cb_1 | REFRESH TRANSAKSI | hidden | Gabungan PO+SO+EXP (AR/AP di-comment). Sudah pakai `ib_silent`. |
| cb_3 | AR/AP ONLY | hidden | AR + AP saja. |
| cb_4 | AP | hidden | Loop lama `f_transfer_ap(voucher)` saja (dw_trace_ap_all). |
| cb_5 | **AR** | visible | **Rebuild pembayaran AR**: `d_gl_bayar` → susun tbyr1/tbyr2 (dw_update/dw_sync1/dw_sync2/dw_delete). |
| cb_6 | **EXP** | visible | Loop `f_transfer_ekspedisi_new(order,'EKSPEDISI')` (dw_trace_expedisi_all). |
| cb_7 | **AP** | visible | Loop `f_transfer_ap(voucher)` → lalu **rebuild pembayaran AP** `d_gl_bayar_ap` → tbyr1/tbyr2. |
| cb_8 | **PO** | visible | `f_transfer_po_new(order,'REGULER')` + `'RETUR'` → `f_re_dp_beli()`. |
| cb_9 | **SO** | visible | NVO `n_cst_closing_stock.of_run(...)` → UPDATE HPP avg ke tsales2 → `f_transfer_so` REGULER(+`f_transfer_dpkomisi`+`f_insert_cons_in`) & RETUR(+`f_transfer_dpkomisi`) → `f_re_dp()`. |
| cb_10 | **Non Item** | visible | Loop `f_transfer_nonitempo(order)` (dw_trace_po_nonitem). |
| cb_11 | **Adj.** | visible | Loop `f_transfer_adjustment(order,tipe)` (d_trace_adj_stok_all). |
| cb_12 | Hapus Data GL | visible | `open(w_delete_datagl)` — window terpisah, bukan bagian refresh. |
| cb_13 | **Cons OUT** | visible | Loop `f_transfer_cons(order,'OUT')` (d_trace_consout_all). |
| cb_14 | **Cons IN** | visible | Loop `f_transfer_cons(order,'IN')` → NVO sinkron SINV (`of_run(...,sinv_only)`). |
| cb_15 | DP | hidden | `f_re_dp()` + `f_re_dp_beli()`. |
| cb_16 | Clear Pembayaran | visible | Hapus baris yatim tbyr1/tbyr2 (4 DELETE). |
| cb_17 | Clear Jurnal Memo | visible | Hapus gl_journal non-memo yatim (1 DELETE). |

Window-level subroutine: `f_re_dp()` (DP jual, baris 107–299) & `f_re_dp_beli()` (DP beli, 301–478).

### 1.2 Urutan WAJIB (ditetapkan user — operasional, mengesampingkan urutan turunan kode)

```
1. SO         (cb_9)   : closing stok + HPP avg dulu, baru transfer SO
2. PO         (cb_8)
3. Non Item   (cb_10)
4. EXP        (cb_6)
5. AR         (cb_5)   : rebuild bayar dari gl_journal
6. AP         (cb_7)   : f_transfer_ap + rebuild bayar
7. Adj.       (cb_11)
8. Cons OUT   (cb_13)
9. Cons IN    (cb_14)  : + sinkron SINV
```
Ini urutan operasional yang user pakai selama ini (tiap tombol independen; SO-first aman karena
HPP avg membaca tabel stok mentah tstok1/2, bukan jurnal PO). **Checkbox hanya menggerbang (gate)
modul mana yang jalan; URUTAN eksekusi TETAP seperti di atas.**

### KEPUTUSAN TERKUNCI
1. **Strategi = refactor aman dulu, optimasi Fase 2 tervalidasi** (hasil dijamin identik di Fase 1).
2. **Popup HANYA untuk error fatal** (yang memicu rollback). Konfirmasi/sukses/warning → panel status + log.
   > Implikasi: cukup pindahkan body event **verbatim** + set `ib_silent=true`. Konfirmasi/sukses/warning
   > lama sudah digerbang `if not ib_silent` → otomatis mati. Messagebox error-rollback TIDAK digerbang →
   > tetap tampil = persis "popup hanya error fatal". **Tidak ada baris logika bisnis yang diedit.**

### 1.3 Objek yang dipanggil (dependensi yang WAJIB ikut di window baru)

- **Controls uo_dw**: `dw_arg` (periode+all), `dw_trace` (list+loop), `dw_sync1`, `dw_sync2`,
  `dw_delete` (dw_bukti_delete), `dw_gl` (d_gl_dp), `dw_bayar1` (d_gl_bayar1), `dw_bayar2` (d_gl_bayar2).
- **`dw_update`** dipakai cb_5/cb_7 TAPI tidak ada di control-array window ini → **diwarisi dari ancestor
  `w_frame_main`**. ⇒ window baru WAJIB `from w_frame_main` juga (biar dapat dw_update + dw_leftmenu + ue_slide).
- **DataWindow trace/rebuild**: dw_trace_po_all_reguler/_retur, dw_trace_po_nonitem, dw_trace_expedisi_all,
  dw_trace_so_all_reguler/_retur, d_trace_adj_stok_all, d_trace_consout_all, d_trace_consin_all,
  dw_trace_ap_all, d_re_dp, d_re_dp_beli, d_gl_bayar, d_gl_bayar_ap, d_gl_bayar1/2, d_sync_argl1/2,
  dw_transfer_list, dw_bukti_delete.
- **Functions**: f_transfer_po_new, f_transfer_nonitempo, f_transfer_ekspedisi_new, f_transfer_so,
  f_transfer_dpkomisi, f_insert_cons_in, f_transfer_adjustment, f_transfer_cons, f_transfer_ap,
  f_re_dp, f_re_dp_beli, f_log, f_bom, f_skin_dwlist, gurningsoft_xls.
- **NVO**: `n_cst_closing_stock` (closing stok + sinkron SINV, sudah silent).
- **Temp tables**: tbyr1_copy, tbyr2_copy, t_bukti_delete (dipakai rebuild AR/AP).

### 1.4 Pola commit & masalah performa (akar lambat)

- **Row-by-row**: setiap modul `retrieve` list lalu `FOR i=1..n → f_transfer_x(order)`. Tiap panggilan
  function = beberapa embedded SQL + DELETE + INSERT + **COMMIT per baris**. Ini sumber utama lambat.
- **`f_re_dp` / `f_re_dp_beli`**: di dalam loop ada **7–8 `COMMIT` per baris** (hapus gl_journal, tbyr1,
  tbyr2 varian R/P lalu update 3 DW). Sangat mahal.
- **SELECT-per-row**: cb_5/cb_7 memanggil `select cust_id/vendor_id/curr_id ... where order_client=:x`
  **4× per baris** — bisa dijadikan join sekali.
- **Rebuild AR/AP**: backup ke *_copy + DELETE massal + update dw_sync — pola sudah semi-set-based; aman.
- **Messagebox**: konfirmasi awal (`Yakin melanjutkan?`) sudah digerbang `ib_silent`; tapi banyak
  messagebox **error/warning/sukses tak digerbang** (HPP gagal, closing gagal, sukses AR/AP, PATCH-C dobel,
  cb_17). Ini yang bikin "banyak popup".

### 1.5 Masalah yang dikonfirmasi kode

1. Logic tersebar di 17 event, banyak duplikat (cb_1/cb_3 vs cb_5..cb_14). Sulit maintain.
2. Row-by-row + commit-per-baris → lambat.
3. Popup error/sukses tak konsisten (sebagian digerbang ib_silent, sebagian tidak).
4. Monitoring cuma st_1/st_2/st_3 (satu baris teks) — tak ada progress bar / histori.
5. Tak ada tabel log durasi/jumlah/status.

---

## 2. RANCANGAN WINDOW BARU — `w_refresh_transaksi_modern`

`global type w_refresh_transaksi_modern from w_frame_main` (WAJIB, demi warisan dw_update dsb).

### 2.1 Layout kontrol

```
gb_periode (GroupBox)  : dw_arg (Dari/Sampai/All) — REUSE apa adanya
gb_pilih   (GroupBox)  : cb_so cb_po cb_nonitem cb_exp cb_ar cb_ap cb_adj cb_consout cb_consin (checkbox)
                         cbx_all (Pilih Semua)  cb_clear (Clear)
cb_refresh (Command)   : "REFRESH TRANSAKSI"  (SATU tombol)
gb_progress(GroupBox)  : per modul StaticText + ProgressBar (pb_modul) + pb_total (total)
mle_status (MultiLineEdit, read-only) : status panel ber-timestamp (pengganti semua popup)
--- kontrol tersembunyi (COPY dari window lama, WAJIB ada) ---
dw_trace, dw_sync1, dw_sync2, dw_delete, dw_gl, dw_bayar1, dw_bayar2   (+ dw_update diwarisi)
```

Checkbox → modul: `cb_so cb_po cb_nonitem cb_exp cb_ar cb_ap cb_adj cb_consout cb_consin`.

### 2.2 Instance variables

```powerscript
boolean ib_silent = true          // paksa silent: matikan SEMUA messagebox konfirmasi
long    il_log_id                 // id baris refresh_jurnal_log berjalan
```

### 2.3 Refactor: pindahkan body event → window function (VERBATIM)

Setiap body event tombol lama dipindah **apa adanya** ke function (bukan ditulis ulang):

| Function baru | Sumber body lama | Isi |
|---|---|---|
| `of_refresh_po()` | cb_8 | PO reguler+retur + f_re_dp_beli |
| `of_refresh_nonitem()` | cb_10 | f_transfer_nonitempo |
| `of_refresh_exp()` | cb_6 | f_transfer_ekspedisi_new |
| `of_refresh_so()` | cb_9 | closing NVO + HPP avg + SO reguler/retur + dpkomisi + cons_in + f_re_dp |
| `of_refresh_adj()` | cb_11 | f_transfer_adjustment |
| `of_refresh_cons_out()` | cb_13 | f_transfer_cons OUT |
| `of_refresh_cons_in()` | cb_14 | f_transfer_cons IN + sinkron SINV |
| `of_refresh_ar()` | cb_5 | rebuild bayar AR |
| `of_refresh_ap()` | cb_7 | f_transfer_ap + rebuild bayar AP |

Aturan pemindahan (menjaga identik):
- Baris SQL/loop/urutan **tidak diubah**.
- Konfirmasi `if messagebox('Konfirmasi'...)` sudah digerbang `ib_silent` → otomatis mati.
- Messagebox **error/warning/sukses tak-tergerbang** → ganti `of_status(...)` + tulis ke log.
  (Ini hanya UI; tidak mengubah data jurnal.)
- `st_1/st_2/st_3.text = ...` → dialihkan ke `of_status()` + update progress. Boleh dipertahankan.

### 2.4 Orkestrasi — event `cb_refresh.clicked` (SATU tombol)

```powerscript
datetime ldt1, ldt2 ; long ll_all
dw_arg.accepttext()
ldt1 = dw_arg.object.tgl1[1] ; ldt2 = dw_arg.object.tgl2[1] ; ll_all = dw_arg.object.all1[1]
ib_silent = true
cb_refresh.enabled = false

// URUTAN WAJIB (user) — checkbox hanya gate
if cb_so.checked      then of_run_modul('SO')
if cb_po.checked      then of_run_modul('PO')
if cb_nonitem.checked then of_run_modul('NONITEM')
if cb_exp.checked     then of_run_modul('EXP')
if cb_ar.checked      then of_run_modul('AR')
if cb_ap.checked      then of_run_modul('AP')
if cb_adj.checked     then of_run_modul('ADJ')
if cb_consout.checked then of_run_modul('CONSOUT')
if cb_consin.checked  then of_run_modul('CONSIN')

// list hasil (sama seperti lama)
dw_trace.dataobject='dw_transfer_list'; dw_trace.settransobject(sqlca)
dw_trace.retrieve(ldt1,ldt2,ll_all); f_skin_dwlist(dw_trace)
cb_refresh.enabled = true
of_status('SELESAI. Semua modul terpilih diproses.')
```

`of_run_modul(modul)` = wrapper: tulis START ke `refresh_jurnal_log` → set progress bar modul →
panggil `of_refresh_xx()` dalam TRY-ish (cek sqlca.sqlcode) → tulis END/durasi/jumlah/status.

### 2.5 Status & progress (pengganti popup)

- `of_status(as_msg)`: `mle_status.text = '['+string(now(),'hh:mm:ss')+'] '+as_msg + '~r~n' + mle_status.text`
- Progress per modul: `pb_modul.position = int(i/ll_count*100)` di dalam loop (ganti `st_3.text`).
- `pb_total`: naik per modul selesai (bobot rata / jumlah modul tercentang).
- Error: `of_status('ERROR ['+modul+']: '+sqlca.sqlerrtext)` + rollback + baris log status='ERROR'.
  **Tidak ada messagebox.**

---

## 3. TABEL LOG — `refresh_jurnal_log`

```sql
CREATE TABLE refresh_jurnal_log (
   id             INTEGER      NOT NULL DEFAULT AUTOINCREMENT,
   tgl            TIMESTAMP    DEFAULT CURRENT TIMESTAMP,
   user_id        VARCHAR(20),
   modul          VARCHAR(15),
   periode_awal   DATE,
   periode_akhir  DATE,
   start_time     TIMESTAMP,
   end_time       TIMESTAMP,
   duration_sec   INTEGER,
   jumlah_data    INTEGER,
   status         VARCHAR(10),        -- RUNNING / SUCCESS / ERROR
   error_message  LONG VARCHAR,
   PRIMARY KEY (id)
);
```
START: insert (status RUNNING, start_time). END: update end_time, duration, jumlah_data, status.

---

## 4. VALIDASI "HASIL 100% SAMA" (wajib sebelum dianggap selesai)

Uji: DB dump SEBELUM migrasi → jalankan refresh window LAMA vs window BARU pada periode sama di
2 copy DB → bandingkan. Selisih harus 0.

```sql
-- Per angka total
SELECT count(*) n, sum(debet) d, sum(kredit) k FROM gl_journal WHERE tgl BETWEEN :a AND :b;
-- Per account
SELECT account_id, sum(debet), sum(kredit) FROM gl_journal WHERE tgl BETWEEN :a AND :b GROUP BY account_id;
-- Per modul
SELECT modul_id, count(*), sum(debet), sum(kredit) FROM gl_journal WHERE tgl BETWEEN :a AND :b GROUP BY modul_id;
-- Per voucher (hash pembanding)
SELECT voucher, sum(debet), sum(kredit) FROM gl_journal WHERE tgl BETWEEN :a AND :b GROUP BY voucher;
-- Pembayaran
SELECT count(*), sum(nilai_bayar), sum(nilai_bayar_idr) FROM tbyr2
  WHERE voucher IN (SELECT voucher FROM tbyr1 WHERE tgl BETWEEN :a AND :b);
```
Karena Fase 1 memakai function & SQL yang PERSIS sama (hanya dipindah lokasi), hasil identik *by construction*.
Uji ini adalah bukti/kepastian, bukan sekadar harapan.

---

## 5. PERFORMANCE — rencana BERTAHAP (Fase 2, hanya bila sudah tervalidasi)

Fase 1 TIDAK menyentuh SQL → aman. Optimasi = Fase 2, tiap perubahan wajib lolos §4 (selisih=0).

### 5.1 Index kandidat (dari SQL nyata di window; verifikasi via `sa_get_table_pages`/plan dulu)
- `gl_journal(voucher_manual)` — dipakai berulang di cb_5/cb_7 & subquery yatim.
- `gl_journal(voucher, urut)` — cb_17, f_re_dp.
- `tbyr1(tgl, kas_id, voucher_manual)` — patch yatim + backup copy.
- `tbyr1(voucher)` , `tbyr2(voucher)` , `tbyr2(bukti_id)` — join & delete rebuild.
- `ar_trans(order_client)` , `ap_trans(order_client)` — SELECT-per-row cb_5/cb_7.
- `tsales1(tgl, order_oke, tipe_trans)` , `tstok1(tgl, order_oke)` — UPDATE HPP avg cb_9.
> Konfirmasi dulu index eksisting sebelum buat baru (jangan duplikat). Gunakan 32-bit ODBC DSN=vsp.

### 5.2 Rewrite set-based yang AMAN (kandidat, tetap harus divalidasi selisih=0)
- SELECT cust_id/vendor_id/curr_id per-row (cb_5/cb_7) → join sekali di DataWindow d_gl_bayar(_ap).
- `f_re_dp` / `f_re_dp_beli`: kurangi COMMIT-per-baris → 1 commit per batch/akhir modul.
- Row-by-row `f_transfer_*`: hanya di-batch bila terbukti identik; ini paling berisiko → terakhir.

### 5.3 UPDATE STATISTICS
Jalankan `CREATE STATISTICS` pada tabel besar (sinv, tsales1/2, tstok1/2, gl_journal, tbyr1/2)
sebelum benchmark (non-destruktif).

---

## 6. RENCANA EKSEKUSI

- **Fase 1 (aman, hasil identik):** buat `w_refresh_transaksi_modern.srw` (copy kontrol tersembunyi +
  dw_arg dari window lama), tambah checkbox + 1 tombol + progress + status + `of_*` (body verbatim),
  tabel `refresh_jurnal_log`. Import + Full Build + uji §4.
- **Fase 2 (perf, tervalidasi):** index → statistics → rewrite set-based bertahap, tiap langkah lolos §4.

Deploy: window baru di-import ke PBL `transfer_data`, tambah menu, Full Build (pola: re-import + Full Build).
Window lama `w_refresh_journal` DIPERTAHANKAN sbg fallback sampai Fase 1 lolos verifikasi.

---

## 7. STATUS — FASE 1 SUDAH DI-GENERATE

File dihasilkan: **`w_refresh_transaksi_modern.srw`** (UTF-16LE + BOM + CRLF, format export PB 11.5).
Cara pembuatan = *extract verbatim* body event lama (byte-faithful) → dibungkus jadi `of_refresh_*`,
NOL baris logika bisnis diketik ulang ⇒ hasil jurnal identik by construction.

Isi yang sudah ada di file:
- Turunan `w_frame_main` (dapat `dw_update`, `dw_leftmenu`, dll).
- 9 checkbox modul + `cbx_all` (Pilih Semua) + `cb_clear` + 1 tombol `cb_refresh`.
- Progress: `hpb_modul` (per modul) + `hpb_total` (total, +1 per modul selesai) + `st_modul`.
- Panel status `mle_status` (read-only, timestamp, terbaru di atas) + `st_1..st_4` (dipakai body lama).
- Fungsi: `f_re_dp`, `f_re_dp_beli` (verbatim), `of_refresh_so/po/nonitem/exp/ar/ap/adj/cons_out/cons_in`
  (verbatim dari cb_9/8/10/6/5/7/11/13/14), `of_status`, `of_log_start`, `of_log_end`, `of_run_modul`.
- Hidden helper DW: dw_arg, dw_trace, dw_sync1/2, dw_delete, dw_gl, dw_bayar1/2.
- `ib_silent=true` (default) ⇒ konfirmasi/sukses/warning mati; hanya error-fatal yang popup.

### Langkah import (PB IDE)
1. Jalankan dulu `RUNBOOK_refresh_jurnal_log.sql` (buat tabel log) di dbisql.
2. PB IDE → Library painter → PBL `transfer_data` → **Import** `w_refresh_transaksi_modern.srw`.
3. Full Build. (Jika import gagal krn 1 properti kontrol, buat kontrol via painter lalu paste script
   dari file ini — fallback painter.)
4. Tambah menu pemanggil: `open(w_refresh_transaksi_modern)`.

### Verifikasi identik (WAJIB sebelum ganti window lama)
- 2 copy DB dari dump yg sama. Copy-A: refresh via window LAMA. Copy-B: window BARU. Periode identik.
- Jalankan query pembanding bagian §4 pada kedua DB → semua selisih HARUS 0.
- Window lama `w_refresh_journal` tetap ada sbg fallback sampai lolos.

### Batas Fase 1 (jujur)
- Progress bar = level MODUL (total naik per modul; bar modul 0→100 saat modul jalan). Progress per-baris
  (mis. SO delete/insert %) = Fase 2 (perlu hook kecil di dlm loop, tak ubah logika).
- `jumlah_data` di log = delta count gl_journal periode (AR/AP menyentuh tbyr → delta bisa ~0).
- Layout tidak reposition saat left-menu slide (kosmetik; bisa ditambah event resize nanti).

---

## 8. REDESIGN UI ENTERPRISE (v2 — sudah di-generate)

`w_refresh_transaksi_modern.srw` di-regenerate dengan tampilan enterprise. **Logika 100% tetap**:
`of_refresh_*`, `f_re_dp/beli` VERBATIM tak berubah; kontrol yang mereka baca (`dw_arg`, `dw_trace`,
`dw_sync1/2`, `dw_delete`, `st_1/st_4`, `dw_update`) dipertahankan sbg **worker tersembunyi**. Yang baru: layout, warna, nama kontrol UI, orkestrasi.

### Mockup (satu layar, 2 kolom + hasil di bawah)
```
+============================================================================+   navy band
|  REFRESH TRANSAKSI JURNAL                                                  |   (st_title)
|  Generate ulang jurnal transaksi berdasarkan periode & modul yang dipilih  |   (st_subtitle)
+============================================================================+
| KIRI (konfigurasi)                     | KANAN (monitor)                    |
| +-- Periode Transaksi --------------+  | +-- Status Proses ---------------+ |
| | Dari   [01-07-2026]               |  | | Modul berjalan  [####____] 60% | |
| | Sampai [31-07-2026]  [ ] Semua    |  | | Total progress  [######__] 75% | |
| +-----------------------------------+  | | Processing PO ...   (st_2)     | |
| +-- Pilih Modul Refresh ------------+  | | Checking row 120/300 (st_3)    | |
| | [SO ]  [PO ]  [Non Item]          |  | +--------------------------------+ |
| | Sales  Purch  Non-Item            |  | +-- Process Log -----------------+ |
| | [EXP]  [AR ]  [AP ]               |  | | [10:01:01] MULAI SO            | |
| | [Adj]  [ConsOUT][ConsIN]          |  | | [10:03:25] OK SO (delta=1250)  | |
| |   [Pilih Semua]   [Reset]         |  | | ...            (mle_log)       | |
| +-----------------------------------+  | +--------------------------------+ |
| |         MULAI REFRESH  (navy)     |  |                                    |
+============================================================================+
|  Hasil Refresh (Data Result)                                               |
|  [ dw_result : Voucher | Manual | Tgl | Modul | Account | Debet | Kredit ]  |
+============================================================================+
```

### Struktur object (60 kontrol) — nama & fungsi
| Object | Tipe | Fungsi |
|--------|------|--------|
| st_title / st_subtitle | statictext (band navy) | header judul + subjudul |
| gb_period | groupbox | bingkai periode |
| dt_from / dt_to | editmask (datemask dd-mm-yyyy) | tanggal Dari/Sampai |
| cb_all_period | checkbox | semua periode (disable dt saat dicentang) |
| gb_module | groupbox | bingkai pilih modul |
| gb_card_xx + cb_xx + st_xx | groupbox+checkbox+statictext | 9 KARTU modul (SO,PO,Non Item,EXP,AR,AP,Adj,ConsOUT,ConsIN); klik deskripsi = toggle |
| cb_select_all / cb_reset | commandbutton | pilih semua / reset |
| pb_refresh | statictext (navy, raised) | tombol PRIMARY "MULAI REFRESH" (clicked event) |
| gb_progress | groupbox | bingkai status |
| pb_progress_current / pb_progress_total | hprogressbar | progres modul & total |
| st_2 / st_3 | statictext | activity headline / detail baris (live) |
| gb_log + mle_log | groupbox + multilineedit(readonly,courier) | log ber-timestamp (terbaru di atas) |
| st_result_lbl + dw_result | statictext + uo_dw(dw_transfer_list) | grid hasil |
| dw_arg,dw_trace,dw_sync1/2,dw_delete,dw_gl,dw_bayar1/2,st_1,st_4 | hidden worker | dipakai logika verbatim |
| dw_update | inherited w_frame_main (hidden) | rebuild AR/AP |

Koordinat (PBU): band header y=28/132; KIRI x=1166 w=1880 (periode 244, modul 650, tombol 1764);
KANAN x=3106 w=1960 (status 244, log 850); hasil full-width y=2016 h=724. Window 5230×2900.

### Warna korporat
Navy `6697728` (RGB 0,51,102) untuk band/judul/primary button/judul groupbox. Teks label `4210752`
(abu gelap), deskripsi kartu `8421504` (abu). Background window & field putih `16777215`. Tanpa warna mencolok.

### Event script (dibuat)
- `open`: init dt_from/dt_to = f_bom/f_eom(hari ini), reset progress+log.
- `resize`: stretch `dw_result` (width & height ikut window).
- `cb_all_period.clicked`: enable/disable dt_from/dt_to.
- `st_xx.clicked` (9): toggle checkbox kartu.
- `cb_select_all.clicked` / `cb_reset.clicked`: centang/hapus 9 modul.
- `pb_refresh.clicked`: baca dt→dw_arg, hitung modul, jalankan URUTAN WAJIB via `of_run_modul`, tampilkan `dw_result`.
- `of_run_modul` → `of_update_progress` (bar+st_2) + `of_write_log` (mle_log) + `of_log_start/end` (DB log).

### Saran usability (diterapkan)
1. Alur kiri→kanan→bawah = urutan kerja (1 pilih periode, 2 pilih modul, 3 refresh, 4 monitor, 5 hasil).
2. Kartu modul menampilkan kode + deskripsi → user finance langsung paham.
3. Urutan kartu = urutan proses (SO→...→ConsIN) → mengajarkan workflow.
4. Tanpa popup (kecuali error fatal); semua status di panel + log.
5. Primary button navy menonjol; Reset sekunder abu.

### Catatan implementasi
- Tanggal via **editmask datemask** + parse manual `Date(yyyy,mm,dd)` (locale-independent) → tulis ke
  `dw_arg` (jembatan) yang dibaca logika. `dw_arg` di-hidden (constructor tetap isi baris default).
- `pb_refresh` = statictext bergaya tombol (PB 11.5 CommandButton tak bisa diberi warna) → tampil "primary".
- Backup v1 window ada di scratchpad (`w_refresh_transaksi_modern.v1.srw.bak`).

---

## 9. REFINEMENT v3 (FINAL — enterprise finance, sudah di-generate)

Menggantikan v2. **Logika tetap verbatim/identik.** Layout **kuadran 2×2** (header tipis, bukan band dominan):

```
↻  Refresh Transaksi Jurnal                                    (st_header, navy, tipis)
Generate ulang jurnal transaksi berdasarkan periode & modul     (st_subtitle, abu)
================ accent line navy (st_accent) ==================
+-- Periode Transaksi ------+   +-- Status Proses --------------+
| Dari   [01-07-2026]       |   | Modul berjalan : SO           |
| Sampai [31-07-2026]       |   | Progress modul [######--] 75% |
| [ ] Semua Periode         |   | Progress total [####----] 50% |
+---------------------------+   | Insert jurnal SO...  (st_2)   |
+-- Pilih Modul Refresh ----+   | Checking row 120/300 (st_3)   |
| SO           PO           |   | Waktu: 00:05:30  Status:OK    |
| Sales Order  Purchase     |   +-------------------------------+
| Non Item     EXP          |   +-- Process Log ----------------+
| ...          ...          |   | [10:01] System ready          |
| Cons IN                   |   | [10:02] MULAI SO              |
| [Pilih Semua]   [Reset]   |   | [10:03] OK SO (jurnal +1250)  |
+---------------------------+   +-------------------------------+
                 [ ▶  MULAI REFRESH ]   (navy primary, tengah)
Hasil Refresh   Total Voucher:1.250  Total Debit:10.5jt  Total Kredit:10.5jt
[ dw_result : Voucher | Modul | Account | Debet | Kredit ]
```

**Perubahan kunci v3 vs v2:**
- Header **tipis** (title `st_header` + subtitle + garis accent `st_accent`) — bukan band navy penuh. Ikon `↻`.
- Modul = **2 kolom, tanpa border kartu** (checkbox kode bold + deskripsi abu; "jangan banyak garis"). Nama: `cb_so/po/nonitem/exp/ar/ap/adj/consout/consin` (+ `st_<nama>` deskripsi, klik = toggle).
- Progress bar rename → `pb_module` + `pb_total`. Status diperkaya: `st_current` (modul berjalan),
  `st_2`/`st_3` (aktivitas & baris live dari verbatim), `st_elapsed` (timer HH:MM:SS via SecondsAfter),
  `st_status` (badge RUNNING=oranye / SUCCESS=hijau / ERROR=merah).
- Log `mle_log` = **append di bawah + auto-scroll** (`selecttext(len+1,0)`), font Consolas fixed.
- Tombol `pb_refresh` = **guard `ib_running`** → saat proses teks jadi "PROCESSING...", selesai balik "▶ MULAI REFRESH".
- Result: **summary footer** `st_total_voucher` / `st_total_debit` (hijau) / `st_total_credit` (hijau) —
  `select count(distinct voucher),sum(debet),sum(kredit)` periode setelah refresh. Grid `dw_result` proporsional.
- Warna korporat: navy `6697728`; sukses hijau `32768`; warning oranye `36095`; error merah `197`; teks abu `4210752`/`8421504`; bg putih `16777215`. Font **Segoe UI** (label) + **Consolas** (log).
- Elapsed & repaint antar-modul via `yield()` di `of_run_modul` (bukan Timer, agar andal tanpa ubah loop verbatim).
- Koordinat: window 5230×2820; KIRI x=1166 w=1900, KANAN x=3126 w=1920; top-row y=200 h=440, bottom-row y=670 h=1000; tombol tengah x=2406 y=1710; hasil full-width y=1962 h=700 (di-stretch saat resize).
- Backup: v1 & v2 di scratchpad (`*.v1.srw.bak`, `*.v2.srw.bak`).

**Batas jujur (tetap):** progress live per-baris hanya tampak saat verbatim ber-`yield()` (AR/AP); modul
tanpa yield tampil update di batas modul. Elapsed = akurasi detik di batas modul. `▶`/`↻` unicode (PB 11.5
Unicode) — jika environment menolak, ganti teks ASCII 1 baris.
