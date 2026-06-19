# ARTEFACT 3: TEST EVIDENCE MATRIX
## Report: dw_rpt_jual_faktur1_rekap
**Date:** 2026-06-16  
**Test Phase:** Gate 8 QA Validation

---

## EXECUTIVE SUMMARY

This matrix defines all test cases required before refactored report can be deployed. Tests cover: formula correctness, multi-currency handling, category segregation, group summation, and balance validation.

---

## TEST CASE 1: UNIT-ONLY INVOICE

### Scenario
Invoice containing ONLY UNIT category items (group_product IN ('TR','TB','TYU','FU','BCS','FUS','OB','NR','BX'))

### Test Data Sample
```sql
SELECT * FROM test_invoice_unit_only
-- Expected: Contains 2-3 line items from category UNIT
-- Total expected revenue: ~15-20 Million IDR
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| cunit_idr > 0 | YES | N/A | [ ] Pass |
| cjasa_idr = 0 | ALL rows | N/A | [ ] Pass |
| cspare_idr = 0 | ALL rows | N/A | [ ] Pass |
| c_sum_unit_idr > 0 | YES | N/A | [ ] Pass |
| c_sum_jasa_idr = 0 | Group level | N/A | [ ] Pass |
| c_sum_spare_idr = 0 | Group level | N/A | [ ] Pass |
| c_sum_unit_idr = sum(ckotor_idr) | YES | ±0 | [ ] Pass |

### Test Evidence Documentation
**Invoice ID:** ___________________  
**Number of Detail Lines:** _________  
**Report Execution Date:** __________  
**Actual c_sum_unit_idr:** ___________  
**Actual sum(ckotor_idr):** __________  
**Balance Match:** YES / NO  
**Notes:** _________________________

---

## TEST CASE 2: JASA-ONLY INVOICE

### Scenario
Invoice containing ONLY JASA category items (group_product IN ('JS01'...'JS07'))

### Test Data Sample
```sql
SELECT * FROM test_invoice_jasa_only
-- Expected: Contains 2-3 line items from category JASA
-- Total expected revenue: ~500K - 2 Million IDR (smaller category)
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| cunit_idr = 0 | ALL rows | N/A | [ ] Pass |
| cjasa_idr > 0 | YES | N/A | [ ] Pass |
| cspare_idr = 0 | ALL rows | N/A | [ ] Pass |
| c_sum_unit_idr = 0 | Group level | N/A | [ ] Pass |
| c_sum_jasa_idr > 0 | YES | N/A | [ ] Pass |
| c_sum_spare_idr = 0 | Group level | N/A | [ ] Pass |
| c_sum_jasa_idr = sum(ckotor_idr) | YES | ±0 | [ ] Pass |

### Test Evidence Documentation
**Invoice ID:** ___________________  
**Number of Detail Lines:** _________  
**Report Execution Date:** __________  
**Actual c_sum_jasa_idr:** ___________  
**Actual sum(ckotor_idr):** __________  
**Balance Match:** YES / NO  
**Notes:** _________________________

---

## TEST CASE 3: SPARE-ONLY INVOICE

### Scenario
Invoice containing ONLY SPARE PARTS category items (group_product IN ('TS','TL','NDS','LA','FS','OS','FP','CS','TSA','FL','L','MT'))

### Test Data Sample
```sql
SELECT * FROM test_invoice_spare_only
-- Expected: Contains 2-3 line items from category SPARE
-- Total expected revenue: ~5-8 Million IDR
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| cunit_idr = 0 | ALL rows | N/A | [ ] Pass |
| cjasa_idr = 0 | ALL rows | N/A | [ ] Pass |
| cspare_idr > 0 | YES | N/A | [ ] Pass |
| c_sum_unit_idr = 0 | Group level | N/A | [ ] Pass |
| c_sum_jasa_idr = 0 | Group level | N/A | [ ] Pass |
| c_sum_spare_idr > 0 | YES | N/A | [ ] Pass |
| c_sum_spare_idr = sum(ckotor_idr) | YES | ±0 | [ ] Pass |

### Test Evidence Documentation
**Invoice ID:** ___________________  
**Number of Detail Lines:** _________  
**Report Execution Date:** __________  
**Actual c_sum_spare_idr:** __________  
**Actual sum(ckotor_idr):** __________  
**Balance Match:** YES / NO  
**Notes:** _________________________

---

## TEST CASE 4: MIXED CATEGORY INVOICE

### Scenario
Invoice containing items from ALL THREE categories (UNIT + JASA + SPARE on same invoice)

### Test Data Sample
```sql
SELECT * FROM test_invoice_mixed_all
-- Expected: Contains 5-7 line items mixed across all categories
-- UNIT: 2-3 items (~10M)
-- JASA: 1-2 items (~1M)
-- SPARE: 2-3 items (~5M)
-- Total: ~16M IDR
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| cunit_idr > 0 | UNIT rows only | N/A | [ ] Pass |
| cjasa_idr > 0 | JASA rows only | N/A | [ ] Pass |
| cspare_idr > 0 | SPARE rows only | N/A | [ ] Pass |
| c_sum_unit_idr > 0 | YES | N/A | [ ] Pass |
| c_sum_jasa_idr > 0 | YES | N/A | [ ] Pass |
| c_sum_spare_idr > 0 | YES | N/A | [ ] Pass |
| **c_sum_unit_idr + c_sum_jasa_idr + c_sum_spare_idr = sum(ckotor_idr)** | YES | ±0 | [ ] Pass |
| sum > 0 for each detail line | Exactly one | N/A | [ ] Pass |

### Test Evidence Documentation
**Invoice ID:** ___________________  
**Total Detail Lines:** __________  
**  - UNIT lines:** ___  
**  - JASA lines:** ___  
**  - SPARE lines:** ___  
**Actual c_sum_unit_idr:** ___________  
**Actual c_sum_jasa_idr:** ___________  
**Actual c_sum_spare_idr:** ___________  
**Sum of above 3:** ___________  
**Actual sum(ckotor_idr):** __________  
**Balance Match:** YES / NO  
**Variance:** ___________  
**Notes:** _________________________

---

## TEST CASE 5: MULTI-CURRENCY INVOICE

### Scenario
Invoice with items in MULTIPLE currencies (USD, EUR, or other non-IDR), requiring exchange rate conversion

### Test Data Sample
```sql
SELECT * FROM test_invoice_multi_currency
-- Expected: Mix of IDR and USD items
-- IDR items: apply kurs=1
-- USD items: apply actual exchange rate (e.g., kurs=15,000)
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| penjualan_kurs varies | YES (1 or >1) | N/A | [ ] Pass |
| cunit_idr correctly converts | IDR * kurs | ±0.01% | [ ] Pass |
| cjasa_idr correctly converts | IDR * kurs | ±0.01% | [ ] Pass |
| cspare_idr correctly converts | IDR * kurs | ±0.01% | [ ] Pass |
| All values in IDR | YES | N/A | [ ] Pass |
| Exchange rate applied to detail | YES | N/A | [ ] Pass |
| No mixed currencies in sums | All IDR | N/A | [ ] Pass |

### Test Evidence Documentation
**Invoice ID:** ___________________  
**Original Currency:** ___________  
**Exchange Rate (kurs):** ___________  
**Original Amount:** ___________  
**Actual cunit_idr (after conversion):** ___________  
**Actual cjasa_idr (after conversion):** ___________  
**Actual cspare_idr (after conversion):** ___________  
**Calculation Verification:** original * kurs = converted ✓ [ ]  
**All in IDR:** YES [ ] / NO [ ]  
**Notes:** _________________________

---

## TEST CASE 6: GROUP SUMMATION ACCURACY

### Scenario
Verify that group-level sums correctly aggregate detail rows for each category

### Test Data Sample
```sql
SELECT * FROM test_invoice_summation_check
-- Contains 10+ detail lines across all categories
-- Requires manual calculation to verify group sums
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| sum(cunit_idr detail rows) = c_sum_unit_idr | Match | ±0 | [ ] Pass |
| sum(cjasa_idr detail rows) = c_sum_jasa_idr | Match | ±0 | [ ] Pass |
| sum(cspare_idr detail rows) = c_sum_spare_idr | Match | ±0 | [ ] Pass |
| All three sums combined = ckotor_idr | Balance | ±0 | [ ] Pass |
| No double-counting | Correct | N/A | [ ] Pass |
| No missing transactions | All counted | N/A | [ ] Pass |

### Calculation Worksheet
```
Detail Row | group_produk | cunit_idr | cjasa_idr | cspare_idr | Notes
---------|-------------|----------|----------|-----------|-------
1        | _________   | _______  | ______   | _________ | 
2        | _________   | _______  | ______   | _________ | 
3        | _________   | _______  | ______   | _________ | 
...      |
---------|-------------|----------|----------|-----------|-------
GROUP SUM|            | _______  | ______   | _________ |
         |            | =UNIT    | =JASA    | =SPARE    |
---------|-------------|----------|----------|-----------|-------
EXPECTED | (from DB)  | _______  | ______   | _________ |
ACTUAL   | (from report) | _______ | ______   | _________ |
MATCH    |            | YES / NO | YES / NO | YES / NO |
```

### Test Evidence Documentation
**Invoice ID:** ___________________  
**Number of Detail Lines:** _________  
**Manually Calculated UNIT Sum:** ___________  
**Report Actual c_sum_unit_idr:** ___________  
**Match:** YES [ ] / NO [ ]  
**Manually Calculated JASA Sum:** ___________  
**Report Actual c_sum_jasa_idr:** ___________  
**Match:** YES [ ] / NO [ ]  
**Manually Calculated SPARE Sum:** ___________  
**Report Actual c_sum_spare_idr:** ___________  
**Match:** YES [ ] / NO [ ]  
**Combined Total:** ___________  
**Report ckotor_idr:** ___________  
**Match:** YES [ ] / NO [ ]  
**Notes:** _________________________

---

## TEST CASE 7: UNMAPPED/UNKNOWN CATEGORY

### Scenario
Verify behavior when invoice contains group_product code not in any category (edge case)

### Test Data Sample
```sql
SELECT * FROM test_invoice_unknown_category
-- Contains items with group_product not in the 3 categories
-- Expected: All cunit_idr, cjasa_idr, cspare_idr = 0
-- This should NOT happen in production (all codes are mapped)
-- But IF it does, formulas should handle gracefully
```

### Assertions
| Assertion | Expected | Tolerance | Status |
|-----------|----------|-----------|--------|
| Unknown group_product | (e.g., 'XYZ') | N/A | [ ] Pass |
| cunit_idr = 0 | YES | N/A | [ ] Pass |
| cjasa_idr = 0 | YES | N/A | [ ] Pass |
| cspare_idr = 0 | YES | N/A | [ ] Pass |
| Formula doesn't error | YES | N/A | [ ] Pass |
| Report renders | YES | N/A | [ ] Pass |

### Test Evidence Documentation
**Test Data ID:** ___________________  
**Unknown group_product Code:** ___________  
**All three category fields = 0:** YES [ ] / NO [ ]  
**Formula Error:** YES / NO  
**Notes:** _________________________

---

## TEST RESULT SUMMARY

| Test # | Name | Status | Date | Tester | Approved |
|--------|------|--------|------|--------|----------|
| 1 | UNIT-only | [ ] Pass | ________ | __________ | [ ] |
| 2 | JASA-only | [ ] Pass | ________ | __________ | [ ] |
| 3 | SPARE-only | [ ] Pass | ________ | __________ | [ ] |
| 4 | Mixed Categories | [ ] Pass | ________ | __________ | [ ] |
| 5 | Multi-Currency | [ ] Pass | ________ | __________ | [ ] |
| 6 | Group Summation | [ ] Pass | ________ | __________ | [ ] |
| 7 | Unknown Category | [ ] Pass | ________ | __________ | [ ] |

### Overall Result
- **Total Tests:** 7
- **Passed:** _____
- **Failed:** _____
- **% Pass Rate:** ______ %
- **Minimum Required:** 100% (all must pass)

### GO/NO-GO Decision
**Approved for Production:** [ ] YES (100% pass) / [ ] NO (< 100%)

---

## GATE 8 VALIDATION CHECKLIST

Before releasing to production, verify:

- [ ] All 7 test cases executed
- [ ] All test cases passed (100% pass rate)
- [ ] No formula errors during testing
- [ ] Balance validation confirmed (±0)
- [ ] Multi-currency handling verified
- [ ] No performance degradation observed
- [ ] Finance UAT approved (accounting reconciliation)
- [ ] Stakeholders notified
- [ ] Backup taken before deployment
- [ ] Rollback plan documented

---

## SIGN-OFF

**QA Tester Name:** _________________ Date: _________

**QA Lead Approval:** ________________ Date: _________

**Finance UAT Approval:** _____________ Date: _________

**Project Manager Approval:** __________ Date: _________

---

## NOTES

**Execution Instructions:**
1. Use production/staging database with real invoice data
2. Select invoices that cover each test scenario
3. Run refactored report with test data
4. Document actual values in "Test Evidence" sections above
5. Verify all balance checks (sum = expected)
6. If any test fails, STOP and investigate root cause
7. Submit evidence to code review before production deployment

**Failure Handling:**
If any assertion fails:
1. Document the failure condition
2. Capture screenshot/export of report data
3. Review formula accuracy (Artefact 2)
4. Check data quality (is source data correct?)
5. Return to CODING phase for fix
6. Re-test after fix
7. Only deploy if all tests pass

