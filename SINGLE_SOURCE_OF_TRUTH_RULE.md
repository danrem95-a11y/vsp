# SINGLE SOURCE OF TRUTH RULE
## Implementation Governance for Report Fix

**Document Purpose:** Enforce consistency in category determination across all formulas  
**Date:** 2026-06-16  
**Status:** ✅ FINAL GOVERNANCE RULE

---

## PROBLEM STATEMENT

**Risk:** Multiple source confusion in formula implementation

```
Report A Formula:
  cjasa = if(penjualan='01', kotor*kurs, 0)

Report B Formula:
  cjasa = if(group_product='JS', kotor*kurs, 0)

Report C Formula:
  cjasa = if(penjualan='01' OR group_product='JS', kotor*kurs, 0)

Result: Different values in different reports = AUDIT FINDING
```

---

## SINGLE SOURCE OF TRUTH PRINCIPLE

**Rule:** Each category MUST use ONE consistent source of truth across ALL formulas.

### Category Mapping (CANDIDATE - Pending Profiling Confirmation)

```
UNIT:
  Source of Truth: penjualan='03'
  Formula: if(penjualan='03', kotor*kurs, 0)
  Alternate: if(group_product='UNIT', kotor*kurs, 0) ← DO NOT USE
  Hybrid: if(penjualan='03' OR group_product='UNIT', ...) ← FORBIDDEN

JASA:
  Source of Truth: group_product='JS'
  Formula: if(group_product='JS', kotor*kurs, 0)
  Alternate: if(penjualan='01', kotor*kurs, 0) ← DO NOT USE
  Hybrid: if(penjualan='01' AND group_product='JS', ...) ← FORBIDDEN

SPAREPART:
  Source of Truth: group_product='SP'
  Formula: if(group_product='SP', kotor*kurs, 0)
  Alternate: if(penjualan='02' OR penjualan='01', ...) ← DO NOT USE
  Hybrid: mixing penjualan + group_product ← FORBIDDEN
```

---

## IMPLEMENTATION RULE (STRICT)

### During Coding Phase:

**BEFORE any formula is written, determine:**

```
For UNIT:
  Q: Should we use penjualan='03' OR group_product='UNIT'?
  A: Check profiling results (diag_penjualan_kombinasi.txt)
     - If 03 always pairs with UNIT: use penjualan='03'
     - If 03 sometimes pairs with other groups: use group_product='UNIT'
     - Document the decision in code comment
     - Enforce this SINGLE source in ALL related formulas

For JASA:
  Q: Should we use penjualan='01' OR group_product='JS'?
  A: Check profiling results (diag_penjualan_kombinasi.txt)
     - If 01 always pairs with JS: use EITHER (but pick ONE)
     - If 01 sometimes pairs with SP: MUST use group_product='JS'
     - Document the decision in code comment
     - Enforce this SINGLE source in ALL related formulas

For SPAREPART:
  Q: Should we use penjualan='02' OR group_product='SP' OR combination?
  A: Check profiling results
     - NEVER use penjualan codes alone
     - MUST use group_product='SP'
     - Document the decision in code comment
     - Enforce this SINGLE source in ALL related formulas
```

---

## ENFORCEMENT DURING CODE REVIEW

**Code Review Checklist (MANDATORY):**

```
For each formula (cunit_idr, cjasa_idr, cspare_idr, etc):

□ Is source of truth clearly documented?
  Example: // UNIT source: penjualan='03'
  
□ Does formula use ONLY this source?
  BAD:  if((penjualan='03' OR group_product='UNIT'), ...)
  GOOD: if(penjualan='03', ...)
  
□ Is source consistent across all related formulas?
  BAD:  cunit_idr uses penjualan
        compute_unit uses group_product
  GOOD: Both use same source
  
□ Is there a fallback/exception logic?
  BAD:  if(penjualan='03', ...) ELSE if(group_product, ...)
  GOOD: Only one path executed
  
□ No mixing of sources in same formula?
  BAD:  if(penjualan='03' AND group_product='SP', ...)
  GOOD: Only one condition tested
```

---

## DOCUMENTATION REQUIREMENT

**In every formula, add source-of-truth comment:**

```powerbuilder
// UNIT: Source of truth = penjualan='03'
// (Confirmed by profiling: 03 always pairs with UNIT)
cunit_idr = if(penjualan='03', kotor*kurs, 0)

// JASA: Source of truth = group_product='JS'
// (Confirmed by profiling: 01 maps to either JS or SP, must use group_product)
cjasa_idr = if(group_product='JS', kotor*kurs, 0)

// SPAREPART: Source of truth = group_product='SP'
// (Confirmed by profiling: must not use penjualan codes)
cspare_idr = if(group_product='SP', kotor*kurs, 0)
```

---

## PREVENTING MULTI-SOURCE CONFUSION

### NEVER DO THIS:

```powerbuilder
// ❌ WRONG: Different sources in same category
cjasa_idr = if(penjualan='01', kotor*kurs, 0)      // Uses penjualan
cjasa_detail = if(group_product='JS', kotor*kurs, 0) // Uses group_product

// ❌ WRONG: Mixing sources in one formula
cspare_idr = if((penjualan='01' OR penjualan='02' OR group_product='SP'), 
                kotor*kurs, 0)

// ❌ WRONG: Fallback logic
cunit_idr = if(penjualan='03', kotor*kurs,
               if(group_product='UNIT', kotor*kurs, 0))

// ❌ WRONG: Implicit source switching
IF penjualan='03' THEN unit ELSE spare ENDIF
```

### ALWAYS DO THIS:

```powerbuilder
// ✅ CORRECT: Single source, consistent across all formulas
// UNIT: penjualan='03'
cunit_idr = if(penjualan='03', kotor*kurs, 0)
compute_unit_idr = sum(cunit_idr for group 1)

// JASA: group_product='JS'
cjasa_idr = if(group_product='JS', kotor*kurs, 0)
compute_jasa_idr = sum(cjasa_idr for group 1)

// SPAREPART: group_product='SP'
cspare_idr = if(group_product='SP', kotor*kurs, 0)
compute_spare_idr = sum(cspare_idr for group 1)
```

---

## IMPACT OF THIS RULE

### Benefits:

✅ **Consistency**: All reports use same logic = same numbers  
✅ **Auditability**: Clear which source is authoritative  
✅ **Maintainability**: Change source in one place = propagate everywhere  
✅ **Future-proof**: Adding new categories doesn't break existing logic  

### Risks of NOT Following:

❌ **Multiple truth sources**: Report A shows 100, Report B shows 95  
❌ **Audit findings**: "Why do different reports show different revenue?"  
❌ **Hard to debug**: Which formula is source of truth?  
❌ **Fragility**: Future changes might break one formula but not another  

---

## SIGN-OFF REQUIREMENT

**In code review, reviewer MUST confirm:**

```
BEFORE APPROVAL:

□ Single Source of Truth documented
□ All formulas use ONLY their designated source
□ Source is consistent across related formulas
□ No fallback/exception logic present
□ Comments clearly state which source is used
□ No mixing of penjualan + group_product in same formula

IF ANY of above NOT satisfied:
  → REJECT code, ask developer to fix
  → Do NOT approve until all rules followed
```

---

## ENFORCEMENT TIMELINE

| Phase | Action |
|-------|--------|
| Code Review | Verify single source per formula |
| QA Testing | Validate same results across all related reports |
| UAT | Confirm no number discrepancies |
| Production | Lock formula (no further changes without review) |

---

## EXCEPTION PROCESS

**IF situation requires mixing sources:**

```
STEP 1: Document why mixing is necessary
STEP 2: Get explicit approval from:
  - Technical Lead
  - Finance Manager
  - Project Manager
STEP 3: Add exception note in code:
  // EXCEPTION: [reason]
  // Approved by: [names, date]
  // [hybrid formula here]
STEP 4: Add to regression test suite
```

**Target:** ZERO exceptions (this is a design smell)

---

**Single Source of Truth Rule Status:** ✅ FINAL & MANDATORY  
**Enforcement:** Code Review phase (BLOCKING)  
**Exception Process:** Requires 3-person approval

