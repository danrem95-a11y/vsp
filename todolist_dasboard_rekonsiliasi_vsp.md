# Design Document & TODO — Dashboard Rekonsiliasi VSP
**Aplikasi:** VSP — PowerBuilder 11.5 + SQL Anywhere 9 (ASA9) · DB `vspnew`
**Scope:** Rekonsiliasi Mutasi Saldo **Stok ↔ Ledger** · Mutasi **Hutang (AP) ↔ Ledger** · Mutasi **Piutang (AR) ↔ Ledger**, dengan **drill-down sampai detail transaksi & baris jurnal GL**.
**Sifat dokumen:** blueprint pengembangan setara *system audit finance design*. Semua logika **traceable transaksi → subledger → GL**.
**Versi:** 2.0 · **Status:** Perencanaan (belum coding) — fase analisa/forensik **SELESAI**, dokumen ini = blueprint build.

> **Fondasi yang SUDAH ada (jangan dibangun ulang):**
> - **Kontrak laporan (sumber kebenaran)**: `dw_stok_gl_mutasi` (stok), `dw_rpt_ap_opname` (hutang), `dw_rpt_ar_opname` (piutang), `dw_rpt_ledger1` (ledger). Dashboard **mereplikasi/mereuse** logika ini, bukan menulis ulang.
> - **Engine SQL & konfigurasi**: `rekonsiliasi_engine_vsp.md` (view + `sp_rekon_anomali` R1–R11) & `rekon_finalization_layer.sql` (tabel **`rekon_account_map`** config-driven + view map-driven + GATE).
> - **`rekon_account_map`** SUDAH dideploy (24 baris dari `gl_setup` + `im_product_group`) — zero hardcode akun.
> - **Prototype**: `rekon_dashboard.html` + `rekon_dashboard_gen.ps1` (dashboard read-only di luar app; jadi acuan tata-letak & angka baseline).
> - **Root cause AP/AR sudah terkunci forensik** (14 voucher DP tanpa jurnal GL) → dipakai sbg test-oracle Phase 6.

---

## 1. TUJUAN & PRINSIP

1. Satu layar melihat **selisih (subledger − ledger GL)** per akun/periode untuk 3 domain: **Stok, Hutang (AP), Piutang (AR)**.
2. **Drill-down berjenjang**: Akun → Entitas (group/supplier/customer) → Dokumen/Voucher → Baris `gl_journal` — tanpa keluar aplikasi.
3. **Menemukan sumber selisih cepat**: klasifikasi otomatis penyebab via `sp_rekon_anomali` (R1–R11).
4. **Auditability penuh**: setiap angka ledger tertelusur ke `gl_journal`; setiap angka subledger ke transaksi sumber (`sinv/tstok*/tsales*/ap_trans/ar_trans/tbyr*`).
5. **Read-only murni** — dashboard tak mengubah data. Koreksi lewat modul transaksi/jurnal resmi.
6. **Config-driven, zero hardcode** — semua akun dari `rekon_account_map`/`gl_setup`; satu sumber konfigurasi untuk view & UI.
7. **Cepat** — dashboard baca **snapshot** (`rekon_snapshot_v2`); agregasi transaksi berat hanya saat drill/refresh.

**Persamaan rekonsiliasi (umum):**
```
SELISIH(akun,periode) = SALDO_SUBLEDGER(akun,periode) − SALDO_LEDGER(akun,periode)
SALDO_LEDGER    = GL_BALANCE(YYYY-01-01, akun) [AmountDebet−AmountCredit]
                  + Σ GL_JOURNAL(debet−kredit | posting='P', tahun sama, tgl ≤ eom(periode))
Sehat ⇔ |SELISIH| ≤ Rp 10 (toleransi pembulatan 18-digit ASA9)
```

**Sistem GATE (wajib lulus sebelum angka dipercaya):**
- **GATE#1** — Laporan ↔ View engine konsisten (agregat view = laporan opname per-voucher).
- **GATE#2** — Subledger ↔ GL (kebenaran audit; selisih = anomali riil, harus terklasifikasi).
- **GATE#3** — Integritas mapping akun (`rekon_account_map` = `gl_setup`, anchored=all, tak ada orphan jurnal).

---

## 2. ANALISA KEBUTUHAN SISTEM

### 2.1 Business Process (per domain)

**A. Rekonsiliasi Stok — Mutasi Saldo ↔ Ledger persediaan**
- **Subledger** = laporan mutasi stok (`dw_stok_gl_mutasi`, versi *fixed*): `awal + beli(+ekspedisi) + mutasi_in + consin + consin_by_evap + ret_jual − COGS(jual_real + jual_by_evap) − ret_beli − consout − mutasi_out = akhir`; sumber snapshot `SINV` + transaksi `TSTOK*/TSALES*`.
- **Ledger** = akun persediaan GL, digerakkan modul **PO** (beli), **HP** (COGS), **AS** (adjustment/mutasi '09'/'19'), **EX** (ekspedisi), **CO** (koreksi manual).
- **Rule kunci**: `Σ SINV.nilai per akun PERSEDIAAN = saldo GL akun persediaan`.
- **Valuasi WAJIB konsisten** dg `dw_refresh_stok` fixed: `JUAL` hanya non-EVAP (`ISNULL(EVAP,'')=''`); `JUAL_BY_EVAP = Σ qty×HPP-sendiri`; `CONSIN_BY_EVAP = Σ qty×NETTO-sendiri`; '19' pakai **avg-cost awal bulan** (non-sirkular).

**B. Rekonsiliasi Hutang / AP — Mutasi Hutang ↔ Ledger hutang dagang**
- **Subledger** = opname faktur hutang (`dw_rpt_ap_opname`): daftar faktur beli outstanding per supplier + histori bayar/adjustment.
  `SISA = SALDO_AWAL_FAKTUR + MUTASI(faktur) + ADJ(tbyr2_putih) − BAYAR(tbyr1+tbyr2)` (valuta & IDR paralel).
- **Ledger** = akun hutang dagang `gl_setup.acc_ap` (**226-001**) + freight `gl_setup.acc_biaya_ekpedisi` (**226-006**); digerakkan **PO** (kredit hutang) & **CO** (debet hutang / bayar).
- **Rule**: `Σ SISA faktur outstanding = saldo GL hutang (226-001 + 226-006)`.

**C. Rekonsiliasi Piutang / AR — Mutasi Piutang ↔ Ledger piutang dagang**
- **Subledger** = opname faktur piutang (`dw_rpt_ar_opname`), simetris AP: `SISA = SAF + MUTASI + ADJ − BAYAR`.
- **Ledger** = akun piutang `gl_setup.acc_ar` (**103-001**); digerakkan **SO** (debet piutang) & **CI** (kredit piutang / terima).
- **Rule**: `Σ SISA faktur outstanding per customer = saldo GL piutang (103-001)`.

### 2.2 Data Source (tabel, kolom inti & kunci)

| Domain | Subledger (sumber + kontrak DW) | Ledger (GL) | Master / mapping |
|---|---|---|---|
| **Stok** | `SINV`(PERIODE,STOK_ID,QTY,NILAI,HPP_AVG,SITE_ID); `TSTOK1/2`; `TSALES1/2` · kontrak `dw_stok_gl_mutasi` | `GL_BALANCE`,`GL_JOURNAL` (akun persediaan) | `IM_PRODUK`(PRODUK_ID,GROUP_PRODUCT); `IM_PRODUCT_GROUP`(KODE_GROUP,PERSEDIAAN,HPP,PENJUALAN) |
| **Hutang** | `AP_TRANS`(ORDER_CLIENT,TIPE,tgl); `SALDO_AWAL_FAKTUR`(BUKTI_ID,TIPE_TRANS=2); `TBYR1`(VOUCHER,FLAG_BAYAR,TGL,VOUCHER_MANUAL); `TBYR2`(VOUCHER,BUKTI_ID,NILAI_BAYAR_IDR); `TBYR2_PUTIH`(BUKTI_ID,FLAG_ORDER,NILAI_BAYAR_IDR) · kontrak `dw_rpt_ap_opname` | `GL_BALANCE`,`GL_JOURNAL` (226-001/226-006) | `MCSTSUPP`(VENDOR_ID); `gl_setup` |
| **Piutang** | `AR_TRANS`; `SALDO_AWAL_FAKTUR`(TIPE_TRANS=1); `TBYR1/2`; `TBYR2_PUTIH` · kontrak `dw_rpt_ar_opname` | `GL_BALANCE`,`GL_JOURNAL` (103-001) | `MCUST`(CUST_ID); `gl_setup` |

**Kunci GL (dari analisa live — FAKTA):**
- `GL_BALANCE` = **saldo awal TAHUNAN** per (Periode=`YYYY-01-01`, account_id, site) = `AmountDebet − AmountCredit`.
- `GL_JOURNAL` = mutasi per baris; **`posting='P'`** = terposting; `modul_id` ∈ {PO,HP,AS,EX,CO,SO,CI,SI}; kolom keterusuran `voucher`, `voucher_manual`, `doc_reff`.
- Saldo ledger akhir periode = `GL_BALANCE(tahun) + Σ GL_JOURNAL(debet−kredit)[tahun, tgl ≤ eom, posting='P', site]`.

**Konfigurasi akun (SUDAH ada, zero hardcode):**
- `rekon_account_map(domain, account_type, account_id, site_id, effective_from, is_active)` — deploy 24 baris (21 STOK INVENTORY, AP PAYABLE=226-001, AP PAYABLE_FREIGHT=226-006, AR RECEIVABLE=103-001).
- `gl_setup`: `acc_ar`=103-001, `acc_ap`=226-001, `acc_biaya_ekpedisi`=226-006 (freight), `acc_titipan`=410-047, `acc_lebih_bayar`=228-001, `acc_kurang_bayar`=104-002.

### 2.3 Aturan Rekonsiliasi (formal & traceable)

**Stok — akun persediaan `X`, periode `P`:**
```
LEDGER(X,P)    = GL_BALANCE(year(P),X) + Σ GL_JOURNAL(debet−kredit | account_id=X, posting='P', year(tgl)=year(P), tgl≤eom(P))
SUBLEDGER(X,P) = Σ SINV.NILAI | periode=akhir(P), untuk stok dg IM_PRODUK→IM_PRODUCT_GROUP.PERSEDIAAN=X
```

**Hutang / Piutang — akun `A`, periode `P`:**
```
LEDGER(A,P)    = GL_BALANCE(year,A) + Σ GL_JOURNAL(debet−kredit | account=A, posting='P', ≤eom(P))
SUBLEDGER(A,P) = Σ SISA ; SISA = SALDO_AWAL_FAKTUR + MUTASI − BAYAR + ADJ  (per faktur, valuta & IDR)
```
**Toleransi:** `|selisih| ≤ Rp 10` = "COCOK"; selebihnya "SELISIH".

### 2.4 Kunci Linkage & Traceability (FAKTA terverifikasi — dasar drill)

| Relasi | Kunci | Catatan |
|---|---|---|
| Stok trx → GL | `IM_PRODUCT_GROUP.PERSEDIAAN` → `IM_PRODUK.GROUP_PRODUCT` → `SINV/TSTOK2/TSALES2.STOK_ID` → `TSTOK1/TSALES1.BUKTI_ID` → `GL_JOURNAL(doc_reff/voucher)` | invarian Σ GL = Δ SINV (terbukti April 2026) |
| Faktur AP/AR → GL (anchor) | `GL_JOURNAL.voucher = AP_TRANS/AR_TRANS.ORDER_CLIENT` | AP: 226-001/006 kredit>0 · AR: 103-001 debet>0 |
| Opening faktur | `SALDO_AWAL_FAKTUR.BUKTI_ID = ORDER_CLIENT` (tipe 2=AP,1=AR) | hanya Jan |
| Pembayaran → faktur | `TBYR2.BUKTI_ID = ORDER_CLIENT`, `TBYR1.VOUCHER=TBYR2.VOUCHER`, `FLAG_BAYAR ∈ (1,2)` | — |
| **Pembayaran → GL** | **`GL_JOURNAL.voucher_manual = TBYR1.voucher_manual`** (BUKAN `voucher`) | kunci penting utk R11/GATE#2 |

### 2.5 Katalog Potensi Masalah Data & Anomaly Rules (R1–R11)

| Rule | Masalah | Domain | Deteksi | Severity |
|---|---|---|---|---|
| **R1** | Jurnal belum diposting (`posting≠'P'`) | semua | baris `posting='N'` di periode | HIGH |
| **R2** | Missing ledger (mutasi sub ada, GL kosong) | stok | Δ SINV tanpa jurnal GL | HIGH |
| **R3** | Opening balance gap (mis. MAT: `CO` 2018 tanpa inventory) | stok | `GL_BALANCE − SINV` awal tahun ≠ 0 | HIGH |
| R4 | Akun GL-only (WIP) di luar SINV | stok | akun tanpa `PERSEDIAAN` | INFO |
| **R5** | Loop '19' (`|qty19/akhir|>1`) | stok | rasio qty '19' / saldo akhir | MED |
| R6 | Site mismatch (gl_balance.site ≠ journal.site) | semua | agregasi lintas-site | MED |
| R7 | Payment pending (`TBYR1.flag_bayar=1`) mengurangi sisa | AP/AR | flag pending | INFO |
| R8 | Adjustment putih (`TBYR2_PUTIH`) non-kas | AP/AR | nilai adj periode | INFO |
| **R9** | GL-anchor orphan (jurnal akun kontrol tanpa pasangan subledger) | AP/AR | `NOT EXISTS ap_trans/ar_trans/SAF` | HIGH |
| R10 | Rounding noise (`|selisih|≤10`) | semua | ditangani layer summary | INFO |
| **R11** | **DP application posting gap** — DP kurangi subledger tanpa jurnal GL CI/CO (by `voucher_manual`) | AP/AR | `tbyr` applied `NOT EXISTS gl_journal(CI/CO)` | HIGH |

**Masalah lain (klasifikasi selisih):** posting delay/backdate; salah akun (WRONG_ACCOUNT_CLASS); EVAP dobel-hitung (stok, sudah difix); valas/kurs; closing tak idempoten (roll-forward `bal[y]≠bal[y-1]+jrn[y-1]`).

> **Temuan forensik terkunci (test-oracle):** GATE#2 gap AR +459.861.950 (9 voucher DPR) & AP +1.324.504.398,80 (5 voucher DPB) = 100% **Down Payment tanpa jurnal GL** (R11). Bukan bug engine. Dashboard harus menampilkan 14 voucher ini sebagai "tindakan akuntansi".

---

## 3. ARSITEKTUR & MODUL POWERBUILDER

### 3.1 DataWindow (usulan penamaan)

**Ringkasan (dashboard) — baca snapshot:**
- `dw_rekon_summary` — 1 baris per (domain, akun, periode): subledger, ledger, selisih, status, kategori. (warna merah bila selisih)
- `dw_rekon_kpi` — kartu KPI: jumlah akun cocok/selisih, total nilai selisih per domain, status GATE#1/#2/#3.
- `dw_rekon_trend` — grafik selisih per periode (deteksi kapan mulai menyimpang).

**Drill lvl-1 (per akun):**
- `dw_rekon_stok_akun` — saldo awal + komponen mutasi (beli/COGS/mutasi/consign/adjust) + GL per modul + selisih.
- `dw_rekon_ap_akun` / `dw_rekon_ar_akun` — saldo awal (SAF) + faktur + bayar + adj + saldo akhir vs GL.

**Drill lvl-2 (entitas):** `dw_rekon_stok_group`, `dw_rekon_ap_supplier`, `dw_rekon_ar_customer`.

**Drill lvl-3 (dokumen/voucher):** `dw_rekon_stok_trx`, `dw_rekon_ap_faktur`, `dw_rekon_ar_faktur`.
> **REUSE kontrak**: lvl-3 AP/AR = SQL `dw_rpt_ap_opname`/`dw_rpt_ar_opname` **apa adanya** + filter `vendor_id/cust_id`. **Jangan tulis ulang logika.**

**Drill lvl-4 (jurnal GL — jembatan audit):**
- `dw_rekon_gl_detail` — baris `gl_journal` (tgl, voucher, voucher_manual, modul, debet, kredit, ket, doc_reff) per akun/periode → **titik temu ledger**.
- `dw_rekon_gl_balance` — saldo awal tahunan per akun (`GL_BALANCE`).

**Diagnostik:**
- `dw_rekon_anomali` — hasil `sp_rekon_anomali` (R1–R11) per akun.
- `dw_rekon_dp_gap` — **daftar 14 voucher DP** (R11) sbg to-do akuntansi (voucher, entitas, nilai, akun jurnal usulan).

### 3.2 SQL / query (ASA9 — view + proc, map-driven)

> ASA9: **tanpa** CTE/`WITH`, window function, `*=` outer join, `NOT IN` konkatenasi, `SELECT *`. Host var hanya di WHERE/HAVING (painter). Akun **selalu** dari `rekon_account_map`.

- `v_gl_mutasi_bulan`, `v_gl_opening_tahun`, `v_gl_saldo_periode` — ledger (map-driven).
- `v_stok_saldo_periode` — Σ `SINV.nilai` per persediaan/periode.
- `v_ap_reconcile_final` / `v_ar_reconcile_final` — SISA per vendor/customer (kontrak opname, anchor bayar/adj ke GL). *(sudah didesain di `rekon_finalization_layer.sql`)*
- `v_rekon_summary` — subledger vs ledger → selisih + status per (domain,akun,periode).
- `sp_rekon_anomali(p_domain,p_account,p_tgl1,p_tgl2)` — klasifikasi R1–R11.
- `sp_rekon_build_snapshot` — isi `rekon_snapshot_v2` pasca closing/refresh.

### 3.3 Window design (master-detail berjenjang)

- `w_rekon_dashboard` (master) — tab domain (Stok/AP/AR), filter periode (`d_periode`) & site, grid `dw_rekon_summary` + KPI + GATE. Klik baris → detail.
- `w_rekon_detail_[stok|ap|ar]` (lvl-1/2) — master-detail: akun (atas) → entitas (bawah).
- `w_rekon_trx_[..]` (lvl-3) — dokumen/faktur; tombol "Lihat Jurnal GL".
- `w_rekon_gl_bridge` (lvl-4) — `dw_rekon_gl_detail` + `dw_rekon_gl_balance`: jembatan subledger↔ledger.
- `w_rekon_anomali` — panel diagnostik + tombol "Jelaskan Selisih" + tab "DP Gap (R11)".
- **NVO** `n_cst_rekon` — business logic (hitung selisih, panggil proc, build snapshot) terpisah dari UI.

### 3.4 User Flow (dashboard → detail)
```
[Dashboard Rekon] pilih Domain + Periode + Site
  → grid akun (hijau=cocok / merah=selisih) + KPI + status GATE#1/#2/#3 + trend
  → klik akun selisih
     → Detail domain: saldo awal + komponen mutasi vs GL per modul  (lihat komponen mana beda)
        → klik entitas (group/supplier/customer)
           → daftar dokumen/faktur/transaksi
              → "Lihat Jurnal GL" (bridge lvl-4)  ⇐ titik audit (Σ jurnal = mutasi GL)
        → "Jelaskan Selisih" → panel Anomali (R1–R11) + tab DP-Gap (14 voucher)
  → Export (Excel/PDF) kertas kerja akuntansi
```

---

## 4. TODO LIST IMPLEMENTASI

> Prioritas: **High** = fondasi/tanpa ini fitur tak jalan · **Medium** = fungsional penting · **Low** = penyempurnaan. Dependensi: `dep: <task-id>`.

### Phase 1 — Database & Query Layer
- **[1.1] Verifikasi skema & kunci sumber** — Tujuan: kunci final nama tabel/kolom & 5 kunci linkage (§2.4). Dep: — · **High**
- **[1.2] Finalkan `rekon_account_map`** — Tujuan: pastikan 24 baris map = `gl_setup`+`im_product_group`, `effective_from` benar, `is_active='Y'`; tambah akun GL-only (WIP) sbg dikecualikan. Dep: 1.1 · **High**
- **[1.3] View ledger (`v_gl_opening_tahun`,`v_gl_mutasi_bulan`,`v_gl_saldo_periode`)** — Tujuan: saldo GL akhir periode per akun (map-driven, `posting='P'`), per site. Dep: 1.2 · **High**
- **[1.4] View `v_stok_saldo_periode`** — Tujuan: Σ `SINV.nilai` per persediaan/periode. Dep: 1.2 · **High**
- **[1.5] View mutasi stok (reuse `dw_stok_gl_mutasi` fixed)** — Tujuan: komponen mutasi per akun (EVAP `=''`, JUAL_BY_EVAP own-HPP, CONSIN own-NETTO, '19' non-sirkular). Dep: 1.4 · **High**
- **[1.6] View `v_ap_reconcile_final` & `v_ar_reconcile_final`** — Tujuan: SISA per entitas (kontrak opname; anchor bayar/adj ke GL). Dep: 1.1 · **High**
- **[1.7] View `v_rekon_summary`** — Tujuan: subledger vs ledger → selisih+status per (domain,akun,periode). Dep: 1.3–1.6 · **High**
- **[1.8] Uji korektnes view vs live** — Tujuan: view = angka forensik terbukti (April stok=ledger; AP sub=8.238.241.410,02; AR sub=19.658.007.939,85). Dep: 1.7 · **High**

### Phase 2 — Business Logic Rekonsiliasi
- **[2.1] Formalkan persamaan & toleransi + sign-off dini** — Tujuan: dokumen rule + ambang Rp10, disepakati akuntansi. Dep: 1.7 · **High**
- **[2.2] `sp_rekon_anomali` R1–R11** — Tujuan: implementasi engine klasifikasi (termasuk **R11 DP-gap** by `voucher_manual`, R9 orphan). Dep: 2.1 · **High**
- **[2.3] Rekonsiliasi mutasi (bukan hanya saldo)** — Tujuan: cocokkan gerakan sub vs GL per periode (deteksi gap gaya 647-ribu). Dep: 2.1 · **High**
- **[2.4] Multi-group→1 akun & akun GL-only** — Tujuan: agregasi per akun benar; kecualikan WIP dari uji SINV (R4). Dep: 1.2,2.1 · **High**
- **[2.5] Sistem GATE (#1/#2/#3)** — Tujuan: query gate + status ke KPI; GATE#2 fail ⇒ tampilkan anomali, bukan sembunyikan. Dep: 2.2 · **High**
- **[2.6] `sp_rekon_build_snapshot`** — Tujuan: isi `rekon_snapshot_v2` pasca closing/refresh (dashboard baca snapshot). Dep: 1.7,2.2 · **Medium**
- **[2.7] Kontinuitas periode & valas** — Tujuan: `saldo awal(P+1)=akhir(P)`; pisah selisih kurs bila ada akun valas. Dep: 2.1 · **Medium**

### Phase 3 — DataWindow Design
- **[3.1] `dw_rekon_summary` + `dw_rekon_kpi` + `dw_rekon_trend`** — Tujuan: grid ringkasan + KPI + status GATE + trend. Dep: 1.7,2.5 · **High**
- **[3.2] `dw_rekon_[stok|ap|ar]_akun`** — Tujuan: DW detail per akun (saldo awal, komponen mutasi, GL per modul, selisih). Dep: 1.5,1.6 · **High**
- **[3.3] `dw_rekon_[stok_group|ap_supplier|ar_customer]`** — Tujuan: drill entitas. Dep: 3.2 · **Medium**
- **[3.4] `dw_rekon_[stok_trx|ap_faktur|ar_faktur]`** — Tujuan: drill dokumen; **AP/AR reuse SQL opname + filter entitas**. Dep: 3.3 · **Medium**
- **[3.5] `dw_rekon_gl_detail` + `dw_rekon_gl_balance`** — Tujuan: jembatan audit ke `gl_journal`. Dep: 1.3 · **High**
- **[3.6] `dw_rekon_anomali` + `dw_rekon_dp_gap`** — Tujuan: tampil R1–R11 + daftar 14 voucher DP (to-do). Dep: 2.2 · **High**
- **[3.7] Standar kolom retrieval-arg & format** — Tujuan: arg konsisten (`arg_tgl,arg_tgl2,arg_site,arg_akun,arg_domain`), format `#,##0.00`; **hindari mismatch kolom-def by-position** (pelajaran EVAP/hppx: kolom baru taruh paling akhir). Dep: 3.1 · **High**

### Phase 4 — UI Dashboard PowerBuilder
- **[4.1] `w_rekon_dashboard` (master) + `n_cst_rekon`** — Tujuan: window utama, tab domain, filter periode/site, KPI+GATE; logic di NVO. Dep: 3.1 · **High**
- **[4.2] Visual status** — Tujuan: hijau/merah, badge kategori, lampu GATE, tooltip nilai. Dep: 4.1 · **Medium**
- **[4.3] Navigasi drill (event → OpenWithParm)** — Tujuan: klik baris meneruskan (domain,akun,periode,site) ke window detail. Dep: 4.1,3.2 · **High**
- **[4.4] Filter & pencarian** — Tujuan: filter akun/entitas, cari voucher/faktur/`voucher_manual`. Dep: 4.1 · **Medium**
- **[4.5] Export kertas kerja (Excel/PDF)** — Tujuan: output rekonsiliasi + drill + daftar DP-gap utk audit. Dep: 4.1 · **Medium**

### Phase 5 — Drilldown Detail & Debugging Tools
- **[5.1] Master-detail berjenjang (`w_rekon_detail_*`)** — Tujuan: Akun→Entitas→Dokumen. Dep: 3.2–3.4,4.3 · **High**
- **[5.2] Bridge ke Jurnal GL (`w_rekon_gl_bridge`)** — Tujuan: dokumen → baris `gl_journal` (Σ = mutasi GL). **Titik keterusuran utama.** Dep: 3.5,5.1 · **High**
- **[5.3] Tombol "Jelaskan Selisih"** — Tujuan: panggil `sp_rekon_anomali` utk baris terpilih → penyebab + saran (mis. R11 ⇒ "posting jurnal DP"). Dep: 2.2,3.6 · **High**
- **[5.4] Trace transaksi ↔ jurnal** — Tujuan: hubungkan faktur/transaksi ke jurnal via `voucher`/`voucher_manual`/`doc_reff`. Dep: 5.2 · **Medium**
- **[5.5] Panel DP-Gap (R11) actionable** — Tujuan: 14 voucher DP dg entitas, nilai, akun jurnal usulan (AR kredit 103-001 / AP debet 226-001). Dep: 3.6 · **High**
- **[5.6] Diagnostik built-in** — Tujuan: cek cepat unposted, gap saldo-awal, kontinuitas periode, orphan (R9). Dep: 2.2 · **Medium**

### Phase 6 — Testing & Validasi Data
- **[6.1] Baseline vs data terbukti** — Tujuan: dashboard April 2026 = angka live tervalidasi (stok=ledger; AP/AR benchmark; MAT gap 2018). Dep: 1.8 · **High**
- **[6.2] Oracle forensik AP/AR** — Tujuan: dashboard men-deteksi **tepat 14 voucher DP** (9 AR=459.861.950 + 5 AP=1.324.504.398,80) via R11. Dep: 2.2,6.1 · **High**
- **[6.3] Uji kasus anomali sintetis** — Tujuan: unposted, salah akun, EVAP, loop '19', DP, backdate, orphan → klasifikasi benar. Dep: 2.2 · **High**
- **[6.4] Uji kontinuitas lintas periode** — Tujuan: saldo awal(P+1)=akhir(P) semua domain (terbukti: awal Mei=akhir April). Dep: 2.7 · **High**
- **[6.5] Uji drill end-to-end (traceability)** — Tujuan: selisih → transaksi → voucher GL tanpa putus (uji `voucher_manual` linkage). Dep: 5.2 · **High**
- **[6.6] Rekon silang dg report existing** — Tujuan: cocokkan dg `dw_stok_gl_mutasi`, `dw_rpt_ap_opname`, `dw_rpt_ar_opname`, `dw_rpt_ledger1`. Dep: 6.1 · **High**
- **[6.7] Sign-off akuntansi** — Tujuan: verifikasi angka & definisi oleh finance. Dep: 6.1–6.6 · **High**

### Phase 7 — Optimization SQL Anywhere 9
- **[7.1] Index pendukung** — Tujuan: `gl_journal(account_id,tgl,posting)`, `gl_journal(voucher)`, `gl_journal(voucher_manual)`, `sinv(periode,stok_id)`, `ap_trans/ar_trans(order_client)`, `tbyr2(bukti_id)`, `tbyr1(voucher,flag_bayar,tgl)`; verifikasi index existing. Dep: 1.3–1.6 · **High**
- **[7.2] Ganti pola lambat** — Tujuan: hilangkan `*=` & `NOT IN` konkatenasi (penyebab retrieve >2 menit) → `LEFT JOIN`/`NOT EXISTS`. Dep: 1.5 · **High**
- **[7.3] Snapshot `rekon_snapshot_v2`** — Tujuan: dashboard baca snapshot (instant); re-agregasi hanya saat drill/refresh. Dep: 1.7,2.6,7.2 · **High**
- **[7.4] Update statistics & uji plan** — Tujuan: plan stabil, waktu retrieve terukur. Dep: 7.1 · **Medium**
- **[7.5] Batasi retrieve** — Tujuan: default filter periode/site/akun (jangan tarik ±6.5rb produk sekaligus). Dep: 3.7 · **Medium**
- **[7.6] Jadwalkan DDL saat idle** — Tujuan: hindari blocking vs SHARE lock aplikasi (isolation). Dep: 7.1 · **Low**

### Phase 8 — Deployment & User Training
- **[8.1] Deploy objek DB** — Tujuan: jalankan `rekon_finalization_layer.sql` (map+view+index), `sp_rekon_anomali`, `sp_rekon_build_snapshot` di produksi (urut, saat idle). Dep: fase 1–2,7 · **High**
- **[8.2] Paket build & deploy PB** — Tujuan: import DW/window/NVO ke PBL benar; **full build**; verifikasi PBD/EXE live ter-update (pelajaran: source≠deployed). Dep: fase 3–5,8.1 · **High**
- **[8.3] Checklist verifikasi pasca-deploy** — Tujuan: buka DW di IDE cek SQL; cetak sampel = angka prod; GATE#1–#3 pass di 1 periode. Dep: 8.2 · **High**
- **[8.4] Hak akses & audit-log** — Tujuan: read-only, batasi per role (menu entry `ms_menu`), catat akses. Dep: 8.2 · **Medium**
- **[8.5] Manual & SOP rekonsiliasi bulanan** — Tujuan: cara baca dashboard, drill, tindak-lanjut selisih (termasuk posting DP-gap). Dep: 8.2 · **Medium**
- **[8.6] Training akuntansi & pilot 1 periode** — Tujuan: uji pakai nyata, feedback. Dep: 8.5 · **Medium**
- **[8.7] Handover & pemeliharaan** — Tujuan: dok teknis, katalog anomali hidup, backlog. Dep: 8.6 · **Low**

---

## 5. URUTAN EKSEKUSI (critical path)
`1.1 → 1.2 → 1.3/1.4/1.6 → 1.5 → 1.7 → 1.8 → 2.1 → 2.2 → 2.5/2.6 → 3.1/3.2/3.5/3.6 → 4.1/4.3 → 5.1/5.2/5.3/5.5 → 6.1/6.2/6.5/6.6 → 7.1/7.2/7.3 → 8.1/8.2/8.3`
> Fondasi wajib duluan: **view rekonsiliasi (Phase 1) + `sp_rekon_anomali` (2.2) + GATE (2.5) + bridge GL (3.5/5.2)**. Tanpa ini dashboard tidak *auditable*.

## 6. RISIKO & MITIGASI
- **Performa** (agregasi berat) → snapshot (7.3) + index (7.1) + buang `*=`/`NOT IN` (7.2).
- **Angka tak match (source≠deployed)** → checklist deploy (8.3).
- **Definisi selisih beda dg akuntansi** → sign-off dini (2.1, 6.7).
- **Gap historis (saldo-awal GL, mis. MAT)** → kategori khusus (R3), bukan bug; sediakan jalur "usulan jurnal koreksi".
- **DP tanpa jurnal (R11)** → tampilkan sbg to-do actionable (§5.5), bukan disembunyikan.
- **By-position DataWindow** (pelajaran EVAP/hppx) → kolom-def selaras SELECT; kolom baru paling akhir (3.7).
- **Kesalahan linkage pembayaran** → WAJIB `voucher_manual` (bukan `voucher`) utk cocokkan bayar↔GL (2.4).

## 7. DEFINITION OF DONE
- Dashboard menampilkan selisih per akun/periode 3 domain + status + kategori penyebab + lampu GATE#1/#2/#3.
- Setiap selisih dapat di-drill sampai **baris `gl_journal`** dan **transaksi sumber** (traceable penuh; linkage `voucher`/`voucher_manual`).
- Angka = angka live tervalidasi (baseline April 2026: stok=ledger; AP=8.238.241.410,02; AR=19.658.007.939,85).
- Anomali known (EVAP, loop '19', gap saldo-awal, unposted, orphan, **DP-gap R11**) terdeteksi otomatis; 14 voucher DP tampil sbg to-do.
- Dashboard baca snapshot (cepat); export kertas kerja tersedia; sign-off akuntansi diperoleh.
