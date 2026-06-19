# Desain Modul Fixed Asset (Aktiva Tetap) + Penyusutan Otomatis — Terintegrasi GL

**Aplikasi:** PowerBuilder 11.5 + Sybase SQL Anywhere (runtime engine v11, sintaks DDL kompatibel SQLA9)
**Database:** `vsp` (DSN `vsp`, user `dba`) — single site `101` = PT. VARIA PERDANA KARYA
**Tanggal analisis:** 2026-06-17
**Status:** Desain / Reverse-engineering (BUKAN implementasi). Semua fakta GL di bawah **diverifikasi dari database live**, bukan asumsi.

> ⚠️ **Temuan penting tentang source code.** Folder `C:\BTV\debug\source_powerbuilder_11.5` berisi 3.285 file hasil export PBL, **tetapi seluruhnya 0 byte (kosong)**. `batch_export.log` melaporkan `OK=3284 Fail=0`, jadi export "berhasil" secara metadata tetapi tidak menulis isi objek. **Source `.srw/.srd/.srf` tidak bisa dibaca saat ini.** Karena itu, analisis arsitektur jurnal di dokumen ini bersumber dari **skema + data live database** (lebih otoritatif daripada source), bukan dari pembacaan kode. Untuk membaca logika PB (event `ue_save`, generate voucher, dll.) export harus dijalankan ulang dengan benar. Lihat §13.

---

## 1. Ringkasan Eksekutif

Modul Fixed Asset dibangun sebagai **sub-ledger** yang menumpang pada infrastruktur GL existing, mengikuti pola yang sudah terbukti di modul lain (refresh jurnal stok/AP/AR → ringkasan ke `gl_journal`). Tidak ada engine jurnal, penomoran voucher, atau proses closing baru.

Empat fakta verifikasi yang mengubah desain dibanding `todolist_penyusutan_aktiva.md`:

| # | Asumsi lama (todolist) | Fakta dari DB live | Dampak desain |
|---|---|---|---|
| 1 | `gl_journal` = header+detail gabungan | `gl_journal` adalah tabel **flat per-baris-jurnal** (PK `voucher,urut,site_id`), header-field diulang tiap baris. Ada juga `gl_journal_detail` terpisah. | Jurnal penyusutan ditulis sebagai baris-baris flat di `gl_journal`. |
| 2 | `posting='Y'` saat terposting | Nilai real `posting='P'` (Posted) — terbukti pada voucher closing `RL101202604`. | Gunakan `'P'`. |
| 3 | Akun penyusutan diasumsikan 5 kategori, rate ditebak | **COA aktiva tetap nyata** sudah ada (lihat §4). 4 kategori disusutkan + Tanah (tidak disusut). Expense **satu akun** `412-066`. | Mapping kategori→akun sudah pasti, tinggal di-seed. |
| 4 | Banyak stored proc jurnal | Hanya **1** stored procedure di DB (`f_get_saldo_faktur`). | Seluruh logika jurnal ada di PB (kode), bukan DB. Modul FA pun menempatkan logika di PB agar konsisten. |

---

## 2. Arsitektur Jurnal Existing (terverifikasi dari DB)

### 2.1 `gl_journal` — buku besar terposting (flat, 34 kolom)
PK: `(voucher, urut, site_id)`. Setiap baris = satu baris jurnal yang **membawa field header sendiri**.

```
voucher        varchar(15)  PK  -- nomor voucher sistem
urut           integer      PK  -- nomor baris (1..n)
site_id        varchar(4)   PK
tgl            timestamp        -- tanggal transaksi (diulang tiap baris)
modul_id       varchar(2)       -- AS,CI,CO,DP,EX,GJ,KS,PO,SO,TC,VP,VR
account_id     varchar(15)      -- akun GL (FK logis -> gl_acc.AccountCode)
debet          decimal(30,6)    -- nilai mata uang lokal
kredit         decimal(30,6)
debet_kurs     numeric(30,6)    -- nilai mata uang asal (kurs)
kredit_kurs    numeric(30,6)
ket            varchar(250)     -- keterangan baris
ket2           varchar(250)
curr_id        varchar(5)       -- mata uang
rate_rp        decimal(14,2)    -- kurs ke IDR
posting        varchar(1)       -- 'P' = Posted (terverifikasi)
voucher_manual varchar(15)      -- no. referensi (utk auto = sama dgn voucher)
dk             char(1)          -- flag debit/kredit (bisa NULL)
depart_id1/2   varchar(10)      -- cost center (opsional)
project_id1/2  varchar(10)      -- project (opsional)
cf_flag        varchar(1)       -- routing cash flow
cc_flag        varchar(1)       -- routing cost center
cust_id        varchar(15)
group_id       varchar(10)
doc_reff       varchar(25)
journal_urut   integer
order_reff,kas_id,giro_id,inkaso_id,rekon,flag_dp,show_hide ...
```

`gl_journal_detail` (tabel terpisah, granularitas lebih halus, `numeric(14,4)`): `voucher, urut, account_id, keterangan, debet, kredit, debet_kurs, kredit_kurs, site_id`. Dipakai sebagai detail entry/working pada modul transaksi. **Modul FA cukup menulis ke `gl_journal`** (ringkasan terposting), sejajar pola refresh-jurnal.

### 2.2 Penomoran voucher (pola terbukti dari data)
`voucher` max 15 char. Modul `GJ` menampung jurnal manual **dan** jurnal closing. Closing memakai pola **`'RL' + site + YYYYMM`** → `RL101202604` (site 101, April 2026, 11 char), `voucher_manual = voucher`, `posting='P'`, `modul_id='GJ'`.

Modul existing & contoh voucher (urut=1):
```
AS n=23228   GJ n=2988  (… RL101202604 = closing)
CI n=16694   KS n=7952
CO n=47674   PO n=17460
DP n=2838    SO n=24743
EX n=1377    TC n=3173    VP n=141    VR n=689
```

### 2.3 Master pendukung (terverifikasi)
- **`gl_acc`** (COA): `AccountCode(15) PK`, `AccountDes`, `FinCatCode`→`gl_cate`, `DetailYN`('1'=boleh diposting), `DebetCredit`(saldo normal D/K), `FAType char(1)` (saat ini semua `'0'` — **belum dipakai** menandai aktiva), `cc_flag`,`cf_flag`,`show_hide`, `ParentCode`/`LevelNo` (hirarki), `site_id`.
- **`gl_cate`/`gl_cate_detail`**: kategori laporan keuangan. FA memakai `BS2110` (Aktiva Tetap-harga perolehan), `BS2111` (Akumulasi Penyusutan), `IS2120` (Beban Penyusutan).
- **`gl_setup`** (1 baris config): `periode = 2026-01-01` (periode berjalan = awal bulan), `re_this_year/re_ikhtisar/re_last_year`, banyak `acc_*` mapping, flag auto-journal `auto_pogl/auto_sogl/auto_argl/auto_apgl/auto_expgl/auto_hppgl`, `tgl_start`.
- **`gl_site`**: prefix voucher per-jenis-dokumen per site. Hanya 1 site `101`.
- **`gl_balance`**: `(Period, AccountCode, AmountDebet, AmountCredit, site_id, curr_id, rate_rp)` — snapshot saldo GL per bulan (di-refresh saat closing).
- **`gl_depart`, `gl_project`**: master cost center & project.

### 2.4 Audit trail existing
**`USER_LOG`**: `LOG_ID(identity), USER_ID, ITEM_ID, ITEM_DESC, LOG_DATE, LOG_ACTION, LOG_DESC, LOG_REFF`. → Mencatat **aksi** (siapa, kapan, apa) tetapi **tidak punya kolom old_value/new_value**. Karena requirement audit FA menuntut nilai lama vs baru (Nilai Perolehan, Umur, Residu, Saldo Awal), modul FA butuh tabel audit field-level sendiri (`FA_ASSET_AUDIT`), sambil tetap menulis ringkasan aksi ke `USER_LOG` agar muncul di log terpusat.

### 2.5 Peta alur (target FA mengikuti jalur existing)
```
Master FA (FA_ASSET)               ← sub-ledger (baru)
   │  Generate Depreciation (per periode, straight-line)
   ▼
FA_DEPRECIATION (history per aset)  ← sub-ledger detail (baru)
   │  Generate Journal (ringkas per kategori)
   ▼
gl_journal  (modul_id='FA', voucher 'FA'+site+YYYYMM, posting='P')   ← GL existing
   │  (closing me-refresh)
   ▼
gl_balance  →  Trial Balance (d_trial_balance)  →  Financial Statement (gl_cate)
```

---

## 3. ERD Modul Fixed Asset

```
                         gl_acc (existing)
                            ▲   ▲   ▲
        asset_account ──────┘   │   └────── dep_expense_account
        accum_dep_account ──────┘
                            │ (FK logis by AccountCode+site_id)
                            │
   ┌─────────────┐   1   N  ┌──────────────┐   1   N  ┌──────────────────┐
   │ FA_CATEGORY │─────────▶│   FA_ASSET    │─────────▶│ FA_DEPRECIATION  │
   │ category_code│         │ asset_code PK │          │ asset_code,period│
   └─────────────┘          │ category_code │          │ journal_no ──────┼──▶ gl_journal.voucher
                            │ site_id       │          └──────────────────┘
                            └──────┬────────┘
                                   │ 1   N
                                   ▼
                            ┌──────────────────┐        ┌──────────────┐
                            │ FA_ASSET_AUDIT   │        │  FA_PERIOD   │ (kontrol periode generate)
                            │ (old/new value)  │        │ period,site PK│
                            └──────────────────┘        └──────────────┘
   gl_depart / gl_project (existing) ◀── department / location ref pada FA_ASSET
```

Relasi:
- `FA_ASSET.category_code` → `FA_CATEGORY.category_code` (mapping akun & default umur/residu).
- `FA_DEPRECIATION.asset_code` → `FA_ASSET.asset_code`; `FA_DEPRECIATION.journal_no` → `gl_journal.voucher` (jejak posting).
- `FA_CATEGORY.{asset_account,accum_dep_account,dep_expense_account}` → `gl_acc.AccountCode` (divalidasi `DetailYN='1'`).
- `FA_PERIOD` mengunci periode yang sudah digenerate (anti dobel posting).
- Semua tabel bawa `site_id` (multi-site ready, walau sekarang 1 site).

---

## 4. Mapping Kategori → Akun GL (DIVERIFIKASI dari `gl_acc`, site 101)

| Kategori | Akun Aset (BS2110) | Akumulasi (BS2111) | Beban (IS2120) | Disusutkan? |
|---|---|---|---|---|
| Bangunan | `151-100` Bangunan | `158-001` | `412-066` | Ya |
| Peralatan Kantor | `153-001` | `158-101` | `412-066` | Ya |
| Peralatan Bengkel | `154-001` | `158-201` | `412-066` | Ya |
| Kendaraan | `155-001` | `158-301` | `412-066` | Ya |
| Tanah | `151-001` Tanah | — | — | **Tidak** (non-depreciable) |

Catatan: akun beban penyusutan **tunggal** (`412-066`) untuk semua kategori. Pemisahan per kategori/ departemen dilakukan via `FA_ASSET.department` (`depart_id1` di jurnal), bukan via akun beban berbeda. Umur ekonomis/residu **bukan** dari COA — diambil dari `WP_Aset tetap_TAM 2026.xlsx` (lihat §9) dan disimpan di `FA_CATEGORY`/`FA_ASSET`.

---

## 5. DDL — SQL Anywhere 9 (kompatibel engine v11)

> Konvensi mengikuti existing: `varchar` untuk kode, `decimal` untuk uang, `timestamp` untuk tanggal, `site_id varchar(4)`, identity via `DEFAULT AUTOINCREMENT`, audit `DEFAULT CURRENT TIMESTAMP`/`CURRENT USER`. Tidak memodifikasi tabel existing kecuali penambahan opsional di §5.6.

### 5.1 FA_CATEGORY
```sql
CREATE TABLE FA_CATEGORY (
    site_id              varchar(4)    NOT NULL DEFAULT '101',
    category_code        varchar(10)   NOT NULL,
    category_name        varchar(50)   NOT NULL,
    asset_account        varchar(15)   NOT NULL,   -- gl_acc.AccountCode (BS2110)
    accum_dep_account    varchar(15)   NULL,        -- gl_acc.AccountCode (BS2111); NULL utk non-depreciable (Tanah)
    dep_expense_account  varchar(15)   NULL,        -- gl_acc.AccountCode (IS2120)
    useful_life_month    integer       NOT NULL DEFAULT 0,   -- 0 = tidak disusutkan
    residual_percent     decimal(5,2)  NOT NULL DEFAULT 0,
    depreciable_yn       char(1)       NOT NULL DEFAULT 'Y',  -- 'N' utk Tanah
    active_yn            char(1)       NOT NULL DEFAULT 'Y',
    created_by           varchar(15)   NULL DEFAULT CURRENT USER,
    created_date         timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (site_id, category_code)
);
```

### 5.2 FA_ASSET
```sql
CREATE TABLE FA_ASSET (
    site_id              varchar(4)    NOT NULL DEFAULT '101',
    asset_code           varchar(20)   NOT NULL,
    asset_name           varchar(100)  NOT NULL,
    category_code        varchar(10)   NOT NULL,
    acquisition_date     timestamp     NOT NULL,
    acquisition_cost     decimal(18,2) NOT NULL DEFAULT 0,
    residual_value       decimal(18,2) NOT NULL DEFAULT 0,
    useful_life_month    integer       NOT NULL,        -- umur total (bln) saat perolehan
    -- Saldo awal (per cut-off, mis. 31/12/2025):
    accum_dep_beginning  decimal(18,2) NOT NULL DEFAULT 0,
    book_value_beginning decimal(18,2) NOT NULL DEFAULT 0,  -- = acquisition_cost - accum_dep_beginning
    beginning_period     timestamp     NULL,            -- tgl cut-off saldo awal (31/12/2025)
    -- Override mapping akun (NULL = ikut FA_CATEGORY):
    asset_account        varchar(15)   NULL,
    accum_dep_account    varchar(15)   NULL,
    dep_expense_account  varchar(15)   NULL,
    department           varchar(10)   NULL,            -- gl_depart.depart_id
    project              varchar(10)   NULL,            -- gl_project.project_id
    location             varchar(50)   NULL,
    status               char(1)       NOT NULL DEFAULT 'A', -- A=Active, F=Fully depreciated, D=Disposed, X=Inactive
    disposal_date        timestamp     NULL,
    remarks              varchar(250)  NULL,
    created_by           varchar(15)   NULL DEFAULT CURRENT USER,
    created_date         timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    updated_by           varchar(15)   NULL,
    updated_date         timestamp     NULL,
    PRIMARY KEY (site_id, asset_code),
    FOREIGN KEY (site_id, category_code) REFERENCES FA_CATEGORY (site_id, category_code)
);
CREATE INDEX ix_fa_asset_cat ON FA_ASSET (site_id, category_code, status);
```

### 5.3 FA_DEPRECIATION (history per aset per periode)
```sql
CREATE TABLE FA_DEPRECIATION (
    site_id             varchar(4)    NOT NULL DEFAULT '101',
    asset_code          varchar(20)   NOT NULL,
    period              timestamp     NOT NULL,         -- akhir bulan (last day of month)
    depreciation_amount decimal(18,2) NOT NULL DEFAULT 0,
    accum_depreciation  decimal(18,2) NOT NULL DEFAULT 0, -- kumulatif s/d period (incl. saldo awal)
    book_value          decimal(18,2) NOT NULL DEFAULT 0,
    journal_no          varchar(15)   NULL,             -- gl_journal.voucher (NULL bila belum diposting)
    posting_status      char(1)       NOT NULL DEFAULT 'D', -- D=Draft, P=Posted, R=Reversed
    created_by          varchar(15)   NULL DEFAULT CURRENT USER,
    created_date        timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (site_id, asset_code, period),
    FOREIGN KEY (site_id, asset_code) REFERENCES FA_ASSET (site_id, asset_code)
);
CREATE INDEX ix_fa_depr_period ON FA_DEPRECIATION (site_id, period, posting_status);
```

### 5.4 FA_PERIOD (kontrol generate per bulan)
```sql
CREATE TABLE FA_PERIOD (
    site_id        varchar(4)   NOT NULL DEFAULT '101',
    period         timestamp    NOT NULL,           -- akhir bulan
    status         char(1)      NOT NULL DEFAULT 'O', -- O=Open, G=Generated, P=Posted, C=Closed
    journal_no     varchar(15)  NULL,               -- voucher FA periode tsb
    total_depr     decimal(18,2) NOT NULL DEFAULT 0,
    generate_date  timestamp    NULL,
    generate_by    varchar(15)  NULL,
    post_date      timestamp    NULL,
    post_by        varchar(15)  NULL,
    PRIMARY KEY (site_id, period)
);
```

### 5.5 FA_ASSET_AUDIT (field-level old/new — pelengkap USER_LOG)
```sql
CREATE TABLE FA_ASSET_AUDIT (
    audit_id     integer       NOT NULL DEFAULT AUTOINCREMENT,
    site_id      varchar(4)    NOT NULL,
    asset_code   varchar(20)   NOT NULL,
    field_name   varchar(30)   NOT NULL,   -- 'acquisition_cost','useful_life_month','residual_value','accum_dep_beginning',...
    old_value    varchar(100)  NULL,
    new_value    varchar(100)  NULL,
    action       varchar(10)   NOT NULL,   -- INSERT/UPDATE/DELETE
    log_user     varchar(15)   NULL DEFAULT CURRENT USER,
    log_date     timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (audit_id)
);
CREATE INDEX ix_fa_audit_asset ON FA_ASSET_AUDIT (site_id, asset_code, log_date);
```

### 5.6 (Opsional) Penanda FA pada `gl_acc`
`gl_acc.FAType` saat ini `'0'` semua. Opsional di-set: `'1'`=akun aset, `'2'`=akumulasi, `'3'`=beban, agar lookup window FA bisa memfilter akun valid tanpa hardcode. **Tidak wajib** untuk MVP (mapping sudah di `FA_CATEGORY`).

### 5.7 Seed FA_CATEGORY (sesuai §4)
```sql
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES
('101','BGN','Bangunan',        '151-100','158-001','412-066',240,0,'Y'),
('101','PKT','Peralatan Kantor','153-001','158-101','412-066', 48,0,'Y'),
('101','PBK','Peralatan Bengkel','154-001','158-201','412-066', 96,0,'Y'),
('101','KDR','Kendaraan',       '155-001','158-301','412-066', 96,0,'Y'),
('101','TNH','Tanah',           '151-001', NULL,     NULL,       0,0,'N');
-- useful_life_month adalah DEFAULT; nilai final per aset mengikuti WP_Aset tetap_TAM 2026.xlsx (§9).
```
> Umur ekonomis di atas **placeholder** mengikuti golongan fiskal umum (bangunan permanen 20th, kendaraan/bengkel 8th, peralatan kantor 4th). **Wajib dikonfirmasi terhadap Excel** sebelum go-live.

---

## 6. Metode Penyusutan — Straight Line

```
Penyusutan bulanan = (acquisition_cost - residual_value) / useful_life_month
Akumulasi          = accum_dep_beginning + Σ penyusutan bulan berjalan
Nilai Buku (NBV)   = acquisition_cost - akumulasi   (tidak boleh < residual_value)
```
Aturan:
- `depreciable_yn='N'` (Tanah) atau `useful_life_month=0` → penyusutan = 0.
- Bulan terakhir: penyusutan = sisa yang masih dapat disusutkan (`acquisition_cost - residual_value - accum_sebelumnya`) agar NBV mendarat tepat di residu (hindari over/under akibat pembulatan).
- `residual_value` default 0 (residual_percent × cost bila dipakai).
- Pembulatan 2 desimal (`ROUND(x,2)`), konsisten validasi balance GL existing.

---

## 7. Pseudocode

### 7.1 Hitung penyusutan satu aset untuk satu periode
```
FUNCTION f_fa_calc_one (as_asset, adt_period) RETURNS decimal:
    READ FA_ASSET a; READ FA_CATEGORY c (by a.category_code)
    IF c.depreciable_yn='N' OR a.useful_life_month=0 RETURN 0

    -- akumulasi sebelum period ini (saldo awal + history < period)
    SELECT accum := a.accum_dep_beginning
           + COALESCE(SUM(depreciation_amount),0)
      FROM FA_DEPRECIATION
     WHERE asset_code=a.asset_code AND site_id=a.site_id AND period < adt_period

    depreciable_base := a.acquisition_cost - a.residual_value
    remaining        := depreciable_base - accum
    IF remaining <= 0 RETURN 0                      -- sudah habis disusut

    monthly := ROUND(depreciable_base / a.useful_life_month, 2)
    RETURN MIN(monthly, remaining)                  -- bulan terakhir diratakan
```

### 7.2 Generate Depreciation (range periode, anti-dobel)
```
PROC f_fa_generate (adt_from, adt_to, as_category, as_asset, as_site):
    FOR each month m in [adt_from .. adt_to]:        -- m = last-day-of-month
        period_dt := EndOfMonth(m)
        IF FA_PERIOD(site,period_dt).status IN ('P','C'):
            SKIP  (sudah diposting/closed → tidak boleh recompute tanpa Regenerate)
        BEGIN TRANSACTION
            DELETE FA_DEPRECIATION WHERE site=as_site AND period=period_dt
                   AND posting_status='D'            -- buang draft lama saja
                   AND (filter category/asset)
            FOR each asset A in FA_ASSET
                WHERE site=as_site AND status='A'
                  AND acquisition_date <= period_dt
                  AND (as_category IS NULL OR category_code=as_category)
                  AND (as_asset    IS NULL OR asset_code=as_asset):
                amt := f_fa_calc_one(A, period_dt)
                IF amt > 0:
                    accum := accum_before(A,period_dt) + amt
                    INSERT FA_DEPRECIATION(site,A,period_dt,amt,accum,
                            A.cost-accum, NULL, 'D')
                    IF accum >= A.cost - A.residual_value:
                        UPDATE FA_ASSET SET status='F' WHERE asset_code=A  -- fully depreciated
            UPDATE/INSERT FA_PERIOD SET status='G', generate_date=now, generate_by=user
        COMMIT
```

### 7.3 Generate Journal (ringkas per kategori → `gl_journal`)
Pola: 1 voucher per periode per site; tiap kategori = pasangan baris **Dr beban / Cr akumulasi** (seimbang). Mengikuti `posting='P'`, `modul_id='FA'`.
```
FUNC f_fa_post_journal (adt_period, as_site) RETURNS voucher:
    period_dt := EndOfMonth(adt_period)
    YYYYMM    := Format(period_dt,'yyyymm')
    voucher   := 'FA' + as_site + YYYYMM            -- ex: FA101202601 (11 char ≤ 15)

    -- anti-dobel: kalau voucher sudah ada & FA_PERIOD='P' → tolak (pakai Regenerate)
    IF EXISTS(gl_journal WHERE voucher=voucher AND site_id=as_site) RETURN error('sudah diposting')

    -- agregasi draft per kategori untuk periode ini
    rs := SELECT cat.category_code,
                 cat.dep_expense_account AS acc_exp,
                 COALESCE(a.dep_expense_account,cat.dep_expense_account) ...
                 cat.accum_dep_account   AS acc_acc,
                 SUM(d.depreciation_amount) AS amt,
                 a.department
            FROM FA_DEPRECIATION d JOIN FA_ASSET a USING(site,asset_code)
                 JOIN FA_CATEGORY cat USING(site,category_code)
           WHERE d.site=as_site AND d.period=period_dt AND d.posting_status='D'
             AND cat.depreciable_yn='Y'
           GROUP BY cat.category_code, acc_exp, acc_acc, a.department

    total := SUM(rs.amt); IF total=0 RETURN ''
    urut := 0
    BEGIN TRANSACTION
        FOR each r in rs:
            urut++; INSERT gl_journal(voucher,urut,site_id,tgl=period_dt,modul_id='FA',
                account_id=r.acc_exp, debet=r.amt, kredit=0, debet_kurs=r.amt, kredit_kurs=0,
                curr_id='IDR', rate_rp=1, posting='P', voucher_manual=voucher,
                depart_id1=r.department, dk='D',
                ket='Penyusutan '+r.category_code+' '+MonthName(period_dt))
            urut++; INSERT gl_journal(... account_id=r.acc_acc, debet=0, kredit=r.amt,
                debet_kurs=0, kredit_kurs=r.amt, ... dk='K',
                ket='Akumulasi Penyusutan '+r.category_code)
        -- VALIDASI WAJIB sebelum commit (pola GL existing):
        ASSERT ROUND(SUM(debet)-SUM(kredit),2)=0
        UPDATE FA_DEPRECIATION SET posting_status='P', journal_no=voucher
               WHERE site=as_site AND period=period_dt AND posting_status='D'
        UPDATE FA_PERIOD SET status='P', journal_no=voucher, post_date=now, post_by=user
        f_userlog(user,'FA','POSTING','Depr '+YYYYMM,voucher)   -- ke USER_LOG
    COMMIT
    RETURN voucher
```
> Catatan jika ingin granularitas per-aset di GL: ganti agregasi jadi per `asset_code`. Default desain = **ringkas per kategori** (konsisten dengan pola "sub-ledger detail + GL summary" existing; detail tetap tertelusur di `FA_DEPRECIATION`).

### 7.4 Regenerate (reverse + recompute, integritas GL terjaga)
```
PROC f_fa_regenerate (adt_period, as_site):
    period_dt := EndOfMonth(adt_period)
    IF FA_PERIOD(site,period_dt).status='C' RETURN error('periode closed')
    voucher := 'FA'+as_site+Format(period_dt,'yyyymm')
    BEGIN TRANSACTION
        -- HANYA sentuh jurnal milik modul FA (governance: explicit, single source)
        DELETE gl_journal WHERE voucher=voucher AND site_id=as_site AND modul_id='FA'
        DELETE FA_DEPRECIATION WHERE site=as_site AND period=period_dt   -- buang P & D periode tsb
        UPDATE FA_PERIOD SET status='O', journal_no=NULL WHERE period=period_dt
        f_userlog(user,'FA','REGEN','Reverse depr '+voucher,voucher)
    COMMIT
    f_fa_generate(period_dt,period_dt,NULL,NULL,as_site)   -- recompute dari master terbaru
    f_fa_post_journal(period_dt,as_site)
```
Aturan keras: Regenerate menolak periode `status='C'` (closed); tidak pernah menghapus baris `gl_journal` dengan `modul_id<>'FA'`.

---

## 8. Desain DataWindow & Window (PowerBuilder)

### 8.1 Window
| Window | Fungsi | Pola acuan existing |
|---|---|---|
| `w_fa_category` | Maintenance kategori + mapping akun | `w_gl_category` / `w_mst_*` (master sederhana list+entry) |
| `w_fa_master` | Maintenance master aktiva (list + detail + lookup akun/depart) | `w_gl_journal` (tab list/detail), lookup akun ala `gl_acc` |
| `w_fa_generate` | Generate & Regenerate penyusutan (parameter from/to/category/asset) + preview + post | `w_refresh_journal` / `w_closing_journal` (batch + preview + commit) |
| `w_fa_disposal` | Pelepasan aktiva + jurnal laba/rugi | `w_gl_journal` (entry + posting) |
| `w_fa_import_saldo` | Import saldo awal 31/12/2025 (dari Excel/CSV) | `w_saldo_update_ap`/`w_saldo_update_ar`/`w_adm_saldo_*` (pola import saldo awal SUDAH ADA) |
| `w_rpt_fa_*` | Laporan (register, kartu, rekap) | `w_rpt_gl_*` / `w_rpt_journal` |

> Pola **import saldo awal sudah ada** di aplikasi (`w_saldo_update_ap`, `w_saldo_update_ar`, `dw_adm_saldo_ap/ar`). FA mengikuti pola yang sama → mengurangi risiko & effort.

### 8.2 DataWindow
| DataWindow | Tabel | Tipe | Catatan |
|---|---|---|---|
| `dw_fa_category_list` / `_entry` | FA_CATEGORY (+gl_acc lookup) | grid / freeform | validasi `DetailYN='1'` saat pilih akun |
| `dw_fa_asset_list` | FA_ASSET + FA_CATEGORY | grid read | filter status/kategori |
| `dw_fa_asset_entry` | FA_ASSET | freeform update | lookup akun, depart (`gl_depart`), project (`gl_project`) |
| `dw_fa_depr_calc` | FA_ASSET ⋈ FA_DEPRECIATION | grid read | preview hasil generate (sebelum post) |
| `dw_fa_journal_preview` | dihitung dari draft | grid read | tampilan Dr/Cr seperti `dw_journal*` |
| `dw_fa_journal_post` | gl_journal | **update DW** (insert) | dataobject untuk INSERT ke `gl_journal` (pola `dw_update`) |
| `dw_fa_import_saldo` | FA_ASSET | import (ImportFile/ImportClipboard) | kolom: kode, nama, kategori, cost, accum 31/12/2025, NBV, sisa umur |
| `dw_rpt_fa_register` | FA_ASSET + FA_CATEGORY | report | Daftar Aktiva Tetap |
| `dw_rpt_fa_card` | FA_ASSET + FA_DEPRECIATION | report (group) | Kartu Aktiva (history) |
| `dw_rpt_fa_rekap` | FA_DEPRECIATION (+cat/depart) | crosstab/group | Rekap per bulan/tahun/kategori/departemen |
| `dw_rpt_fa_gl_recon` | FA_DEPRECIATION vs gl_balance | report | rekonsiliasi akun aset/akumulasi/beban |

Update ke `gl_journal` mengikuti **pola Update-DataWindow** existing: DW tampilan read-only + DW khusus INSERT/UPDATE (`dw_fa_journal_post`).

---

## 9. Strategi Saldo Awal 31/12/2025

1. **Sumber:** `WP_Aset tetap_TAM 2026.xlsx` (worksheet aset tetap per kategori). Wajib diekstrak: per aset → kode, nama, kategori, tgl perolehan, harga perolehan, akumulasi 31/12/2025, NBV, umur ekonomis (& sisa umur), residu.
2. **Import** via `w_fa_import_saldo` → isi `FA_ASSET` dengan `accum_dep_beginning`, `book_value_beginning`, `beginning_period='2025-12-31'`, `useful_life_month`.
3. **TIDAK membuat jurnal GL untuk saldo awal.** Saldo akun `151/153/154/155` (aset) dan `158-xxx` (akumulasi) **sudah ada** di GL/`gl_balance` per 31/12/2025. Membuat jurnal opening akan **double-count**. Saldo awal FA hanya menyetel sub-ledger.
4. **Rekonsiliasi wajib:** Σ`acquisition_cost` per kategori = saldo akun aset GL 31/12/2025; Σ`accum_dep_beginning` per kategori = saldo akun `158-xxx` GL 31/12/2025. Selisih harus nol sebelum lanjut. (`dw_rpt_fa_gl_recon`.)

---

## 10. Strategi Generate Jurnal Januari–Juni 2026

1. **Pra-syarat kritis — cek dobel.** Sebelum generate, periksa apakah penyusutan Jan–Jun 2026 **sudah dibukukan manual** di GL (cari mutasi `412-066`/`158-xxx` dengan `modul_id='GJ'` periode 2026-01..06). 
   - Jika **sudah ada manual** → pilih satu: (a) reverse entri manual lalu generate FA, atau (b) set titik mulai FA pada bulan pertama yang belum dibukukan. **Jangan generate di atas entri manual** (dobel).
   - Jika **belum** → lanjut generate penuh Jan–Jun.
   > Pengecekan ini perlu data run; saat penyusunan dokumen koneksi DB sempat terputus, jadi **langkah ini wajib dijalankan saat implementasi**.
2. Loop `f_fa_generate('2026-01-31','2026-06-30',...)` → `f_fa_post_journal` per bulan. Menghasilkan voucher `FA101202601 … FA101202606`, masing-masing `posting='P'`, `modul_id='FA'`.
3. Validasi tiap bulan: `Σdebet=Σkredit`; akumulasi FA per kategori + saldo awal = saldo `158-xxx` GL setelah posting bulan tsb.
4. Update `gl_balance` mengikuti mekanisme closing existing (jurnal FA ikut ter-refresh karena `posting='P'`).

---

## 11. Integrasi dengan Closing
Dua opsi:
- **A (disarankan, decoupled):** Generate+Post penyusutan = langkah manual/batch di `w_fa_generate`, dijalankan **sebelum** `w_closing_journal`/`w_closing_gl` tiap bulan. Lebih aman, mudah di-regenerate, tidak menyentuh kode closing.
- **B (auto):** Sisipkan panggilan `f_fa_generate`+`f_fa_post_journal` di dalam alur closing. Lebih otomatis tapi mengubah kode closing (risiko regresi). 

Rekomendasi: **Opsi A** untuk MVP; pertimbangkan B setelah stabil.

---

## 12. Laporan
| Laporan | Isi | DataWindow |
|---|---|---|
| Daftar Aktiva Tetap (Register) | kode, nama, kategori, perolehan, akumulasi, NBV, status | `dw_rpt_fa_register` |
| Kartu Aktiva | history per aset: perolehan, penyusutan bulanan, mutasi, NBV berjalan | `dw_rpt_fa_card` |
| Rekap Penyusutan | per bulan/tahun/kategori/departemen | `dw_rpt_fa_rekap` |
| Rekonsiliasi GL | aset/akumulasi/beban FA vs `gl_balance` | `dw_rpt_fa_gl_recon` |

---

## 13. Risiko Implementasi

| # | Risiko | Dampak | Mitigasi |
|---|---|---|---|
| R1 | **Source PB export kosong** (3285 file 0 byte) | Logika `ue_save`/generate voucher GL tak terbaca → asumsi pada cara INSERT `gl_journal` | Jalankan ulang export (PBORCA) hingga isi terbaca; sebelum itu, **validasi pola insert lewat data nyata** (sudah dilakukan dari DB). |
| R2 | **Dobel posting** penyusutan Jan–Jun 2026 (jika sudah ada entri manual GJ) | Beban & akumulasi dobel, lap. keuangan salah | Pengecekan §10.1 wajib + `FA_PERIOD` + cek `EXISTS` voucher. |
| R3 | Saldo awal tak rekonsiliasi dgn GL 31/12/2025 | Sub-ledger ≠ GL | Rekonsiliasi §9.4 sebelum go-live (`dw_rpt_fa_gl_recon`). |
| R4 | `modul_id='FA'` belum dikenali report/closing existing yang memfilter modul | Jurnal FA tak ikut tampil di beberapa laporan GL | Inventarisasi laporan yang filter `modul_id`; tambahkan 'FA'. (Butuh source terbaca — lihat R1.) |
| R5 | Pembulatan menyebabkan NBV ≠ residu di akhir umur | Selisih recehan | Bulan terakhir diratakan (`§6`, `MIN(monthly,remaining)`). |
| R6 | Umur/residu dari Excel belum dikonfirmasi | Nilai penyusutan salah | Kunci nilai dari `WP_Aset tetap_TAM 2026.xlsx` sebelum generate; seed §5.7 hanya placeholder. |
| R7 | Regenerate menghapus jurnal periode yang sudah closed | Korup GL terkunci | Tolak regen bila `FA_PERIOD.status='C'`; hanya hapus baris `modul_id='FA'`. |
| R8 | Multi-currency aktiva | Jarang utk aset lokal; tapi `gl_journal` punya kurs | Default `curr_id` base, `rate_rp=1`; dukung kurs hanya bila aset valas ada. |
| R9 | Engine SQLA auto-start sempat gagal restart saat sesi ini | Operasional | Bukan isu modul; pastikan engine `vsp` stabil sebelum batch besar. |

---

## 14. Estimasi Effort (indikatif, 1 developer PB+SQLA berpengalaman)

| Fase | Aktivitas | Estimasi |
|---|---|---|
| 0 | Re-export source + baca pola `gl_journal` insert (resolusi R1) | 1–2 hari |
| 1 | DDL 5 tabel + seed kategori + uji skema | 1 hari |
| 2 | `w_fa_category` + `w_fa_master` + DW + audit field-level | 4–6 hari |
| 3 | Mesin penyusutan (`f_fa_calc/generate`) + preview | 3–4 hari |
| 4 | Generate Journal + Regenerate ke `gl_journal` + validasi balance | 3–4 hari |
| 5 | Import saldo awal + rekonsiliasi 31/12/2025 | 2–3 hari |
| 6 | Generate Jan–Jun 2026 + cek dobel + rekon bulanan | 2 hari |
| 7 | Disposal + jurnal laba/rugi | 2–3 hari |
| 8 | 4 laporan | 3–4 hari |
| 9 | Integrasi menu/otorisasi + UAT + perbaikan | 4–5 hari |
| 10 | Deployment + training + dokumentasi | 2 hari |
| | **Total** | **±27–36 hari kerja (≈ 6–7 minggu)** |

UAT ditekankan pada: akurasi vs Excel (±0,01), `Σdebet=Σkredit`, rekonsiliasi GL, idempotensi Regenerate.

---

## 15. Rekomendasi Struktur Source PowerBuilder
Selaras pola PBL existing (per modul GL: `gl_trans`, `gl_report`). Buat library baru **`fa_trans.pbl`** (transaksi/master/generate) dan **`fa_report.pbl`** (laporan), sejajar `gl_trans`/`gl_report`:

```
fa_trans.pbl
  w_fa_category, w_fa_master, w_fa_generate, w_fa_disposal, w_fa_import_saldo
  dw_fa_category_*, dw_fa_asset_*, dw_fa_depr_calc, dw_fa_journal_preview, dw_fa_journal_post, dw_fa_import_saldo
  n_fa_engine (user object: f_fa_calc_one, f_fa_generate, f_fa_post_journal, f_fa_regenerate, f_fa_validate_accounts, f_fa_get_bookvalue)
fa_report.pbl
  w_rpt_fa_register, w_rpt_fa_card, w_rpt_fa_rekap, w_rpt_fa_gl_recon
  dw_rpt_fa_register, dw_rpt_fa_card, dw_rpt_fa_rekap, dw_rpt_fa_gl_recon
```
Fungsi GL reuse: nomor voucher & insert `gl_journal` lewat object/function existing (teridentifikasi setelah R1 teratasi) — **jangan** menulis ulang engine jurnal.

---

## 16. Keputusan yang Perlu Konfirmasi User (sebelum coding)
1. **Granularitas jurnal GL:** ringkas per kategori (default desain) **atau** per aset?
2. **modul_id:** pakai `'FA'` (disarankan, eksplisit) atau menumpang `'GJ'` dengan prefix voucher `'FA'`?
3. **Penyusutan Jan–Jun 2026 sudah dibukukan manual?** (menentukan strategi §10.1). 
4. **Umur ekonomis & residu final** per kategori (dari Excel) — konfirmasi angka.
5. **Timing penyusutan:** akhir bulan (default) atau awal bulan?
6. **Disposal:** rumus laba/rugi = harga jual − NBV; NBV = cost − akumulasi (konfirmasi perlakuan).

---

*Disusun 2026-06-17. Fakta GL diverifikasi langsung dari database `vsp`. Bagian yang belum terverifikasi ditandai eksplisit (umur/residu Excel, distribusi flag posting, dobel-posting 2026, isi source PB).*
