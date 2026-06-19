# CODING PHASE ARTEFACT REQUIREMENTS
## Mandatory Deliverables During Implementation

**Document Purpose:** Define artefacts that MUST be produced during coding phase  
**Date:** 2026-06-16  
**Status:** ✅ FINAL REQUIREMENTS

---

## OVERVIEW

During coding phase, the following THREE artefacts are MANDATORY and will be reviewed during code review and QA phases.

No code can be merged WITHOUT these artefacts.

---

## ARTEFACT 1: CHANGE IMPACT MATRIX

### Purpose
Document what changes, where, and the risk level

### Format

```
File: dw_rpt_jual_faktur1_rekap.srd

NEW Compute Fields:
  - cunit_idr          (Detail band)
  - cunit_valuta       (Detail band)
  - cjasa_idr          (Detail band)
  - cspare_idr         (Detail band)
  - ckotor_valuta      (Detail band - rename from ckotor)
  - ckotor_idr_total   (Detail band - rename from ckotor_idr)

MODIFIED Compute Fields:
  - compute_unit_idr      (Group header - was compute_47)
  - compute_unit_valuta   (Group header - new)
  - compute_jasa_idr      (Group header - new)
  - compute_spare_idr     (Group header - new)
  - compute_kotor_valuta  (Group header - rename)
  - compute_kotor_idr     (Group header - renamed from compute_47)

DELETED Compute Fields:
  - None (legacy fields preserved for backward compatibility)

MODIFIED Columns:
  - Group header layout changed (new column sequence)

IMPACT RISK: LOW
  - No SQL changes
  - No table changes
  - No data loss
  - Existing KOTOR values unchanged (only distribution)
  - Backward compatible (old formulas not deleted)

AFFECTED WINDOWS:
  - w_rpt_jual.srw (uses dw_rpt_jual_faktur1_rekap.srd)
  - Export Excel (column count increased: 4 → 7 columns)
  - Print preview (layout adjusted)

REGRESSION RISK: MINIMAL
  - Other reports do not reference this datawindow
  - w_rpt_jual.srw uses dynamic DW loading (handles new columns)
  - Excel export is column-agnostic (iterates all columns)
```

---

## ARTEFACT 2: BEFORE vs AFTER FORMULA MATRIX

### Purpose
Show exact formula changes for code review

### Format

```
UNIT CATEGORY:
─────────────────────────────────────────────────────────────

OLD (Not explicitly defined - all transactions):
  (No formula - all amounts went to Unit column)

NEW (Explicit filtering):
  cunit_idr = if(penjualan='03', kotor_asli * penjualan_kurs, 0)
  compute_unit_idr = sum(cunit_idr for group 1)

SOURCE OF TRUTH: penjualan='03'
REASON: Profiling confirmed 03 always pairs with UNIT group_product
RISK: LOW (explicit, single source)

─────────────────────────────────────────────────────────────

JASA CATEGORY:
─────────────────────────────────────────────────────────────

OLD (Not explicitly defined - not shown in report):
  (No formula - category didn't exist)

NEW (Explicit filtering):
  cjasa_idr = if(group_product='JS', kotor_asli * penjualan_kurs, 0)
  compute_jasa_idr = sum(cjasa_idr for group 1)

SOURCE OF TRUTH: group_product='JS'
REASON: Profiling confirmed 01/02/03 maps to different group_product values
        Must use group_product for correct categorization
RISK: LOW (explicit, single source, validated by profiling)

─────────────────────────────────────────────────────────────

SPARE PARTS CATEGORY:
─────────────────────────────────────────────────────────────

OLD (Not explicitly defined - not shown in report):
  (No formula - category didn't exist)

NEW (Explicit filtering):
  cspare_idr = if(group_product='SP', kotor_asli * penjualan_kurs, 0)
  compute_spare_idr = sum(cspare_idr for group 1)

SOURCE OF TRUTH: group_product='SP'
REASON: Profiling confirmed SP is only non-JS spare parts category
RISK: LOW (explicit, single source, validated by profiling)

─────────────────────────────────────────────────────────────

KOTOR (Total) - UNCHANGED:
─────────────────────────────────────────────────────────────

OLD:
  compute_kotor_idr = sum(ckotor_idr for group 1)
  Where: ckotor_idr = kotor_asli * penjualan_kurs

NEW:
  compute_kotor_idr = sum(ckotor_idr_total for group 1)
  Where: ckotor_idr_total = kotor_asli * penjualan_kurs

CHANGE: Rename for clarity (was ckotor_idr, now ckotor_idr_total)
LOGIC: UNCHANGED - still sums ALL transactions
RESULT: Same total KOTOR (validated by Gate 6: Reconciliation)

─────────────────────────────────────────────────────────────

VALIDATION:

Unit + Jasa + Spare = Kotor?
  ✓ YES (proven by Gate 4: Balance Validation)

Is KOTOR value same before/after?
  ✓ YES (proven by Gate 6: Reconciliation)

Are formulas explicit (no catch-all)?
  ✓ YES (all use explicit conditions)

Are sources of truth documented?
  ✓ YES (see comments above)
```

---

## ARTEFACT 3: TEST EVIDENCE MATRIX

### Purpose
Prove that all test cases pass before merge

### Format

```
TEST CASE EXECUTION RESULTS
═════════════════════════════════════════════════════════════

Test Case: TC-001 - Unit Category Only
─────────────────────────────────────────────────────────────
Scenario:  Invoice with ONLY kode 03 (Unit)
          Amount: Rp 100.000.000

Expected Results:
  Unit_IDR:      100.000.000 ✓
  Jasa_IDR:      0           ✓
  Spare_IDR:     0           ✓
  Kotor_IDR:     100.000.000 ✓
  Balance Check: 100+0+0=100 ✓

Actual Results:  [INSERT ACTUAL FROM TEST]
Status: ✅ PASS / ❌ FAIL

Remarks:
  [If FAIL, explain why]

─────────────────────────────────────────────────────────────

Test Case: TC-002 - Jasa Category Only
─────────────────────────────────────────────────────────────
Scenario:  Invoice with ONLY kode 01/group_product JS (Jasa)
          Amount: Rp 30.000.000

Expected Results:
  Unit_IDR:      0           ✓
  Jasa_IDR:      30.000.000  ✓
  Spare_IDR:     0           ✓
  Kotor_IDR:     30.000.000  ✓
  Balance Check: 0+30+0=30   ✓

Actual Results:  [INSERT ACTUAL FROM TEST]
Status: ✅ PASS / ❌ FAIL

─────────────────────────────────────────────────────────────

Test Case: TC-003 - Spare Parts Category Only
─────────────────────────────────────────────────────────────
Scenario:  Invoice with ONLY kode 02/group_product SP (Spare)
          Amount: Rp 50.000.000

Expected Results:
  Unit_IDR:      0           ✓
  Jasa_IDR:      0           ✓
  Spare_IDR:     50.000.000  ✓
  Kotor_IDR:     50.000.000  ✓
  Balance Check: 0+0+50=50   ✓

Actual Results:  [INSERT ACTUAL FROM TEST]
Status: ✅ PASS / ❌ FAIL

─────────────────────────────────────────────────────────────

Test Case: TC-004 - Mixed Invoice (All Categories)
─────────────────────────────────────────────────────────────
Scenario:  Invoice with kode 03, 01/JS, 01/SP, 02/SP
          Kode 03:      100.000.000 (UNIT)
          Kode 01/JS:   30.000.000 (JASA)
          Kode 01/SP:   70.000.000 (SPARE from 01)
          Kode 02/SP:   50.000.000 (SPARE from 02)
          ─────────────────────
          Total:        250.000.000

Expected Results:
  Unit_IDR:      100.000.000 ✓
  Jasa_IDR:      30.000.000  ✓
  Spare_IDR:     120.000.000 ✓ (70+50 from dual categories)
  Kotor_IDR:     250.000.000 ✓
  Balance Check: 100+30+120=250 ✓

Actual Results:  [INSERT ACTUAL FROM TEST]
Status: ✅ PASS / ❌ FAIL

Remarks:
  Note: Spare_IDR (120) > Kotor component (70+50)
        because kode 01 counted in BOTH Jasa AND Spare (expected)

─────────────────────────────────────────────────────────────

Test Case: TC-005 - Multi-Currency Invoice
─────────────────────────────────────────────────────────────
Scenario:  Invoice with USD and IDR in same document
          USD 10.000 @ 16.000/USD:  160.000.000 (UNIT)
          IDR 30.000.000:            30.000.000 (JASA)
          IDR 10.000.000:            10.000.000 (SPARE)
          ─────────────────────────
          Total:                    200.000.000

Expected Results:
  Unit_IDR:      160.000.000 ✓
  Jasa_IDR:      30.000.000  ✓
  Spare_IDR:     10.000.000  ✓
  Kotor_IDR:     200.000.000 ✓
  Balance Check: 160+30+10=200 ✓
  Kurs Applied:  Per-item conversion (not global) ✓

Actual Results:  [INSERT ACTUAL FROM TEST]
Status: ✅ PASS / ❌ FAIL

Remarks:
  Currency conversion validated per-item
  (not SUM(kotor) * kurs - would be wrong)

─────────────────────────────────────────────────────────────

SUMMARY: TEST EXECUTION
═════════════════════════════════════════════════════════════

Total Test Cases:        5
Passed:                  5
Failed:                  0
Success Rate:            100%

APPROVAL:
  QA Lead Sign-off:    ✅ [Signature/Date]
  Technical Lead:      ✅ [Signature/Date]

  Ready for UAT:       ✅ YES

  Note: If ANY test fails, STOP and debug before merge
```

---

## ARTEFACT SUBMISSION CHECKLIST

**Coder MUST provide when submitting for code review:**

```
□ Change Impact Matrix (file/field level analysis)
□ Before vs After Formula Matrix (exact formula changes)
□ Test Evidence Matrix (test cases + results)

□ Code compiles without errors
□ All 8 gates still pass (re-run diagnostic)
□ Single Source of Truth Rule followed (one source per category)
□ No catch-all logic in any formula
□ Source of truth documented in code comments
□ Git commit message references gate results
□ Git commit message references test evidence

IF ANY above missing:
  → Code Review HOLD
  → Request developer to provide missing artefacts
```

---

## CODE REVIEW APPROVAL CRITERIA

**Reviewer will check:**

```
□ Change Impact Matrix accuracy
  - Lists all new/modified/deleted fields
  - Risk assessment is realistic
  - Affected windows identified

□ Before vs After Formula Matrix logic
  - Each formula has SINGLE source of truth
  - Source documented in code
  - KOTOR unchanged (reconciliation proven)

□ Test Evidence Matrix results
  - All 5 test cases PASS
  - Balance equations validated
  - Currency conversion correct
  - No regressions visible

□ Source of Truth Rule compliance
  - Each category uses one source (not mixing)
  - Comments show which source chosen
  - No fallback/exception logic

IF ALL above verified:
  → ✅ APPROVE for merge

ELSE:
  → ❌ REQUEST CHANGES
  → Comment on which artefact needs fix
```

---

## GATE 8 (QA) VERIFICATION

**QA will validate artefacts against actual code:**

```
□ Does actual code match Before vs After Matrix?
□ Do actual test results match Test Evidence Matrix?
□ Can QA reproduce all test cases?
□ Are formulas actually using single source of truth?
□ Is KOTOR value confirmed unchanged (Gate 6 revalidation)?
□ Is balance proven (Gate 4 revalidation)?

IF all verified:
  → ✅ PASS Gate 8

ELSE:
  → ❌ FAIL - back to developer
```

---

## MERGE REQUIREMENTS

**Before code can be merged to release:**

```
✅ Code Review: APPROVED
   - All 3 artefacts provided
   - Single Source of Truth verified
   - No catch-all logic
   
✅ QA Testing: PASSED
   - All test cases executed
   - Results match Test Evidence Matrix
   - Gates 1-8 revalidated
   - No regressions found
   
✅ Finance UAT: SIGNED OFF
   - Numbers match expectations
   - Reports show correct breakdown
   - No double-counting
   
→ MERGE APPROVED
```

---

**Artefact Requirements Status:** ✅ FINAL & BINDING  
**Submission Required:** Before code review  
**Review Criteria:** All 3 artefacts + source-of-truth verification  
**Merge Gate:** All artefacts verified + tests passed + UAT signed off

