# GATE 7 & GATE 8 + GOVERNANCE RULES
## Production-Grade Implementation Governance

**Document Purpose:** Add historical validation, data quality audit, and governance rules for production deployment  
**Date:** 2026-06-16  
**Status:** ✅ FINAL

---

## GATE 7: HISTORICAL REGRESSION TEST

### Purpose
Validasi formula tidak hanya untuk periode berjalan, tapi juga historis (3/6/12 bulan) untuk mendeteksi kategori lama yang jarang dipakai.

**Risk It Mitigates:**
```
Skenario:
  Periode Jan 2026: Data clean (hanya JS, SP, UNIT)
  Periode Jul 2025: Ada ACC (jarang, tapi ada)
  Periode Apr 2025: Ada OTH (abandoned category)

Jika hanya cek Jan 2026 → Tidak terdeteksi
Jika cek 12 bulan → Semua kategori terdeteksi
```

### Query Template

```sql
-- Period 1: Current Month
SELECT 'Current Month' as period, SUM(kotor) as revenue_existing
FROM tsales1 t1 JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
WHERE MONTH(t1.tgl) = MONTH(GETDATE())
  AND YEAR(t1.tgl) = YEAR(GETDATE())
UNION ALL
-- Period 2: Last 3 Months
SELECT 'Last 3 Months', SUM(kotor)
FROM tsales1 t1 JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
WHERE t1.tgl >= DATEADD(MONTH, -3, GETDATE())
UNION ALL
-- Period 3: Last 6 Months
SELECT 'Last 6 Months', SUM(kotor)
FROM tsales1 t1 JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
WHERE t1.tgl >= DATEADD(MONTH, -6, GETDATE())
UNION ALL
-- Period 4: Last 12 Months
SELECT 'Last 12 Months', SUM(kotor)
FROM tsales1 t1 JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
WHERE t1.tgl >= DATEADD(MONTH, -12, GETDATE())
```

### File Output
`diag_historical_regression_test.txt`

### Expected Pattern (PASS)

```
Period              | Revenue Existing | Revenue New | Variance
Current Month       | 1.000.000        | 1.000.000   | 0%
Last 3 Months       | 3.050.000        | 3.050.000   | 0%
Last 6 Months       | 6.120.000        | 6.120.000   | 0%
Last 12 Months      | 12.340.000       | 12.340.000  | 0%
```

→ ✅ PASS: Semua periode balance

### Red Flag Pattern (FAIL)

```
Period              | Revenue Existing | Revenue New | Variance
Current Month       | 1.000.000        | 1.000.000   | 0%    ✅
Last 3 Months       | 3.050.000        | 3.050.000   | 0%    ✅
Last 6 Months       | 6.120.000        | 6.100.000   | -0.3% ⚠️ MISMATCH!
Last 12 Months      | 12.340.000       | 12.200.000  | -1.1% ❌ MISMATCH!
```

→ ❌ FAIL: Ada periode tidak balance
   - Jul 2025 data mungkin punya kategori yang tidak expected
   - Formula tidak valid untuk historical data

### Approval Criteria

```
✅ PASS: Semua periode (current + 3m + 6m + 12m) balance
        (variance < 0.01%)

❌ FAIL: Ada periode variance > 0.1%
        → Investigate: kategori apa yang missing?
        → Update formula jika diperlukan
        → Re-validate semua periode
```

### Root Cause Investigation

Jika variance di periode lama:

```sql
-- Find transactions in Jul 2025 that don't match current categorization
SELECT
    DATE_TRUNC('MONTH', t1.tgl) as bulan,
    im_product_group.penjualan,
    im_produk.group_product,
    COUNT(*) as jml,
    SUM(t2.kotor) as total
FROM tsales1 t1
JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
JOIN im_produk ON t2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE t1.tgl >= '2025-01-01'
GROUP BY DATE_TRUNC('MONTH', t1.tgl), 
         im_product_group.penjualan,
         im_produk.group_product
ORDER BY bulan, penjualan, group_product
```

---

## GATE 8: NULL & DATA QUALITY AUDIT

### Purpose
Mendeteksi NULL values atau data missing yang bisa cause seluruh transaksi hilang dari kategorisasi.

### Query Template

```sql
SELECT
    COUNT(*) as total_rows,
    COUNT(*) - COUNT(group_product) as null_group_product,
    COUNT(*) - COUNT(penjualan) as null_penjualan,
    COUNT(*) - COUNT(tsales2.kotor) as null_kotor,
    COUNT(DISTINCT CASE WHEN group_product IS NULL THEN bukti_id END) as invoices_with_null_group,
    COUNT(DISTINCT CASE WHEN penjualan IS NULL THEN bukti_id END) as invoices_with_null_penjualan,
    SUM(CASE WHEN group_product IS NULL THEN tsales2.kotor ELSE 0 END) as amount_missing_group,
    SUM(CASE WHEN penjualan IS NULL THEN tsales2.kotor ELSE 0 END) as amount_missing_penjualan
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
LEFT JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tipe_trans <> '33'
```

### File Output
`diag_null_data_quality.txt`

### Expected Pattern (PASS)

```
total_rows                  | 5000
null_group_product          | 0
null_penjualan              | 0
null_kotor                  | 0
invoices_with_null_group    | 0
invoices_with_null_penjualan| 0
amount_missing_group        | 0
amount_missing_penjualan    | 0
```

→ ✅ PASS: Tidak ada NULL, semua data valid

### Red Flag Pattern (FAIL)

```
total_rows                  | 5000
null_group_product          | 47   ← NULL FOUND!
null_penjualan              | 0
invoices_with_null_group    | 8
amount_missing_group        | 250000  ← Rp 250k hilang!
```

→ ❌ FAIL: Ada 47 rows dengan group_product NULL
   - Data quality issue
   - 8 invoices affected
   - Rp 250k potentially missing

### Approval Criteria

```
✅ PASS: 
  - null_group_product = 0
  - null_penjualan = 0
  - amount_missing_group = 0
  - amount_missing_penjualan = 0

❌ FAIL: Ada NULL values
  → Investigate: Kenapa ada NULL?
  → Fix data quality BEFORE coding
  → Re-validate gate 8
```

### Root Cause Investigation

Jika ada NULL:

```sql
-- Find transactions with NULL group_product
SELECT TOP 50
    t1.bukti_id,
    t1.tgl,
    t2.stok_id,
    im_produk.nama_produk,
    im_produk.group_product,
    t2.kotor
FROM tsales1 t1
JOIN tsales2 t2 ON t1.bukti_id = t2.bukti_id
JOIN im_produk ON t2.stok_id = im_produk.produk_id
WHERE im_produk.group_product IS NULL
OR im_produk.group_product = ''
ORDER BY t1.tgl DESC

-- Action: Either
-- 1. Add missing product master data
-- 2. Update product master group_product
-- 3. Fix inventory master setup
```

---

## GOVERNANCE RULES FOR IMPLEMENTATION

### Rule 1: NO CATCH-ALL LOGIC ⛔ CRITICAL

**PROHIBITED:**
```powerbuilder
// ❌ WRONG - Catch-all (dangerous)
cspare_idr = if(group_product<>'JS', kotor*kurs, 0)

// ❌ WRONG - Implicit else
cspare_idr = if(group_product='JS', 0, kotor*kurs)

// ❌ WRONG - Else clause
IF unit_flag = 'N' THEN spare_part ELSE ...
```

**REQUIRED:**
```powerbuilder
// ✅ CORRECT - Explicit (safe)
cunit_idr = if(group_product='UNIT', kotor*kurs, 0)
cjasa_idr = if(group_product='JS', kotor*kurs, 0)
cspare_idr = if(group_product='SP', kotor*kurs, 0)

// ✅ CORRECT - Explicit list
cspare_idr = if(group_product IN ('SP', 'ACC'), kotor*kurs, 0)
```

**Why This Rule:**
```
Jika tahun depan muncul kategori baru:
  ACC (Accessories)
  FRT (Freight)
  BNS (Bonus)
  OTH (Other)

Dengan catch-all:
  → Silent masuk ke Spare Part (WRONG!)
  → Tidak ada warning
  → Discovered 6 bulan kemudian (ouch!)

Dengan explicit:
  → Kategori baru tidak ter-capture
  → Report looks incomplete (visible error)
  → Quick investigation & fix
```

### Rule 2: VALIDATION BEFORE COMMIT ✅ REQUIRED

**In commit message, include:**
```
- All 6+ gates PASS
- Historical regression tested (3/6/12 months)
- Null audit completed
- No catch-all logic used
- Acceptance criteria met
```

### Rule 3: ACCEPTANCE CRITERIA (8 AC)

**MUST PASS all before production:**

```
AC-01: All Gate 1-6 PASS
       Status: ✅ PASS / ❌ FAIL
       Evidence: [gate result file]

AC-02: Orphan Category = 0 rows
       Status: ✅ 0 rows / ❌ [X] rows
       Evidence: diag_orphan_category.txt

AC-03: Balance Error = 0 invoices
       Status: ✅ 0 rows / ❌ [X] rows
       Evidence: diag_balance_not_ok.txt

AC-04: Currency Conversion Error = 0
       Status: ✅ All "OK" / ❌ [X] "MISMATCH"
       Evidence: diag_currency_integrity.txt

AC-05: Revenue Difference (Existing vs New) = 0%
       Status: ✅ 0% variance / ❌ [X]% variance
       Evidence: diag_reconciliation_existing.txt

AC-06: Historical Regression (3/6/12m) = PASS
       Status: ✅ All periods balance / ❌ [X] period fail
       Evidence: diag_historical_regression_test.txt

AC-07: Data Quality (Null audit) = PASS
       Status: ✅ No NULL / ❌ [X] NULL found
       Evidence: diag_null_data_quality.txt

AC-08: Finance UAT Sign-off = OBTAINED
       Status: ✅ Signed / ❌ Pending
       Evidence: [UAT sign-off document]
```

**Deployment Rule:**
```
IF ALL AC PASS THEN
    OK to deploy to production
ELSE
    DO NOT DEPLOY
    
Mark as HOLD and investigate failing AC
```

### Rule 4: EXCEL EXPORT VALIDATION

**Before merge:**
```
□ Open existing report in Excel
  - Note column positions
  - Note sorting
  - Note any VBA macros

□ Export new report to Excel
  - All columns present?
  - Same column order?
  - Same data types?
  - Any formula issues?
  - Macros still work?

□ Side-by-side comparison
  - Sample 10 rows
  - Spot-check values
  - Check totals
```

---

## IMPLEMENTATION SIGN-OFF DOCUMENT

```
═══════════════════════════════════════════════════════
    IMPLEMENTATION & PRODUCTION APPROVAL CHECKLIST
═══════════════════════════════════════════════════════

Project: Rekap Penjualan By Customer
Implementation Date: [DATE]
Implemented By: [NAME]
Reviewed By: [NAMES]

───────────────────────────────────────────────────────
GATE VALIDATION CHECKLIST
───────────────────────────────────────────────────────

Gate 1 - Mapping:           ✅ PASS / ❌ FAIL
Gate 2 - Inventory:         ✅ PASS / ❌ FAIL
Gate 3 - Orphan Audit:      ✅ PASS / ❌ FAIL
Gate 4 - Balance:           ✅ PASS / ❌ FAIL
Gate 5 - Currency:          ✅ PASS / ❌ FAIL
Gate 6 - Reconciliation:    ✅ PASS / ❌ FAIL
Gate 7 - Historical:        ✅ PASS / ❌ FAIL
Gate 8 - Data Quality:      ✅ PASS / ❌ FAIL

───────────────────────────────────────────────────────
ACCEPTANCE CRITERIA VALIDATION
───────────────────────────────────────────────────────

AC-01: All Gates 1-6 PASS                  ✅ / ❌
AC-02: Orphan Category = 0                 ✅ / ❌
AC-03: Balance Error = 0                   ✅ / ❌
AC-04: Currency Error = 0                  ✅ / ❌
AC-05: Revenue Diff (Existing vs New) = 0% ✅ / ❌
AC-06: Historical Regression = PASS        ✅ / ❌
AC-07: Data Quality (Null) = PASS          ✅ / ❌
AC-08: Finance UAT Sign-off                ✅ / ❌

───────────────────────────────────────────────────────
GOVERNANCE COMPLIANCE
───────────────────────────────────────────────────────

□ No catch-all logic used
  Formula review: ✅ PASS / ❌ FAIL
  
□ Explicit filtering only
  Code review: ✅ PASS / ❌ FAIL
  
□ Excel export tested
  Export validation: ✅ PASS / ❌ FAIL

───────────────────────────────────────────────────────
FINAL DECISION
───────────────────────────────────────────────────────

All AC Passed?
  ✅ YES → Ready for Production Deployment
  ❌ NO  → HOLD - Fix failing AC

Status: [✅ APPROVED FOR PRODUCTION / ❌ HOLD]

───────────────────────────────────────────────────────
SIGN-OFFS
───────────────────────────────────────────────────────

Development Lead: _____________ Date: _________
Technical Lead: ______________ Date: _________
QA Lead: ____________________ Date: _________
Finance Manager: _____________ Date: _________
Project Manager: _____________ Date: _________

═══════════════════════════════════════════════════════
```

---

## FINAL APPROVAL GATES: 8 GATES

| Gate | Name | Input File | Pass Criteria |
|------|------|-----------|---------------|
| 1 | Penjualan Mapping | diag_penjualan_kombinasi.txt | 4 standard combos |
| 2 | Group Product Inventory | diag_group_product_agregasi.txt | JS, SP, UNIT only |
| 3 | Orphan Category Audit | diag_orphan_category.txt | 0 rows |
| 4 | Balance Validation | diag_balance_not_ok.txt | 0 rows |
| 5 | Currency Integrity | diag_currency_integrity.txt | All "OK per-item" |
| 6 | Reconciliation | diag_reconciliation_existing.txt | 0% variance |
| **7** | **Historical Regression** | **diag_historical_regression_test.txt** | **All periods balance** |
| **8** | **Data Quality (Null)** | **diag_null_data_quality.txt** | **0 NULL rows** |

---

## BINARY APPROVAL LOGIC (8-GATE)

```
IF Gate1=PASS
   AND Gate2=PASS
   AND Gate3=PASS
   AND Gate4=PASS
   AND Gate5=PASS
   AND Gate6=PASS
   AND Gate7=PASS        ← NEW (Historical)
   AND Gate8=PASS        ← NEW (Data Quality)
   AND AC-01 through AC-08 PASS
   AND Governance Rules COMPLIED
THEN
    ✅ PRODUCTION DEPLOYMENT APPROVED
ELSE
    ❌ DO NOT DEPLOY (HOLD & FIX)
```

---

**Gate 7 & 8 Purpose:** Comprehensive production-readiness validation  
**Governance Rules:** Prevent future silent failures and edge cases  
**Acceptance Criteria:** Binary pass/fail for production deployment

**Status:** ✅ FINAL & PRODUCTION-READY

