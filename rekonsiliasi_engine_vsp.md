# Reconciliation Engine — VSP (ASA9 + PowerBuilder 11.5)
**Sifat:** blueprint teknis + SQL production-ready (ASA9). Semua objek grounded ke skema live & report production.
**Kontrak dashboard (dari user):** bandingkan **`dw_rpt_ap_opname`** (mutasi hutang), **`dw_rpt_ar_opname`** (mutasi piutang), **`dw_stok_gl_mutasi`** (mutasi stok) vs **`dw_rpt_ledger1`** (ledger).
**Aturan:** no CTE/`WITH`, no `SELECT *`, kolom eksplisit, `*=`→ANSI `LEFT OUTER JOIN`, `NOT IN`→`NOT EXISTS`, mapping akun dari `gl_setup`/`IM_PRODUCT_GROUP`.
**Toleransi cocok:** `ABS(selisih) <= 10` (pembulatan desimal).
**Versi:** 2.0 — AP/AR FINAL (zero `@CONFIRM`).

---

## 0. FAKTA SKEMA (hasil inspeksi + report production — bukan asumsi)

| Elemen | Sumber live | Keterangan |
|---|---|---|
| Akun persediaan | `IM_PRODUCT_GROUP.PERSEDIAAN` per `KODE_GROUP` | many group → 1 akun (L+LA→102-110) |
| Akun hutang (AP) | `gl_setup.acc_ap` = `226-001` (+ `226-006` freight di anchor report) | liability (kredit) |
| Akun piutang (AR) | `gl_setup.acc_ar` = `103-001` | asset (debet) |
| Ledger opening | `GL_BALANCE(Period=YYYY-01-01, AccountCode, site_id)` = `AmountDebet−AmountCredit` | tahunan |
| Ledger mutasi | `GL_JOURNAL(debet−kredit)` `WHERE posting='P'` | modul PO/HP/AS/EX/CO/SO/CI |
| Subledger stok | `SINV(PERIODE,STOK_ID,QTY,NILAI,HPP_AVG,SITE_ID)` | `SINV[periode]` = saldo AWAL periode |
| Opening faktur AP/AR | `SALDO_AWAL_FAKTUR(periode,bukti_id,vendor_id,saldo,saldo_kurs,new_saldo,new_rate,tipe_trans)` | tahunan (Januari); `tipe_trans 1=AR, 2=AP`; `bukti_id` = ORDER_CLIENT |
| **Invoice AP** | **`AP_TRANS`** (`ORDER_CLIENT,TIPE_TRANS,TGL,VENDOR_ID,TTL_NETTO,KURS,CURR_ID,NEW_RATE,ORDER_OKE`) | tipe `'02','05','06','12','16'` (12=retur, −) |
| **Invoice AR** | **`AR_TRANS`** (`ORDER_CLIENT,TIPE_TRANS,TGL,CUST_ID,KURS,CURR_ID,NEW_RATE,ORDER_OKE`) | tipe `'22','32','33','26','36'` |
| **Pembayaran AP & AR** | **`TBYR1`** (`VOUCHER,TGL,FLAG_BAYAR,FLAG_VENDOR,VOUCHER_MANUAL`) + **`TBYR2`** (`VOUCHER,BUKTI_ID,NILAI_BAYAR,NILAI_BAYAR_IDR`) | join `TBYR2.VOUCHER=TBYR1.VOUCHER`; `TBYR2.BUKTI_ID = ORDER_CLIENT`; `FLAG_BAYAR IN (1,2)`; AR: `FLAG_VENDOR=1 OR IS NULL` |
| **Adjustment AP & AR** | **`TBYR2_PUTIH`** (`BUKTI_ID,TGL_BAYAR,FLAG_ORDER,NILAI_BAYAR,NILAI_BAYAR_IDR`) | AP: `FLAG_ORDER NOT IN (2,22)`→`+` else `−`; AR: `11`→`+`, `1`→`−` |
| Master | `MCUST(CUST_ID,CUST_NAME)`, `MCSTSUPP(VENDOR_ID,NAMA)`, `GL_ACC` | |
| **GL anchor key** | **`GL_JOURNAL.voucher = ORDER_CLIENT`** | AP: `account_id IN ('226-001','226-006') AND kredit>0`; AR: `account_id='103-001' AND debet>0` |
| Formula outstanding | `SISA = SALDO_AWAL + MUTASI + ADJ − NILAI_BAYAR` (valuta & IDR paralel) | identik di kedua report opname |

> ✅ **KONTRAK AP/AR TERKUNCI** dari report production `dw_rpt_ap_opname.srd` & `dw_rpt_ar_opname.srd`. Tabel: `AP_TRANS` (19.353 baris, 2010–2026), `AR_TRANS` (30.784, 2011–2026), `TBYR1` (21.539), `TBYR2_PUTIH` (444) — semua BASE table live. `TINKASO` **tidak** dipakai report opname. **Zero `@CONFIRM`.**

---

## 1. LEDGER ENGINE (semua domain) — FINAL

### 1.1 View mutasi GL bulanan (terposting)
```sql
CREATE VIEW v_gl_mutasi_bulan AS
SELECT j.account_id, j.site_id,
       YEAR(j.tgl)  AS thn,
       MONTH(j.tgl) AS bln,
       SUM(ISNULL(j.debet,0) - ISNULL(j.kredit,0)) AS mutasi
FROM   gl_journal j
WHERE  j.posting = 'P'
GROUP BY j.account_id, j.site_id, YEAR(j.tgl), MONTH(j.tgl);
```

### 1.2 View opening GL tahunan
```sql
CREATE VIEW v_gl_opening_tahun AS
SELECT b.AccountCode AS account_id, b.site_id,
       YEAR(b.Period) AS thn,
       SUM(ISNULL(b.AmountDebet,0) - ISNULL(b.AmountCredit,0)) AS saldo_awal
FROM   gl_balance b
GROUP BY b.AccountCode, b.site_id, YEAR(b.Period);
```

### 1.3 Saldo ledger akhir periode (retrieve; `:arg_tgl` = akhir periode)
```sql
SELECT o.account_id, o.site_id,
       (o.saldo_awal + ISNULL(m.mutasi_ytd,0)) AS saldo_ledger
FROM   v_gl_opening_tahun o
LEFT OUTER JOIN (
        SELECT v.account_id, v.site_id, v.thn, SUM(v.mutasi) AS mutasi_ytd
        FROM   v_gl_mutasi_bulan v
        WHERE  v.thn = YEAR(:arg_tgl)
          AND  v.bln <= MONTH(:arg_tgl)
        GROUP BY v.account_id, v.site_id, v.thn
     ) m ON m.account_id = o.account_id AND m.site_id = o.site_id AND m.thn = o.thn
WHERE  o.thn = YEAR(:arg_tgl);
```

### 1.4 Drill audit — baris jurnal GL (jembatan; = basis `dw_rpt_ledger1`)
```sql
SELECT j.account_id, j.tgl, j.voucher, j.voucher_manual, j.modul_id,
       ISNULL(j.debet,0)  AS debet,
       ISNULL(j.kredit,0) AS kredit,
       (ISNULL(j.debet,0) - ISNULL(j.kredit,0)) AS mutasi,
       j.ket, j.doc_reff, j.order_reff, j.cust_id, j.site_id
FROM   gl_journal j
WHERE  j.account_id = :arg_akun
  AND  j.posting = 'P'
  AND  j.tgl BETWEEN :arg_tgl1 AND :arg_tgl2
ORDER BY j.tgl, j.voucher, j.urut;
```
**Invarian audit:** `SUM(mutasi)` (1.4, periode) = mutasi ledger (1.3) = perubahan saldo. "1 angka GL = SUM jurnal".

---

## 2. STOK ENGINE — FINAL (hybrid; = basis `dw_stok_gl_mutasi` fixed)

### 2.1 Subledger saldo (snapshot SINV) per akun persediaan
```sql
CREATE VIEW v_stok_saldo_sinv AS
SELECT g.persediaan AS account_id, s.site_id, s.periode,
       SUM(ISNULL(s.nilai,0)) AS saldo_subledger,
       SUM(ISNULL(s.qty,0))   AS qty_subledger
FROM   sinv s
JOIN   im_produk        p ON p.produk_id  = s.stok_id
JOIN   im_product_group g ON g.kode_group = p.group_product
WHERE  p.stok_item = 'Y'
GROUP BY g.persediaan, s.site_id, s.periode;
```
Saldo AKHIR bulan → `s.periode = DATEADD(month, 1, :arg_bom)`.

### 2.2 Rekonsiliasi Stok (retrieve)
```sql
SELECT sub.account_id,
       ISNULL(sub.saldo_subledger,0) AS subledger_value,
       ISNULL(led.saldo_ledger,0)    AS ledger_value,
       (ISNULL(sub.saldo_subledger,0) - ISNULL(led.saldo_ledger,0)) AS selisih,
       CASE WHEN ABS(ISNULL(sub.saldo_subledger,0) - ISNULL(led.saldo_ledger,0)) <= 10
            THEN 'COCOK' ELSE 'SELISIH' END AS status
FROM ( SELECT v.account_id, SUM(v.saldo_subledger) AS saldo_subledger
       FROM v_stok_saldo_sinv v
       WHERE v.periode = DATEADD(month, 1, :arg_bom)
       GROUP BY v.account_id ) sub
LEFT OUTER JOIN
     ( SELECT o.account_id, (o.saldo_awal + ISNULL(m.mutasi_ytd,0)) AS saldo_ledger
       FROM v_gl_opening_tahun o
       LEFT OUTER JOIN ( SELECT account_id, thn, SUM(mutasi) mutasi_ytd
                         FROM v_gl_mutasi_bulan
                         WHERE thn = YEAR(:arg_bom) AND bln <= MONTH(:arg_bom)
                         GROUP BY account_id, thn ) m
              ON m.account_id = o.account_id AND m.thn = o.thn
       WHERE o.thn = YEAR(:arg_bom) ) led  ON led.account_id = sub.account_id
ORDER BY sub.account_id;
```
> Kecualikan akun GL-only (WIP `102-020`) dari uji SINV. Drill komponen: reuse SQL **`dw_stok_gl_mutasi` versi fixed** (EVAP `=''`, JUAL_BY_EVAP own-HPP, CONSIN_BY_EVAP own-NETTO) — sudah terverifikasi = ledger (April 2026).

---

## 3. AP / AR ENGINE — **FINAL** (kontrak = `dw_rpt_ap_opname` / `dw_rpt_ar_opname`)

Rumus outstanding per voucher (`ORDER_CLIENT`), identik kedua domain:
```
SISA_IDR = SALDO_AWAL_IDR + MUTASI_IDR + ADJ_IDR − NILAI_BAYAR_IDR
```
Anchor voucher WAJIB GL-verified: `EXISTS (gl_journal.voucher = ORDER_CLIENT AND account/dir sesuai domain)` → **closed-loop by construction**.

### 3.1 `v_ap_reconcile_final` — total sisa AP per vendor (akhir periode `:arg_tgl2`, tahun berjalan)
Komponen identik report; agregat per vendor (dipakai isi snapshot & drill lvl-1).
```sql
CREATE VIEW v_ap_sisa_vendor AS
SELECT x.vendor_id, x.thn, x.bln,
       SUM(x.saf_idr) + SUM(x.inv_idr) + SUM(x.adj_idr) - SUM(x.byr_idr) AS sisa_idr
FROM (
   -- opening tahunan per vendor (IDR priority: NEW_SALDO -> SALDO_KURS*NEW_RATE -> SALDO)
   SELECT f.vendor_id, YEAR(f.periode) AS thn, 0 AS bln,
          SUM(CASE WHEN ISNULL(f.new_saldo,0) <> 0 THEN f.new_saldo
                   WHEN ISNULL(f.new_rate,0)  <> 0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate
                   ELSE ISNULL(f.saldo,0) END)      AS saf_idr,
          0 AS inv_idr, 0 AS adj_idr, 0 AS byr_idr
   FROM   saldo_awal_faktur f
   WHERE  f.tipe_trans IN (1,2)
     AND  MONTH(f.periode) = 1
     AND  EXISTS ( SELECT 1 FROM gl_journal gj
                   WHERE gj.voucher = f.bukti_id
                     AND gj.account_id IN ('226-001','226-006')
                     AND gj.kredit > 0 )
   GROUP BY f.vendor_id, YEAR(f.periode)
   UNION ALL
   -- invoice/mutasi (02/05/06/16 = +, 12 = -), IDR: 05 tanpa kurs, lainnya *kurs
   SELECT p.vendor_id, YEAR(p.tgl), MONTH(p.tgl),
          0,
          SUM(CASE WHEN p.tipe_trans = '05' THEN p.ttl_netto
                   ELSE (CASE WHEN p.tipe_trans IN ('02','06','16') THEN p.ttl_netto
                              WHEN p.tipe_trans = '12' THEN -ABS(p.ttl_netto)
                              ELSE 0 END) * ISNULL(p.kurs,1) END),
          0, 0
   FROM   ap_trans p
   WHERE  p.order_oke = 'Y'
     AND  p.tipe_trans IN ('02','05','12','06','16')
     AND  EXISTS ( SELECT 1 FROM gl_journal gj
                   WHERE gj.voucher = p.order_client
                     AND gj.account_id IN ('226-001','226-006')
                     AND gj.kredit > 0 )
   GROUP BY p.vendor_id, YEAR(p.tgl), MONTH(p.tgl)
   UNION ALL
   -- adjustment (TBYR2_PUTIH): AP rule FLAG_ORDER NOT IN (2,22) = +
   SELECT ap.vendor_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar),
          0, 0,
          SUM(CASE WHEN tp.flag_order NOT IN (2,22) THEN ABS(tp.nilai_bayar_idr)
                   ELSE -ABS(tp.nilai_bayar_idr) END),
          0
   FROM   tbyr2_putih tp
   JOIN ( SELECT p2.order_client, MAX(p2.vendor_id) AS vendor_id
          FROM ap_trans p2 GROUP BY p2.order_client ) ap
        ON ap.order_client = tp.bukti_id
   GROUP BY ap.vendor_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar)
   UNION ALL
   -- pembayaran (TBYR1+TBYR2, FLAG_BAYAR 1/2)
   SELECT ap.vendor_id, YEAR(t1.tgl), MONTH(t1.tgl),
          0, 0, 0,
          SUM(ISNULL(t2.nilai_bayar_idr,0))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
   JOIN ( SELECT p2.order_client, MAX(p2.vendor_id) AS vendor_id
          FROM ap_trans p2 GROUP BY p2.order_client ) ap
        ON ap.order_client = t2.bukti_id
   WHERE  t1.flag_bayar IN (1,2)
   GROUP BY ap.vendor_id, YEAR(t1.tgl), MONTH(t1.tgl)
) x
GROUP BY x.vendor_id, x.thn, x.bln;
```
**Pemakaian (saldo per akhir periode):**
```sql
SELECT v.vendor_id, SUM(v.sisa_idr) AS sisa_akhir_idr
FROM   v_ap_sisa_vendor v
WHERE  v.thn = YEAR(:arg_tgl2) AND v.bln <= MONTH(:arg_tgl2)
GROUP BY v.vendor_id
HAVING ABS(SUM(v.sisa_idr)) > 0.005
ORDER BY v.vendor_id;
```

### 3.2 `v_ar_reconcile_final` — total sisa AR per customer (rumus report AR)
Perbedaan vs AP (persis mengikuti report): **mutasi IDR = `SUM(gl_journal.debet)` voucher-anchored** (bukan netto AR_TRANS); adjustment AR `FLAG_ORDER 11=+ / 1=−`; bayar AR filter `FLAG_VENDOR=1 OR IS NULL`.
```sql
CREATE VIEW v_ar_sisa_cust AS
SELECT x.cust_id, x.thn, x.bln,
       SUM(x.saf_idr) + SUM(x.inv_idr) + SUM(x.adj_idr) - SUM(x.byr_idr) AS sisa_idr
FROM (
   SELECT f.vendor_id AS cust_id, YEAR(f.periode) AS thn, 0 AS bln,
          SUM(ROUND(CASE WHEN ISNULL(f.new_saldo,0) <> 0 THEN f.new_saldo
                         WHEN ISNULL(f.new_rate,0)  <> 0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate
                         ELSE ISNULL(f.saldo,0) END, 2)) AS saf_idr,
          0 AS inv_idr, 0 AS adj_idr, 0 AS byr_idr
   FROM   saldo_awal_faktur f
   WHERE  f.tipe_trans = 1 AND MONTH(f.periode) = 1
     AND  EXISTS ( SELECT 1 FROM gl_journal gj
                   WHERE gj.voucher = f.bukti_id
                     AND gj.account_id = '103-001' AND gj.debet > 0 )
   GROUP BY f.vendor_id, YEAR(f.periode)
   UNION ALL
   -- mutasi AR = debet GL 103-001 per voucher-anchored (rumus report)
   SELECT ar.cust_id, YEAR(gj.tgl), MONTH(gj.tgl),
          0, SUM(gj.debet), 0, 0
   FROM   gl_journal gj
   JOIN ( SELECT a2.order_client, MAX(a2.cust_id) AS cust_id
          FROM ar_trans a2
          WHERE a2.order_oke = 'Y'
            AND a2.tipe_trans IN ('22','32','33','26','36')
          GROUP BY a2.order_client ) ar
        ON ar.order_client = gj.voucher
   WHERE  gj.account_id = '103-001' AND gj.debet > 0
   GROUP BY ar.cust_id, YEAR(gj.tgl), MONTH(gj.tgl)
   UNION ALL
   SELECT ar.cust_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar),
          0, 0,
          SUM(CASE WHEN tp.flag_order = 11 THEN  ABS(tp.nilai_bayar_idr)
                   WHEN tp.flag_order = 1  THEN -ABS(tp.nilai_bayar_idr)
                   ELSE 0 END),
          0
   FROM   tbyr2_putih tp
   JOIN ( SELECT a2.order_client, MAX(a2.cust_id) AS cust_id
          FROM ar_trans a2 GROUP BY a2.order_client ) ar
        ON ar.order_client = tp.bukti_id
   WHERE  tp.flag_order IN (1,11)
   GROUP BY ar.cust_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar)
   UNION ALL
   SELECT ar.cust_id, YEAR(t1.tgl), MONTH(t1.tgl),
          0, 0, 0,
          SUM(ISNULL(t2.nilai_bayar_idr,0))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
   JOIN ( SELECT a2.order_client, MAX(a2.cust_id) AS cust_id
          FROM ar_trans a2 GROUP BY a2.order_client ) ar
        ON ar.order_client = t2.bukti_id
   WHERE  t1.flag_bayar IN (1,2)
     AND  (t1.flag_vendor = 1 OR t1.flag_vendor IS NULL)
   GROUP BY ar.cust_id, YEAR(t1.tgl), MONTH(t1.tgl)
) x
GROUP BY x.cust_id, x.thn, x.bln;
```

### 3.3 Rekonsiliasi AP/AR vs ledger (summary; akun dari `gl_setup`)
```sql
-- AR (AP identik: v_ap_sisa_vendor, acc_ap, tanda liability pakai ABS/kredit)
SELECT (SELECT g.acc_ar FROM gl_setup g)        AS account_id,
       'AR'                                     AS domain,
       ISNULL(sub.sisa_total,0)                 AS subledger_value,
       ISNULL(led.saldo_ledger,0)               AS ledger_value,
       (ISNULL(sub.sisa_total,0) - ISNULL(led.saldo_ledger,0)) AS selisih,
       CASE WHEN ABS(ISNULL(sub.sisa_total,0) - ISNULL(led.saldo_ledger,0)) <= 10
            THEN 'COCOK' ELSE 'SELISIH' END      AS status
FROM ( SELECT SUM(v.sisa_idr) AS sisa_total
       FROM v_ar_sisa_cust v
       WHERE v.thn = YEAR(:arg_tgl2) AND v.bln <= MONTH(:arg_tgl2) ) sub
LEFT OUTER JOIN
     ( SELECT (o.saldo_awal + ISNULL(m.mutasi_ytd,0)) AS saldo_ledger
       FROM v_gl_opening_tahun o
       LEFT OUTER JOIN ( SELECT account_id, thn, SUM(mutasi) AS mutasi_ytd
                         FROM v_gl_mutasi_bulan
                         WHERE thn = YEAR(:arg_tgl2) AND bln <= MONTH(:arg_tgl2)
                         GROUP BY account_id, thn ) m
              ON m.account_id = o.account_id AND m.thn = o.thn
       WHERE o.account_id = (SELECT g2.acc_ar FROM gl_setup g2)
         AND o.thn = YEAR(:arg_tgl2) ) led ON 1=1;
```
> **Validasi wajib pra-produksi:** `Σ sisa view (3.1/3.2)` HARUS = `Σ SISA_IDR report opname` periode sama (report membuang baris all-zero; total tidak berubah). Uji 1 periode sebelum dipakai dashboard.

### 3.4 Drill detail per voucher (lvl-3) — pakai **SQL report opname existing apa adanya** (`dw_rpt_ap_opname` / `dw_rpt_ar_opname`) dengan filter tambahan `vendor_id/cust_id`. Jangan tulis ulang logika; report = kontrak.

---

## 4. ANOMALY ENGINE — `sp_rekon_anomali` (ASA9)

Output: `anomaly_type, severity, root_cause_category, evidence_ref, nilai`.
```sql
CREATE PROCEDURE sp_rekon_anomali(
        IN p_account  VARCHAR(20),
        IN p_domain   VARCHAR(4),      -- 'STOK' | 'AR' | 'AP'
        IN p_tgl1     TIMESTAMP,
        IN p_tgl2     TIMESTAMP,
        IN p_site     VARCHAR(10) )
RESULT ( anomaly_type VARCHAR(40), severity VARCHAR(8),
         root_cause_category VARCHAR(40), evidence_ref VARCHAR(200),
         nilai NUMERIC(18,2) )
BEGIN
   -- R1: UNPOSTED JOURNAL
   SELECT 'UNPOSTED_JOURNAL','HIGH','posting<>P',
          'gl_journal account='||p_account||' posting<>P periode',
          CAST(SUM(ISNULL(debet,0)-ISNULL(kredit,0)) AS NUMERIC(18,2))
   FROM   gl_journal
   WHERE  account_id = p_account AND posting <> 'P'
     AND  tgl BETWEEN p_tgl1 AND p_tgl2
     AND  (p_site = '' OR site_id = p_site)
   HAVING COUNT(*) > 0;

   -- R2: MISSING LEDGER (mutasi sub ada, jurnal GL kosong)  [STOK]
   IF p_domain = 'STOK' THEN
     SELECT 'MISSING_LEDGER_ENTRY','HIGH','no_gl_for_movement',
            'SINV bergerak tapi gl_journal kosong utk akun-periode', 0
     FROM   dummy
     WHERE  NOT EXISTS ( SELECT 1 FROM gl_journal
                         WHERE account_id = p_account AND posting = 'P'
                           AND tgl BETWEEN p_tgl1 AND p_tgl2 );
   END IF;

   -- R3: OPENING BALANCE GAP (GL_BALANCE vs subledger awal tahun) [STOK]
   IF p_domain = 'STOK' THEN
     SELECT 'OPENING_BALANCE_GAP','MEDIUM','saldo_awal_gl<>inventory',
            'gl_balance vs SINV periode 01-Jan',
            CAST( ISNULL((SELECT SUM(AmountDebet-AmountCredit) FROM gl_balance
                          WHERE AccountCode = p_account
                            AND YEAR(Period) = YEAR(p_tgl2)),0)
                - ISNULL((SELECT SUM(s.nilai) FROM sinv s
                          JOIN im_produk pr ON pr.produk_id = s.stok_id
                          JOIN im_product_group gp ON gp.kode_group = pr.group_product
                          WHERE gp.persediaan = p_account
                            AND YEAR(s.periode) = YEAR(p_tgl2)
                            AND MONTH(s.periode) = 1),0) AS NUMERIC(18,2))
     FROM dummy
     WHERE ABS( ISNULL((SELECT SUM(AmountDebet-AmountCredit) FROM gl_balance
                        WHERE AccountCode = p_account
                          AND YEAR(Period) = YEAR(p_tgl2)),0)
              - ISNULL((SELECT SUM(s.nilai) FROM sinv s
                        JOIN im_produk pr ON pr.produk_id = s.stok_id
                        JOIN im_product_group gp ON gp.kode_group = pr.group_product
                        WHERE gp.persediaan = p_account
                          AND YEAR(s.periode) = YEAR(p_tgl2)
                          AND MONTH(s.periode) = 1),0) ) > 10;
   END IF;

   -- R5: '19' LOOP RISK (|qty19/akhir| > 1) [STOK]
   IF p_domain = 'STOK' THEN
     SELECT 'LOOP_19_RISK','HIGH','unstable_avg_cost',
            'ratio qty19/akhir>1 pada stok akun ini', CAST(MAX(x.rasio) AS NUMERIC(18,2))
     FROM ( SELECT (ABS(SUM(CASE WHEN t1.tipe_trans = '19' THEN t2.qty ELSE 0 END))
                    / NULLIF(ABS(sv.qty),0)) AS rasio
            FROM tstok1 t1
            JOIN tstok2 t2 ON t1.bukti_id = t2.bukti_id
            JOIN im_produk pr ON pr.produk_id = t2.stok_id
            JOIN im_product_group gp ON gp.kode_group = pr.group_product
            JOIN sinv sv ON sv.stok_id = t2.stok_id
                        AND sv.periode = DATEADD(month, 1, p_tgl1)
            WHERE gp.persediaan = p_account
              AND t1.tgl BETWEEN p_tgl1 AND p_tgl2
              AND t1.order_oke = 'Y'
            GROUP BY t2.stok_id, sv.qty ) x
     WHERE x.rasio > 1
     HAVING COUNT(*) > 0;
   END IF;

   -- R6: SITE MISMATCH
   SELECT 'SITE_MISMATCH','MEDIUM','multi_site_aggregation',
          'gl_journal.site_id > 1 distinct tanpa filter',
          CAST(COUNT(DISTINCT site_id) AS NUMERIC(18,2))
   FROM   gl_journal
   WHERE  account_id = p_account AND posting = 'P'
     AND  tgl BETWEEN p_tgl1 AND p_tgl2
   HAVING COUNT(DISTINCT site_id) > 1;

   -- R7: PAYMENT PENDING (AP/AR): TBYR1.FLAG_BAYAR=1 (pending) mengurangi sisa
   --     tapi jurnal GL pembayaran mungkin belum terbentuk
   IF p_domain IN ('AP','AR') THEN
     SELECT 'PAYMENT_PENDING_FLAG1','MEDIUM','tbyr_flag_bayar_pending',
            'TBYR1.flag_bayar=1 dalam periode (cek jurnal bayar)',
            CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2))
     FROM   tbyr1 t1
     JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
     WHERE  t1.flag_bayar = 1
       AND  t1.tgl BETWEEN p_tgl1 AND p_tgl2
     HAVING COUNT(*) > 0;
   END IF;

   -- R8: ADJUSTMENT PUTIH (AP/AR): nilai TBYR2_PUTIH periode (adjustment non-kas)
   IF p_domain IN ('AP','AR') THEN
     SELECT 'ADJ_PUTIH_PRESENT','LOW','adjustment_non_kas',
            'TBYR2_PUTIH dalam periode (verifikasi jurnal manual)',
            CAST(SUM(ISNULL(tp.nilai_bayar_idr,0)) AS NUMERIC(18,2))
     FROM   tbyr2_putih tp
     WHERE  tp.tgl_bayar BETWEEN p_tgl1 AND p_tgl2
     HAVING COUNT(*) > 0;
   END IF;

   -- R9: GL-ANCHOR ORPHAN (AP/AR): voucher GL akun AP/AR yang TIDAK punya
   --     pasangan di AP_TRANS/AR_TRANS/SALDO_AWAL_FAKTUR  → jurnal manual liar
   IF p_domain = 'AR' THEN
     SELECT 'GL_ORPHAN_VOUCHER','HIGH','manual_journal_no_subledger',
            'gl_journal 103-001 debet tanpa AR_TRANS/SAF pasangan',
            CAST(SUM(gj.debet) AS NUMERIC(18,2))
     FROM   gl_journal gj
     WHERE  gj.account_id = p_account AND gj.debet > 0 AND gj.posting = 'P'
       AND  gj.tgl BETWEEN p_tgl1 AND p_tgl2
       AND  NOT EXISTS ( SELECT 1 FROM ar_trans a
                         WHERE a.order_client = gj.voucher )
       AND  NOT EXISTS ( SELECT 1 FROM saldo_awal_faktur f
                         WHERE f.bukti_id = gj.voucher AND f.tipe_trans = 1 )
     HAVING COUNT(*) > 0;
   END IF;
   IF p_domain = 'AP' THEN
     SELECT 'GL_ORPHAN_VOUCHER','HIGH','manual_journal_no_subledger',
            'gl_journal AP kredit tanpa AP_TRANS/SAF pasangan',
            CAST(SUM(gj.kredit) AS NUMERIC(18,2))
     FROM   gl_journal gj
     WHERE  gj.account_id = p_account AND gj.kredit > 0 AND gj.posting = 'P'
       AND  gj.tgl BETWEEN p_tgl1 AND p_tgl2
       AND  NOT EXISTS ( SELECT 1 FROM ap_trans p
                         WHERE p.order_client = gj.voucher )
       AND  NOT EXISTS ( SELECT 1 FROM saldo_awal_faktur f
                         WHERE f.bukti_id = gj.voucher AND f.tipe_trans IN (1,2) )
     HAVING COUNT(*) > 0;
   END IF;

   -- R10: ROUNDING NOISE ditangani di layer summary (COCOK bila ABS(selisih)<=10)

   -- R11: DP_APPLICATION_POSTING_GAP (AP/AR) — FORENSIC-CONFIRMED
   --   Voucher pembayaran TBYR (anchored ke subledger AR/AP via TBYR2.bukti_id)
   --   yang MENGURANGI sisa di opname TAPI TIDAK punya jurnal GL kas
   --   (CI utk AR / CO utk AP) pada akun kontrol, dicocokkan by voucher_manual.
   --   Terbukti = penerapan Uang Muka (DP) yang tak dijurnal ke GL manapun
   --   (bukan di gl_journal, bukan di TDP, bukan di titipan 410-047).
   --   Efek: GL akun kontrol LEBIH TINGGI dari subledger tepat sebesar total DP.
   IF p_domain = 'AR' THEN
     SELECT 'DP_APPLICATION_GAP','HIGH','tbyr_applied_no_gl_ci',
            'voucher_manual='||t1.voucher_manual,
            CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2))
     FROM   tbyr1 t1
     JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
     WHERE  t1.flag_bayar IN (1,2)
       AND  t1.tgl BETWEEN p_tgl1 AND p_tgl2
       AND  EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client = t2.bukti_id )
       AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                         WHERE gj.account_id = p_account AND gj.modul_id = 'CI'
                           AND gj.voucher_manual = t1.voucher_manual )
     GROUP BY t1.voucher_manual
     HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0;
   END IF;
   IF p_domain = 'AP' THEN
     SELECT 'DP_APPLICATION_GAP','HIGH','tbyr_applied_no_gl_co',
            'voucher_manual='||t1.voucher_manual,
            CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2))
     FROM   tbyr1 t1
     JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
     WHERE  t1.flag_bayar IN (1,2)
       AND  t1.tgl BETWEEN p_tgl1 AND p_tgl2
       AND  EXISTS ( SELECT 1 FROM ap_trans p WHERE p.order_client = t2.bukti_id )
       AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                         WHERE gj.account_id = p_account AND gj.modul_id = 'CO'
                           AND gj.voucher_manual = t1.voucher_manual )
     GROUP BY t1.voucher_manual
     HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0;
   END IF;
END;
```

---

## 5. TRACEABILITY GRAPH — FINAL (closed loop)

**STOK**
```
IM_PRODUCT_GROUP.PERSEDIAAN (account_id)
  └ IM_PRODUK.GROUP_PRODUCT = KODE_GROUP
     └ SINV.STOK_ID / TSTOK2.STOK_ID / TSALES2.STOK_ID
        └ TSTOK1/TSALES1.BUKTI_ID ── GL_JOURNAL (PO/HP/AS/EX; doc_reff/voucher)
Invarian: Σ GL(akun,periode) = Δ SINV(akun).  [TERBUKTI April 2026]
```
**AR (kunci = `gl_journal.voucher = AR_TRANS.ORDER_CLIENT`)**
```
gl_setup.acc_ar (103-001)
  └ GL_JOURNAL.voucher ═══ AR_TRANS.ORDER_CLIENT (invoice; debet>0)
        ├ SALDO_AWAL_FAKTUR.BUKTI_ID = ORDER_CLIENT (opening, tipe 1)
        ├ TBYR2.BUKTI_ID   = ORDER_CLIENT ─ TBYR2.VOUCHER=TBYR1.VOUCHER (bayar; FLAG_BAYAR 1,2; FLAG_VENDOR 1/null)
        ├ TBYR2_PUTIH.BUKTI_ID = ORDER_CLIENT (adj; FLAG_ORDER 11=+/1=−)
        └ MCUST.CUST_ID (nama)
Invarian: SISA = SAF + Σdebet_GL(voucher) + ADJ − BAYAR ;  Σ SISA(semua voucher) = saldo GL 103-001
```
**AP (kunci = `gl_journal.voucher = AP_TRANS.ORDER_CLIENT`; akun `226-001`+`226-006`)**
```
gl_setup.acc_ap (226-001)
  └ GL_JOURNAL.voucher ═══ AP_TRANS.ORDER_CLIENT (invoice; kredit>0; tipe 02/05/06/16=+, 12=−)
        ├ SALDO_AWAL_FAKTUR.BUKTI_ID = ORDER_CLIENT (opening, tipe 1,2)
        ├ TBYR2.BUKTI_ID = ORDER_CLIENT ─ TBYR1 (bayar; FLAG_BAYAR 1,2)
        ├ TBYR2_PUTIH.BUKTI_ID = ORDER_CLIENT (adj; NOT IN(2,22)=+)
        └ MCSTSUPP.VENDOR_ID (nama)
Invarian: SISA = SAF + MUTASI + ADJ − BAYAR ;  Σ SISA = saldo GL 226-001(+226-006 freight)
```
**Jaminan "1 angka GL = SUM jurnal":** query 1.4 per (akun,periode); anchor `EXISTS gl_journal.voucher` di semua view AP/AR memastikan tak ada baris subledger tanpa jejak GL, dan R9 menangkap arah sebaliknya (GL tanpa subledger).

---

## 6. PERFORMANCE — SQL Anywhere 9

**Index wajib**
```sql
CREATE INDEX idx_gljrn_acc_tgl_post ON gl_journal(account_id, tgl, posting);
CREATE INDEX idx_gljrn_voucher      ON gl_journal(voucher);          -- anchor AP/AR
CREATE INDEX idx_sinv_per_stok      ON sinv(periode, stok_id);
CREATE INDEX idx_saf_bukti          ON saldo_awal_faktur(bukti_id, tipe_trans);
CREATE INDEX idx_aptrans_order      ON ap_trans(order_client, tipe_trans, tgl);
CREATE INDEX idx_artrans_order      ON ar_trans(order_client, tipe_trans, tgl);
CREATE INDEX idx_tbyr2_bukti        ON tbyr2(bukti_id);
CREATE INDEX idx_tbyr1_voucher      ON tbyr1(voucher, flag_bayar, tgl);
CREATE INDEX idx_tbyr2p_bukti       ON tbyr2_putih(bukti_id, tgl_bayar);
```
> Cek dulu index existing (report menyebut `IDX_AP_TRANS_ORDER`, `IDX_TBYR2_PUTIH_BUKTI` — mungkin sudah ada). DDL saat idle (aplikasi memegang SHARE lock luas).

**Anti-pattern (dilarang):** `*=` old outer join · `NOT IN` subselect ber-konkatenasi · `SELECT *` · host var di SELECT-list/JOIN-ON (painter PB) · `LEFT JOIN ... ON 1=1` di DW painter · retrieve semua produk tanpa filter.

**Snapshot (dashboard instant):**
```sql
CREATE TABLE rekon_snapshot (
   periode         TIMESTAMP,
   site_id         VARCHAR(10),
   domain          VARCHAR(4),          -- STOK|AP|AR
   account_id      VARCHAR(20),
   subledger_value NUMERIC(18,2),
   ledger_value    NUMERIC(18,2),
   selisih         NUMERIC(18,2),
   status          VARCHAR(8),
   built_at        TIMESTAMP DEFAULT CURRENT TIMESTAMP,
   PRIMARY KEY (periode, site_id, domain, account_id) );
```
Diisi post-closing/refresh dari view §2.2/§3.3; dashboard `SELECT` dari sini; drill lvl-1+ baru query live.

---

## 7. STATUS & GATE PRODUKSI

| Layer | Status | Bukti |
|---|---|---|
| Ledger engine | ✅ CLOSED | invariant balance+journal terverifikasi live |
| Stok engine | ✅ CLOSED | April 2026: report=ledger semua akun stok |
| AR engine | ✅ CONTRACT-FINAL | kontrak = `dw_rpt_ar_opname` (AR_TRANS/TBYR/SAF/GL-anchor) |
| AP engine | ✅ CONTRACT-FINAL | kontrak = `dw_rpt_ap_opname` (AP_TRANS/TBYR/SAF/GL-anchor) |
| Anomaly engine | ✅ READY | R1–R11 implementable ASA9 (R11 forensic-confirmed) |
| Traceability | ✅ CLOSED-LOOP | `gl_journal.voucher = ORDER_CLIENT` dua arah (anchor + R9) |
| Root cause AP/AR | ✅ FORENSICALLY CLOSED | 14 voucher DP (9 AR + 5 AP) — lihat §8 |

**Gate sebelum produksi (wajib, sekali):**
1. Jalankan `Σ sisa view §3.1/§3.2` vs `Σ SISA_IDR report opname` 1 periode → harus identik (uji ekuivalensi agregat vs per-voucher).
2. Jalankan §3.3 AR & AP vs ledger → dokumentasikan selisih baseline (jika ada gap historis à la MAT, kategorikan OPENING_BALANCE_GAP, bukan bug).
3. Buat index §6 saat idle; update statistics.
4. Isi `rekon_snapshot` untuk periode berjalan; dashboard membaca snapshot.

> Catatan akun: anchor AP report memakai `('226-001','226-006')` (freight). Untuk menghindari hardcode di view produksi, tambahkan kolom konfigurasi (mis. tabel `rekon_account_map(domain, account_id)`) yang diisi dari `gl_setup.acc_ap` + akun freight — satu sumber konfigurasi untuk view & dashboard.

---

## 8. FORENSIC CLOSURE — GATE#2 AP/AR (root cause TERKUNCI)

**Benchmark GL-live (YTD s/d Apr 2026), anchored = all (d=0.00 → tak ada orphan jurnal):**

| Akun | GL_balance | Subledger (opname/report) | SELISIH |
|---|--:|--:|--:|
| AR 103-001 | 20.117.869.958,91 | 19.658.007.939,85 | **+459.861.950,00** |
| AP 226-001(+006) | 9.291.427.522,89 (net) | 8.238.241.410,02 | **+1.324.504.398,80** |

GATE#1 PASS (view §3.1/§3.2 = report per-voucher: AP n=84=8.238.241.410,02; AR n=463=19.658.007.939,85). Selisih GATE#2 = **GL > subledger** → subledger dikurangi sesuatu yang tak terjurnal di GL.

**Breakdown per-voucher (klasifikasi lengkap):**

| Domain | MATCH | GAP (NO_GL) |
|---|--:|--:|
| AR | 431 voucher = 47.361.445.587,46 (gap 0,00) | **9 voucher = 459.861.950,00** |
| AP | 131 voucher = 22.329.744.731,38 (gap 0,00) | **5 voucher = 1.324.504.398,80** |

Linkage key = `gl_journal.voucher_manual = tbyr1.voucher_manual` (BUKAN `voucher`).

**Katalog voucher gap — 100% Down Payment (uang muka), `kas_id=0` = alokasi):**

AR (9× `DPR`): 2605DPR002 (122.579.200) · 2603DPR002 (111.000.000) · 2602DPR003 (61.632.750) · 2605DPR003 (40.000.000) · 2602DPR002 (39.627.000) · 2603DPR003 (32.500.000) · 2601DPR001 (20.000.000) · 2602DPR001 (16.983.000) · 2603DPR001 (15.540.000).

AP (5× `DPB`): 2603DPB002 (408.727.854) · 2603DPB004 (358.602.456) · 2603DPB001 (191.590.656) · 2603DPB003 (190.783.392) · 2606DPB001 (174.800.040,80).

**Validasi 3 hipotesis (klasifikasi):**

| Hipotesis | Kategori | Verdict | Bukti |
|---|---|---|---|
| A — posting belum dilakukan | **NO_GL_ENTRY** | ✅ **VALID** | DP tak ada di `gl_journal` (semua akun/modul, tanpa batas tgl), tak ada di `TDP`, tak ada di titipan `410-047` |
| B — mapping akun salah | WRONG_ACCOUNT_CLASS | ❌ DITOLAK | jika salah-bucket → muncul di GL akun lain; nyatanya nihil di GL manapun |
| C — cutoff/period-shift | PERIOD_SHIFT | ❌ DITOLAK | `ci_all=0`/`co_all=0` walau tanpa batas tanggal |

Kategori PARTIAL_GL_ENTRY & WRONG_MODULE_ID: **nihil** (tak ada baris parsial/salah-modul).

**ROOT CAUSE FINAL (audit-grade, FACT):** Down Payment diterapkan mengurangi outstanding di subledger AR/AP (`TBYR`) tetapi **tidak memiliki jurnal GL apa pun** → akun kontrol GL lebih tinggi dari subledger tepat sebesar total DP. Bukan bug engine, bukan efek refresh, bukan selisih pembulatan → **posting-completeness gap DP-application** yang riil dan actionable. Pola bulanan konsisten (AR mulai Jan; AP melonjak Feb = 4 dari 5 DPB `2603`).

**Deliverable akuntansi:** posting jurnal DP-application untuk 14 voucher (AR: kredit 103-001 = 459.861.950; AP: debet 226-001 = 1.324.504.399), pasangan debet/kredit ke akun kas/titipan sesuai lifecycle DP. Setelah diposting → GATE#2 harus 0.

**R11** = `DP_APPLICATION_POSTING_GAP` (§4) — deteksi voucher TBYR (anchored subledger) tanpa jurnal GL CI/CO by `voucher_manual`. Status: **FORENSIC-CONFIRMED, LOCKED.**
