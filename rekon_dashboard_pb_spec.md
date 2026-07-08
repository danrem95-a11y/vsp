# REKON DASHBOARD — PRODUCTION PB 11.5 LAYER SPEC
**Target:** PowerBuilder 11.5 + SQL Anywhere 9 (ASA9) · DB `vspnew`
**Sifat:** presentation layer murni. **TIDAK** ada perhitungan di window — semua angka dari `v_rekon_*` / `sp_rekon_anomali` / `rekon_snapshot_v2`. **TIDAK** ada literal `account_id`/periode/nilai — semua parameter/config dari `rekon_account_map`.
**Prasyarat objek DB (sudah ada):** `v_rekon_stok_final`, `v_rekon_ap_final`, `v_rekon_ar_final`, `v_rekon_gl_bridge`, `v_rekon_summary_kpi`, `v_ap_sisa_vendor`, `v_ar_sisa_cust`, `v_stok_saldo_periode`, `rekon_snapshot_v2`, `sp_rekon_anomali`, `sp_rekon_snapshot_build`, `rekon_account_map`, kontrak `dw_rpt_ap_opname`/`dw_rpt_ar_opname`.

> **Catatan kolom master (bukan COA):** join nama vendor/customer/akun (mis. `MCSTSUPP`/`MCUST`/`GL_ACC`) adalah *lookup opsional*. Kolom kunci yang dipakai & dijamin ada: `v_ap_sisa_vendor.vendor_id`, `v_ar_sisa_cust.cust_id`, `v_rekon_stok_final.account_id`. Nama deskripsi = enhancement; verifikasi kolomnya ke skema sebelum ditambah (ditandai `/*LOOKUP*/`). Dashboard tetap fungsional penuh tanpa nama.

---

## 1. WINDOW ARCHITECTURE (PB 11.5)

Semua window turun dari `w_main` app-standard (inherit toolbar/txn `SQLCA`). Parameter antar-window via `OpenWithParm()` memakai **structure** `str_rekon_ctx` (bukan global var):

```
str_rekon_ctx:
   string  s_domain      // 'STOK' | 'AP' | 'AR'  (dari ddw_domain / map)
   string  s_site        // site_id | '*'         (dari ddw_site / map)
   long    l_thn         // tahun periode
   integer i_bln         // bulan periode
   date    d_periode     // YYYY-MM-01 (untuk snapshot)
   string  s_account     // account_id (hasil drill; asal view/map)
   string  s_entity      // vendor_id | cust_id (hasil drill)
   string  s_voucher     // voucher | voucher_manual (hasil drill)
```

### 1.1 `w_rekon_dashboard` — MAIN CONTROL CENTER
- **Fungsi bisnis:** ringkasan 3 domain untuk 1 periode + status GATE#1–3; pintu masuk semua drill. Tidak menghitung — baca `rekon_snapshot_v2`.
- **DataWindow:** `dw_rekon_summary` (grid 3 baris domain), `dw_filter_bar` (DDDW: domain/site/period). Opsional trend: `dw_rekon_snapshot_v2` (mode all-period).
- **Data source:** `rekon_snapshot_v2` (via `dw_rekon_summary`).
- **Filter logic:** `:arg_periode` = `d_periode` dari `ddw_period` (config, distinct dari snapshot). Domain/site dari `ddw_domain`/`ddw_site` (distinct dari `rekon_account_map`). **Tidak ada daftar akun hardcode.**
- **Event flow:**
  - `open` → set default `d_periode` = MAX(periode) snapshot → `dw_rekon_summary.Retrieve(d_periode)`.
  - `dw_rekon_summary.clicked` (baris domain) → isi `str_rekon_ctx.s_domain` → buka `w_rekon_ap`/`w_rekon_ar`/`w_rekon_stok` sesuai domain via `OpenWithParm`.
  - tombol **Snapshot** → `w_rekon_snapshot`; tombol **Anomali** → `w_rekon_anomali` (domain='ALL').

### 1.2 `w_rekon_ap` — DOMAIN HUTANG
- **Fungsi:** rekap kontrol AP (subledger vs GL dari snapshot) + daftar **per-vendor** (subledger sisa) → pintu ke voucher.
- **DataWindow:** header `dw_rekon_ap_final` (per vendor), label total dari `str_rekon_ctx` (snapshot yang dibawa dashboard — tidak query ulang).
- **Data source:** `v_ap_sisa_vendor` (per vendor, kumulatif `bln<=`).
- **Filter logic:** `:arg_thn=l_thn`, `:arg_bln=i_bln` (dari ctx). Akun kontrol tak disebut di window — sudah di dalam view (map-driven).
- **Event flow:** `open` → `dw_rekon_ap_final.Retrieve(l_thn,i_bln)`. `clicked(vendor)` → `s_entity=vendor_id` → buka `w_rekon_voucher_detail` (domain='AP').

### 1.3 `w_rekon_ar` — DOMAIN PIUTANG
- Identik AP, sumber `v_ar_sisa_cust` (per `cust_id`), DW `dw_rekon_ar_final`. `clicked(cust)` → `w_rekon_voucher_detail` (domain='AR').

### 1.4 `w_rekon_stok` — DOMAIN PERSEDIAAN
- **Fungsi:** rekap per **akun persediaan** (item-group) subledger vs GL + selisih.
- **DataWindow:** `dw_rekon_stok_final`.
- **Data source:** `v_rekon_stok_final` (per `account_id`, per bln).
- **Filter:** `:arg_thn`, `:arg_bln` dari ctx.
- **Event flow:** `clicked(account)` → `s_account=account_id`, `s_domain='STOK'` → `w_rekon_voucher_detail` (drill GL langsung, karena stok tak per-entity-vendor) atau langsung `w_rekon_...gl_bridge` embedded.

### 1.5 `w_rekon_voucher_detail` — DAFTAR VOUCHER/FAKTUR ENTITAS
- **Fungsi:** daftar faktur/voucher milik entitas terpilih + status GL-anchor → pintu ke bridge GL. **SISA per faktur = kontrak opname (reuse, tanpa duplikasi).**
- **DataWindow:** `dw_rekon_detail_voucher` (AP/AR: inherit `dw_rpt_ap_opname`/`dw_rpt_ar_opname` + filter entitas; STOK: navigator dari bridge).
- **Data source:** AP/AR → report opname existing; navigator GL-anchor → `v_rekon_gl_bridge`.
- **Filter:** `:arg_domain=s_domain`, `:arg_entity=s_entity`, `:arg_thn`, `:arg_bln`.
- **Event flow:** `clicked(voucher)` → `s_voucher=voucher` (atau `voucher_manual`) → buka `w_rekon_voucher_detail`'s embedded `dw_rekon_gl_bridge` / window bridge. Tombol **Jelaskan** → `w_rekon_anomali` (domain+entity).

### 1.6 `w_rekon_anomali` — PANEL R1–R11
- **Fungsi:** tampilkan hasil `sp_rekon_anomali`, klasifikasi mismatch, drill ke root voucher.
- **DataWindow:** `dw_rekon_anomali` (tipe **Stored Procedure**).
- **Data source:** `sp_rekon_anomali(:arg_domain,:arg_thn,:arg_bln)`.
- **Filter:** domain/thn/bln dari ctx; `p_domain='ALL'` bila dibuka dari dashboard.
- **Event flow:** `clicked(anomali)` → parse `ref_key` (`vmanual=` / `voucher=`) → set `s_voucher` → buka bridge GL untuk root voucher. Highlight per `category` (lihat §5).

### 1.7 `w_rekon_snapshot` — AUDIT HISTORIKAL
- **Fungsi:** jejak rekonsiliasi lintas periode + status GATE untuk audit; tombol **Build** memicu `sp_rekon_snapshot_build`.
- **DataWindow:** `dw_rekon_snapshot_v2` (semua periode/domain).
- **Data source:** `rekon_snapshot_v2`.
- **Filter:** `:arg_domain` (opsi 'ALL'), `:arg_per1..:arg_per2` (range).
- **Event flow:** tombol **Build Periode** → `DECLARE ... EXECUTE PROCEDURE sp_rekon_snapshot_build(:l_thn,:i_bln)` → `Retrieve` ulang. (Build = satu-satunya jalur tulis; read-only lainnya.)

---

## 2. DATAWINDOW SQL (ASA9-READY, MAP-DRIVEN)

> Semua akun sudah di dalam view (map-driven); **tak ada literal COA di SQL DW**. Argumen retrieval PB memakai `:arg_*` (host variable di WHERE — aman untuk painter ASA9).

### 2.1 `dw_rekon_summary` (dashboard grid — baca snapshot, no recalc)
```sql
SELECT s.domain, s.subledger_total, s.ledger_total, s.selisih,
       CASE WHEN ABS(s.selisih) <= 10 THEN 'COCOK' ELSE 'SELISIH' END AS status,
       s.gate1_status, s.gate2_status, s.gate3_status
FROM   rekon_snapshot_v2 s
WHERE  s.periode = :arg_periode
ORDER BY s.domain;
```

### 2.2 `dw_rekon_ap_final` (per vendor — subledger sisa kumulatif)
```sql
SELECT v.vendor_id,
       /*LOOKUP sup.nama AS vendor_nama, */
       CAST(SUM(v.sisa_idr) AS NUMERIC(18,2)) AS sisa_idr
FROM   v_ap_sisa_vendor v
/*LOOKUP LEFT OUTER JOIN mcstsupp sup ON sup.vendor_id = v.vendor_id */
WHERE  v.thn = :arg_thn AND v.bln <= :arg_bln
GROUP BY v.vendor_id /*LOOKUP , sup.nama */
HAVING SUM(v.sisa_idr) <> 0
ORDER BY 2 DESC;
```

### 2.3 `dw_rekon_ar_final` (per customer)
```sql
SELECT v.cust_id,
       /*LOOKUP c.nama AS cust_nama, */
       CAST(SUM(v.sisa_idr) AS NUMERIC(18,2)) AS sisa_idr
FROM   v_ar_sisa_cust v
/*LOOKUP LEFT OUTER JOIN mcust c ON c.cust_id = v.cust_id */
WHERE  v.thn = :arg_thn AND v.bln <= :arg_bln
GROUP BY v.cust_id /*LOOKUP , c.nama */
HAVING SUM(v.sisa_idr) <> 0
ORDER BY 2 DESC;
```

### 2.4 `dw_rekon_stok_final` (per akun persediaan)
```sql
SELECT s.account_id,
       /*LOOKUP a.accountdes AS account_nama, */
       s.subledger_value, s.ledger_value, s.selisih, s.status
FROM   v_rekon_stok_final s
/*LOOKUP LEFT OUTER JOIN gl_acc a ON a.accountcode = s.account_id */
WHERE  s.thn = :arg_thn AND s.bln = :arg_bln
ORDER BY ABS(s.selisih) DESC, s.account_id;
```

### 2.5 `dw_rekon_gl_bridge` (drill lvl-4 = titik audit ke GL_JOURNAL)
```sql
SELECT b.domain, b.account_id, b.site_id, b.tgl, b.modul_id,
       b.voucher, b.voucher_manual, b.debet, b.kredit,
       b.anchor_type, b.has_subledger
FROM   v_rekon_gl_bridge b
WHERE  b.domain = :arg_domain
  AND  b.account_id = :arg_account
  AND  b.thn = :arg_thn
  AND  b.bln = :arg_bln
  AND  ( :arg_voucher = ''
         OR b.voucher = :arg_voucher
         OR b.voucher_manual = :arg_voucher )
ORDER BY b.has_subledger ASC, b.tgl, b.voucher;
```

### 2.6 `dw_rekon_detail_voucher` (daftar faktur entitas)
**AP/AR — REUSE kontrak opname (zero duplication):** DataWindow = *inherit/salin* `dw_rpt_ap_opname` (AP) / `dw_rpt_ar_opname` (AR), **tambah** retrieval-arg & predikat:
```
-- tambahan WHERE pada SQL opname existing (jangan tulis ulang logika SISA):
AND ap_trans.vendor_id = :arg_entity      -- AR: ar_trans.cust_id = :arg_entity
AND <kolom periode opname> BETWEEN :arg_tgl1 AND :arg_tgl2
```
**Navigator GL-anchor (opsional, cepat) — dari bridge, untuk status posting per voucher:**
```sql
SELECT b.voucher, b.voucher_manual, MAX(b.tgl) AS tgl, b.anchor_type,
       MAX(b.has_subledger) AS has_subledger,
       CAST(SUM(b.debet) AS NUMERIC(18,2)) AS debet,
       CAST(SUM(b.kredit) AS NUMERIC(18,2)) AS kredit
FROM   v_rekon_gl_bridge b
WHERE  b.domain = :arg_domain
  AND  b.thn = :arg_thn AND b.bln <= :arg_bln
  AND  ( ( :arg_domain = 'AP'
           AND EXISTS ( SELECT 1 FROM ap_trans p
                        WHERE p.order_client = b.voucher
                          AND p.vendor_id = :arg_entity ) )
      OR ( :arg_domain = 'AR'
           AND EXISTS ( SELECT 1 FROM ar_trans a
                        WHERE a.order_client = b.voucher
                          AND a.cust_id = :arg_entity ) ) )
GROUP BY b.voucher, b.voucher_manual, b.anchor_type
ORDER BY has_subledger ASC, tgl;
```

### 2.7 `dw_rekon_anomali` (tipe Stored Procedure)
```
-- PB DataWindow source = Stored Procedure:
EXECUTE PROCEDURE sp_rekon_anomali( :arg_domain, :arg_thn, :arg_bln );
-- Result columns: rule_id, severity, category, domain, account_id, ref_key, nilai
```

### 2.8 `dw_rekon_snapshot_v2` (audit historikal / trend)
```sql
SELECT s.periode, s.domain, s.subledger_total, s.ledger_total, s.selisih,
       s.gate1_status, s.gate2_status, s.gate3_status, s.created_at
FROM   rekon_snapshot_v2 s
WHERE  ( :arg_domain = 'ALL' OR s.domain = :arg_domain )
  AND  s.periode BETWEEN :arg_per1 AND :arg_per2
ORDER BY s.periode DESC, s.domain;
```

### 2.9 DDDW filter (config-driven — sumber dropdown)
```sql
-- ddw_domain :
SELECT DISTINCT m.domain FROM rekon_account_map m WHERE m.is_active='Y' ORDER BY 1;
-- ddw_site :
SELECT DISTINCT m.site_id FROM rekon_account_map m WHERE m.is_active='Y' ORDER BY 1;
-- ddw_period :
SELECT DISTINCT s.periode FROM rekon_snapshot_v2 s ORDER BY s.periode DESC;
```

---

## 3. EVENT FLOW SPECIFICATION (DRILL LOGIC)

| Step | Event | Input param | DataWindow refresh | Filter SQL behavior | Audit trace |
|---|---|---|---|---|---|
| 1 | `w_rekon_dashboard.open` | — | `dw_rekon_summary.Retrieve(:arg_periode)` | `periode=` (snapshot) | baca angka jadi (no recalc) |
| 2 | `dw_rekon_summary.clicked` | domain | Open `w_rekon_[ap/ar/stok]` (OpenWithParm ctx) | — | pilih domain |
| 3 | domain-window `.open` | thn,bln | AP:`Retrieve(:arg_thn,:arg_bln)` v_ap_sisa_vendor · AR: v_ar_sisa_cust · STOK: v_rekon_stok_final | `thn=,bln<=` (AP/AR) / `thn=,bln=` (STOK) | subledger per entitas/akun (map-driven) |
| 4 | entity/account `.clicked` | vendor_id/cust_id/account_id | Open `w_rekon_voucher_detail` | — | pilih entitas |
| 5 | `w_rekon_voucher_detail.open` | domain,entity,thn,bln | `dw_rekon_detail_voucher.Retrieve(...)` | opname filter entitas (reuse) + navigator bridge | daftar faktur + status GL |
| 6 | voucher `.clicked` | voucher/voucher_manual | `dw_rekon_gl_bridge.Retrieve(domain,account,thn,bln,voucher)` | `voucher= OR voucher_manual=` | **baris GL_JOURNAL** = titik temu ledger |
| 7 | `w_rekon_gl_bridge`/"Jelaskan" | domain,thn,bln | `dw_rekon_anomali` EXECUTE `sp_rekon_anomali` | proc R1–R11 | klasifikasi penyebab |
| 8 | anomali `.clicked` | ref_key | parse `vmanual=`/`voucher=` → `dw_rekon_gl_bridge.Retrieve(...,:arg_voucher)` | drill balik ke GL root | tutup loop audit |

**PB skeleton (event, bukan UI):**
```
// dw_rekon_summary.clicked
str_rekon_ctx lstr
lstr = istr_ctx
lstr.s_domain = dw_rekon_summary.GetItemString(row,'domain')
CHOOSE CASE lstr.s_domain
  CASE 'AP' ; OpenWithParm(w_rekon_ap, lstr)
  CASE 'AR' ; OpenWithParm(w_rekon_ar, lstr)
  CASE 'STOK' ; OpenWithParm(w_rekon_stok, lstr)
END CHOOSE

// w_rekon_ap.open
istr_ctx = Message.PowerObjectParm
dw_rekon_ap_final.SetTransObject(SQLCA)
dw_rekon_ap_final.Retrieve(istr_ctx.l_thn, istr_ctx.i_bln)

// dw_rekon_gl_bridge retrieve (drill dari voucher)
dw_rekon_gl_bridge.Retrieve(istr_ctx.s_domain, istr_ctx.s_account, &
     istr_ctx.l_thn, istr_ctx.i_bln, istr_ctx.s_voucher)

// dw_rekon_anomali.clicked  (parse ref_key → drill GL)
string ls_ref, ls_v
ls_ref = dw_rekon_anomali.GetItemString(row,'ref_key')
IF Pos(ls_ref,'vmanual=')>0 THEN ls_v = Mid(ls_ref, Pos(ls_ref,'=')+1)
ELSEIF Pos(ls_ref,'voucher=')>0 THEN ls_v = Mid(ls_ref, Pos(ls_ref,'=')+1)
END IF
istr_ctx.s_voucher = ls_v
dw_rekon_gl_bridge.Retrieve(istr_ctx.s_domain, istr_ctx.s_account, &
     istr_ctx.l_thn, istr_ctx.i_bln, ls_v)
```

---

## 4. FILTERING ENGINE (CONFIG-DRIVEN)

- **Domain** ← `ddw_domain` (DISTINCT `rekon_account_map.domain`). Tak ada enum hardcode.
- **Site** ← `ddw_site` (DISTINCT `rekon_account_map.site_id`); `'*'` = semua site (view sudah handle `site_id='*' OR =j.site_id`).
- **Period** ← `ddw_period` (DISTINCT `rekon_snapshot_v2.periode`); dari `d_periode` diturunkan `l_thn=Year()`, `i_bln=Month()`.
- **Entity** ← hasil retrieve `v_ap_sisa_vendor.vendor_id` / `v_ar_sisa_cust.cust_id` / `v_rekon_stok_final.account_id` (bukan daftar statis).
- **Akun kontrol/persediaan** ← **tidak pernah** di UI; berada di dalam view via `rekon_account_map`. Menambah/ganti akun cukup update `rekon_account_map` (effective-dated), dashboard ikut otomatis.

Aturan: setiap `Retrieve` **wajib** membawa minimal (periode) + (domain atau account/entity). Tidak ada retrieve tanpa filter periode.

---

## 5. ANOMALY INTEGRATION MAPPING (R1–R11)

`sp_rekon_anomali` → `dw_rekon_anomali`. Kolom `category` memetakan highlight & aksi:

| category (dari SP) | Rule | Highlight type | Drill root (ref_key) | Aksi UI |
|---|---|---|---|---|
| `DP_APPLICATION_GAP` | R11 | **DP mismatch** (merah) | `vmanual=<voucher_manual>` | drill GL bridge → "posting jurnal DP" |
| `GL_ORPHAN_VOUCHER` | R9 | **Orphan GL** (merah) | `voucher=<voucher>` | drill GL bridge (subledger kosong) |
| `UNPOSTED_JOURNAL` | R1 | **Posting gap** (oranye) | `n_baris` per akun | filter GL posting<>'P' |
| `MISSING_LEDGER` | R2 | Posting gap (oranye) | account_id | subledger tanpa GL |
| `OPENING_BALANCE_GAP` | R3 | **Mapping/opening** (kuning) | account_id | cek saldo awal GL vs SINV |
| `GL_ONLY_NO_SINV` | R4 | Mapping issue (info) | account_id | akun map tanpa SINV (WIP) |
| `LOOP19_RISK` | R5 | Costing risk (kuning) | account_id,bln | cek mutasi '19' |
| `SITE_MISMATCH` | R6 | Mapping issue (kuning) | `site=` | cek site GL vs balance |
| `PAYMENT_PENDING` | R7 | Info | `vmanual=` | pembayaran pending |
| `ADJUSTMENT_PUTIH` | R8 | Info | `bukti=` | adjustment non-kas |
| `ROUNDING_NOISE` | R10 | Info (abu) | account_id | selisih ≤ 10 |

Highlight via DataWindow expression pada kolom `severity`/`category` (mis. `background.color` = expression `IF(severity='HIGH', RGB(255,220,220), ...)`), **bukan** logika di script. Baris R11/R9 double-click → §3 step-8.

---

## 6. SNAPSHOT USAGE DESIGN

- Dashboard (`dw_rekon_summary`) & audit (`dw_rekon_snapshot_v2`) **hanya membaca** `rekon_snapshot_v2`. **Tidak** memanggil `v_rekon_*_final` saat open (view berat → hanya untuk drill/build).
- **Build** dijalankan **setelah closing/refresh** via `sp_rekon_snapshot_build(:l_thn,:i_bln)` (idempotent: DELETE+INSERT per periode). Satu-satunya proses tulis; dijadwalkan (mis. tombol admin / job pasca-closing).
- Snapshot menyimpan `subledger_total`, `ledger_total`, `selisih`, `gate1/2/3_status`, `created_at` → audit historikal per periode tanpa re-agregasi.
- `gate1_status='NA'` di snapshot = perlu verifikasi vs export DW opname (GATE#1 query); operator/loader meng-`UPDATE` setelah cocok. GATE#2/#3 dihitung otomatis di builder.

---

## 7. PERFORMANCE OPTIMIZATION (ASA9 + PB 11.5)

**Avoid full scan**
- Dashboard baca snapshot (O(3) baris) — nol agregasi transaksi saat open.
- Semua filter akun via index map `idx_ram_acc_site` / `idx_ram_domain` (tabel kecil → nested-loop murah).
- `gl_journal` selalu difilter `(account_id,tgl,posting)` → `idx_gljrn_acc_tgl_post`; drill voucher → `idx_gljrn_voucher`; linkage bayar (R11/bridge PAYMENT) → `idx_gljrn_vmanual` + `idx_tbyr1_vmanual`.
- Gunakan rentang tanggal (`BETWEEN`) bukan `YEAR(tgl)=` pada predikat `gl_journal`.

**Index dependency mapping (per DataWindow)**
| DataWindow | View/tabel | Index kritikal |
|---|---|---|
| dw_rekon_summary / snapshot_v2 | rekon_snapshot_v2 | PK(periode,domain), idx_snapv2_dom |
| dw_rekon_ap_final / ar_final | v_ap_sisa_vendor / v_ar_sisa_cust | idx_ram_domain, idx_aptrans_order/idx_artrans_order, idx_gljrn_voucher, idx_tbyr2_bukti |
| dw_rekon_stok_final | v_rekon_stok_final | idx_sinv_per_stok, idx_ram_domain, idx_gljrn_acc_tgl_post |
| dw_rekon_gl_bridge / detail_voucher | v_rekon_gl_bridge | idx_gljrn_acc_tgl_post, idx_gljrn_voucher, idx_gljrn_vmanual, idx_ram_acc_site |
| dw_rekon_anomali | sp_rekon_anomali | idx_gljrn_vmanual, idx_tbyr1_vmanual, idx_aptrans_order, idx_artrans_order |

**Retrieval optimization**
- Setiap `Retrieve` membawa filter periode (+domain/account) — tak pernah tanpa argumen.
- `dw_rekon_gl_bridge` selalu difilter `account_id+thn+bln` (satu akun-periode), bukan seluruh jurnal.
- `SetTransObject` sekali; `Retrieve` ulang saat filter berubah (jangan `ReSelectRow`/full re-instantiate).

**Batch loading**
- Domain-window retrieve per (thn,bln) sekali; drill entitas/voucher lazy (hanya saat diklik).
- `sp_rekon_anomali` dipanggil on-demand (tombol Jelaskan), bukan saat open dashboard.

**Caching via snapshot**
- Angka periode tertutup = immutable di snapshot → cache alami; UI tak hitung ulang.
- `UPDATE STATISTICS` pada `gl_journal, sinv, tbyr1, tbyr2, ap_trans, ar_trans` setelah index dibuat.
- DDL/index dibuat saat idle (aplikasi memegang SHARE lock luas → blok DDL).

---

## 8. SUCCESS CRITERIA — CHECK
- ✅ Semua angka dari `v_rekon_*` / `sp_rekon_anomali` / `rekon_snapshot_v2` — window nol perhitungan.
- ✅ Voucher drill sampai `gl_journal` via `v_rekon_gl_bridge` (`voucher`/`voucher_manual`).
- ✅ Selisih dijelaskan R1–R11 (§5), termasuk R11 DP-gap & R9 orphan.
- ✅ Nol literal COA — semua via `rekon_account_map` (config-driven, effective-dated).
- ✅ ASA9 + PB 11.5 murni (host var di WHERE, no CTE/window func, DW bindable).
