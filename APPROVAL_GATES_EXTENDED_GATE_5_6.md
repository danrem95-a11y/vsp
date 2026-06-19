# APPROVAL GATES EXTENDED
## Gate 5 & Gate 6 - Multi-Currency & Reconciliation

**Document Purpose:** Define Gate 5 & Gate 6 yang sering overlooked pada report multi-currency  
**Date:** 2026-06-16  
**Status:** ✅ FINAL

---

## GATE 5: CURRENCY INTEGRITY VALIDATION

### Purpose
Validasi bahwa konversi kurs dilakukan dengan BENAR:
- Per line item: `kotor_asli * penjualan_kurs` (BENAR)
- BUKAN per total: `SUM(kotor) * kurs` (SALAH - bug klasik)

### File Input
`diag_currency_integrity.txt`

### Expected Pattern (AMAN)

**Single Currency Invoice (IDR only):**
```
bukti_id     | currencies | total_idr_correct | total_idr_wrong | currency_integrity
INV-001      | IDR        | 180.000.000       | 180.000.000     | OK - Line item
```
→ Sama karena hanya satu kurs

**Multi-Currency Invoice:**
```
bukti_id     | currencies | total_idr_correct | total_idr_wrong | currency_integrity
INV-002      | USD,IDR    | 165.000.000       | 160.000.000     | OK - Line item
             | (USD mix)  |                   |                 |
```
→ BERBEDA = Berarti formula dengan-per item (BENAR)

**Jika kebalikan (SALAH):**
```
bukti_id     | currencies | total_idr_correct | total_idr_wrong | currency_integrity
INV-003      | USD,IDR    | 165.000.000       | 165.000.000     | MISMATCH - Check
             |            |                   |                 | (means formula is broken)
```
→ SAMA = Formula menggunakan SUM() * kurs (SALAH)

### Red Flag Pattern (STOP)

```
currency_integrity = 'MISMATCH - Check kurs handling'
```

Artinya:
- Formula konversi kurs tidak per item
- Atau ada bug di handling multi-currency
- Harus investigate lebih lanjut

### Approval Criteria

```
✅ PASS: Semua invoices menunjukkan "OK - Line item conversion"
        (Atau untuk IDR-only, total_idr_correct = total_idr_wrong)

⚠️  WARNING: Ada beberapa MISMATCH tapi kecil (< 2)
          → Mungkin rounding error
          → Investigate tapi mungkin bisa tolerate

❌ FAIL: Ada MISMATCH signifikan
       → Berarti formula salah
       → Harus fix SEBELUM coding
```

### Root Cause Investigation (Jika MISMATCH)

**Scenario: Invoice punya USD + IDR**

```
Line 1: USD 100 @ 16000 = 1.600.000 IDR
Line 2: IDR 500.000
Total = 2.100.000 IDR

BENAR (per item):
  1.600.000 + 500.000 = 2.100.000

SALAH (per total):
  (100 + 500.000) * 16000 = ERROR
```

**Query untuk investigate:**
```sql
SELECT
    bukti_id,
    curr_id,
    SUM(kotor) as total_per_curr,
    AVG(kurs) as avg_kurs,
    SUM(kotor * kurs) as per_item_idr,
    SUM(kotor) * MAX(kurs) as per_total_idr
FROM ...
GROUP BY bukti_id, curr_id
```

---

## GATE 6: RECONCILIATION - EXISTING VS NEW REPORT

### Purpose
Memastikan bahwa perubahan formula HANYA merubah distribusi kategori, BUKAN total revenue.

```
EXISTING REPORT: KOTOR = X
NEW REPORT: UNIT + JASA + SPARE = X (same total, different breakdown)

Target: X_existing = X_new
```

### File Input
`diag_reconciliation_existing.txt`

### Expected Pattern (AMAN)

**Existing Report Total = New Report Total**

```
source                          | kotor_total | jumlah_line | jumlah_invoice
Existing Report                 | 1.000.000   | 245         | 65
New Report (formula based)      | 1.000.000   | 245         | 65
```

→ SAMA = Formula benar, hanya beda distribusi kategori ✅

### Red Flag Pattern (STOP)

**New Report Total ≠ Existing Report Total**

```
source                          | kotor_total | jumlah_line
Existing Report                 | 1.000.000   | 245
New Report (formula based)      | 950.000     | 245  ← BERBEDA!
```

→ Ada revenue yang hilang atau terkalkulasi dua kali ❌

### Variance Interpretation

```
Variance = ABS(Existing - New)

Variance = 0       → ✅ Perfect match
Variance < 1       → ✅ OK (rounding error, 0.1%)
Variance < 0.1%    → ✅ OK (acceptable difference)
Variance > 0.1%    → ❌ FAIL - investigate
Variance >> 10%    → 🔴 CRITICAL - major bug
```

### Approval Criteria

```
✅ PASS: Kotor_existing = Kotor_new (variance < 0.01%)
        Distribution ke Unit/Jasa/Spare adalah perubahan
        Total revenue tetap sama

❌ FAIL: Kotor_existing ≠ Kotor_new
       → Revenue missing atau double-counted
       → Harus fix formula SEBELUM coding
       → DO NOT DEPLOY
```

### Root Cause Investigation (Jika FAIL)

**Jika variance besar:**

```sql
SELECT
    penjualan,
    group_product,
    COUNT(*) as jumlah,
    SUM(kotor) as total_existing,
    SUM(
        CASE 
            WHEN penjualan='03' THEN kotor
            WHEN group_product='JS' THEN kotor
            WHEN group_product='SP' THEN kotor
            ELSE 0
        END
    ) as total_new
FROM ...
GROUP BY penjualan, group_product
```

Cari kategori mana yang berbeda total-nya.

**Common Root Causes:**
- Kategori missing dari formula (tidak ter-capture)
- Double counting salah (counted lebih dari seharusnya)
- Filter yang tidak matched (penjualan code tidak ada di mapping)

---

## GATE 5 & 6 IN CONTEXT

### When to Check

| Gate | When | Why |
|------|------|-----|
| Gate 1-4 | Before testing | Validate data mapping & balance |
| **Gate 5** | **Before coding** | **Critical for multi-currency accuracy** |
| **Gate 6** | **Before deploy** | **Final sanity check: no revenue loss** |

### Typical Issues Found

**Gate 5 (Currency):**
- Kurs bervariasi dalam satu invoice (multi-currency)
- Formula menggunakan AVG(kurs) bukan per-item kurs
- Rounding error accumulation pada banyak lines

**Gate 6 (Reconciliation):**
- Kategori missing → Revenue gap
- Category overlap → Revenue double-counted wrong
- Exchange rate not applied correctly → Variance

---

## FINAL APPROVAL MATRIX (6 GATES)

```
APPROVAL RULE FOR CODING:

IF Gate1=PASS
   AND Gate2=PASS
   AND Gate3=PASS
   AND Gate4=PASS
   AND Gate5=PASS
   AND Gate6=PASS
THEN
    APPROVED FOR CODING
ELSE
    HOLD (investigate root cause)

EXECUTION:
┌─────────────────────────────────────┐
│ Run Diagnostic Script               │
│ (generates input files)             │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ GATE 1: Penjualan ↔ Group Product   │
│ File: diag_penjualan_kombinasi.txt │
│ Status: ⏳                          │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ GATE 2: Group Product Inventory     │
│ File: diag_group_product_agregasi.txt
│ Status: ⏳                          │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ GATE 3: Orphan Category Audit       │
│ File: diag_orphan_category.txt      │
│ Status: ⏳                          │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ GATE 4: Balance Validation          │
│ File: diag_balance_not_ok.txt       │
│ Status: ⏳                          │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ GATE 5: Currency Integrity          │
│ File: diag_currency_integrity.txt   │
│ Status: ⏳                          │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ GATE 6: Existing vs New Reconcile   │
│ File: diag_reconciliation_existing.txt
│ Status: ⏳                          │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│ ALL GATES PASS?                     │
├─────────────────────────────────────┤
│ YES → ✅ APPROVED FOR CODING        │
│ NO  → ❌ HOLD & INVESTIGATE         │
└─────────────────────────────────────┘
```

---

## GATE 5 & 6 SIGN-OFF TEMPLATE

```
═══════════════════════════════════════════════════════
    GATE 5 & 6 VALIDATION - SIGN-OFF
═══════════════════════════════════════════════════════

GATE 5: CURRENCY INTEGRITY VALIDATION
─────────────────────────────────────────────────────

File: diag_currency_integrity.txt
Date: [DATE]

Multi-currency invoices checked: [COUNT]
Single-currency invoices checked: [COUNT]

Result: ✅ PASS / ⚠️ WARNING / ❌ FAIL

If WARNING/FAIL:
  Issue: [DESCRIBE]
  Root cause: [INVESTIGATE]
  Decision: ✅ Acceptable / ❌ Must fix

───────────────────────────────────────────────────────

GATE 6: RECONCILIATION - EXISTING VS NEW
─────────────────────────────────────────────────────

File: diag_reconciliation_existing.txt
Date: [DATE]

Existing Report Total: [AMOUNT]
New Report Total: [AMOUNT]
Variance: [AMOUNT] ([%])

Result: ✅ PASS / ❌ FAIL

If FAIL:
  Root cause: [INVESTIGATE]
  Missing category: [IF ANY]
  Double count issue: [IF ANY]
  Must fix before deploy: YES/NO

───────────────────────────────────────────────────────

OVERALL GATE 5 & 6 DECISION:
  ✅ Both PASS → Proceed to coding approval
  ❌ Either FAIL → Hold, investigate, fix formula
  
Approved by: _________________ Date: _________
═══════════════════════════════════════════════════════
```

---

## WHY THESE GATES ARE CRITICAL

### Gate 5 (Currency) Risk

**Without validation:**
- Multi-currency invoices calculate wrong
- User complaints: "Why USD 10.000 showing as IDR 160.000 in report?"
- Revenue mismatch in GL reconciliation
- Worse: Silent error (looks correct but calculated wrong)

**With validation:**
- Early detection of exchange rate formula bugs
- Confidence that multi-currency handled correctly
- Can trace issue to line-item vs total calculation

### Gate 6 (Reconciliation) Risk

**Without validation:**
- Deploy new formula
- 2 weeks later: "Laporan menunjukkan revenue berkurang 5%!"
- Root cause unclear (banyak perubahan)
- Rollback diperlukan (downtime)

**With validation:**
- Know BEFORE deploy: KOTOR tetap sama
- Confidence bahwa perubahan hanya distribusi kategori
- Quick root cause if something else goes wrong

---

## BEST PRACTICE SUMMARY

✅ **Gate 5 & 6 harus lolos SEBELUM coding** karena:
1. Bug multi-currency = silent failure
2. Revenue reconciliation = critical business metric
3. Easy to validate (2 queries saja)
4. Better to find now daripada di production

❌ **Jangan skip gates ini** karena:
- "Saya sudah test formula manual" ≠ automated validation
- Multi-currency edge cases mudah terlewat
- Reconciliation mismatch hanya keliatan di aggregate data

---

**Gate 5 & 6 Addition Approval:** ✅ FINAL  
**Status:** Ready for implementation in diagnostic script  
**Update:** Add to full approval framework documentation

