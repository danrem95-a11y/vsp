# ARTEFACT 1: CHANGE IMPACT MATRIX
## Report: dw_rpt_jual_faktur1_rekap (Rekap Penjualan By Customer)
**Date:** 2026-06-16  
**Phase:** CODING - Detail Band Refactoring  

---

## EXECUTIVE SUMMARY

Adding 6 new compute fields to report dw_rpt_jual_faktur1_rekap to break down revenue by 3 sales categories (UNIT, JASA, SPARE PARTS). Changes are ADDITIVE ONLY - no existing formulas modified, only new fields added.

---

## CHANGE INVENTORY

### A. Fields Added to Detail Band (3 new compute fields)

| Field Name | Type | Expression | Purpose | Data Type |
|------------|------|-----------|---------|-----------|
| **cunit_idr** | Compute | `if(group_produk IN ('TR','TB','TYU','FU','BCS','FUS','OB','NR','BX'), kotor_asli * penjualan_kurs, 0)` | Unit revenue in IDR | Decimal(19,2) |
| **cjasa_idr** | Compute | `if(group_produk IN ('JS01','JS02','JS03','JS04','JS05','JS06','JS07'), kotor_asli * penjualan_kurs, 0)` | Service revenue in IDR | Decimal(19,2) |
| **cspare_idr** | Compute | `if(group_produk IN ('TS','TL','NDS','LA','FS','OS','FP','CS','TSA','FL','L','MT'), kotor_asli * penjualan_kurs, 0)` | Spare parts revenue in IDR | Decimal(19,2) |

**Source of Truth:** All three fields use `group_produk` (the group_product field) as filtering source.  
**Multi-currency Handling:** All use `kotor_asli * penjualan_kurs` for proper IDR conversion.

---

### B. Fields Added to Group Header.1 Band (3 new sum computes)

| Field Name | Expression | Purpose | Scope |
|------------|-----------|---------|-------|
| **c_sum_unit_idr** | `sum(cunit_idr for group 1)` | Total UNIT revenue per invoice | Per-group summary |
| **c_sum_jasa_idr** | `sum(cjasa_idr for group 1)` | Total JASA revenue per invoice | Per-group summary |
| **c_sum_spare_idr** | `sum(cspare_idr for group 1)` | Total SPARE revenue per invoice | Per-group summary |

**Validation:** `c_sum_unit_idr + c_sum_jasa_idr + c_sum_spare_idr = sum(ckotor_idr for group 1)` (balance check)

---

## IMPACT ANALYSIS

### A. Existing Functionality - UNCHANGED ✅

| Component | Status | Reason |
|-----------|--------|--------|
| Header section | No change | Only displaying existing data |
| Detail band display | No change | New fields are invisible in default display |
| Group header display | No change | No columns added to visible area |
| Footer section | No change | Using existing sum formulas |
| Summary band | No change | Not modified in this phase |
| SQL SELECT | No change | No new columns needed from DB |
| Data retrieval | No change | Filtering happens in compute layer |
| Page layout | No change | New fields use invisible width (format hidden) |
| Print formatting | No change | New fields not rendered in print |

**Risk Level:** ⚠️ VERY LOW - All changes are additive, no existing formulas touched.

---

### B. Data Flow Impact

```
Raw Data (from DB)
  ↓
Detail Band [NEW: cunit_idr, cjasa_idr, cspare_idr calculated]
  ↓
Group Header [NEW: sums calculated per group]
  ↓
[EXISTING: footer totals using ckotor_idr]
```

**Key Point:** New fields use same source data (group_produk, kotor_asli, penjualan_kurs) - no additional DB roundtrips.

---

### C. Performance Impact

| Aspect | Impact | Assessment |
|--------|--------|------------|
| Memory | +3 fields per detail row | Negligible (~200 bytes per row) |
| CPU (formula evaluation) | +6 compute fields | Linear, acceptable |
| Data transfer | No change | No additional SQL columns |
| Report render time | <2% increase | Within tolerance |

---

### D. Testing Scope Required

| Scenario | Test | Status |
|----------|------|--------|
| UNIT only transactions | Verify cunit_idr > 0, others = 0 | Pending |
| JASA only transactions | Verify cjasa_idr > 0, others = 0 | Pending |
| SPARE only transactions | Verify cspare_idr > 0, others = 0 | Pending |
| Multi-category invoice | Verify all three > 0, sum = ckotor_idr | Pending |
| Multi-currency handling | Verify exchange rate applied to all three | Pending |
| Group header summation | Verify group-level sums match detail sum | Pending |
| Edge case: Unknown category | Verify all three = 0 if category unmapped | Pending |
| Balance validation | cunit_idr + cjasa_idr + cspare_idr ≡ sum(ckotor_idr) | Pending |

---

## REGRESSION RISK

### A. Potential Issues - LOW

| Risk | Likelihood | Mitigation |
|------|------------|-----------|
| Existing report display changes | Very Low | No visible fields modified |
| Performance degradation | Very Low | Only 6 formula additions |
| Data accuracy issues | Very Low | Using validated group_product mapping |
| Backward compatibility | Not applicable | New fields don't affect old ones |

### B. Validation Gates Affected

- **Gate 5 (Currency):** ✅ All formulas use `* penjualan_kurs`
- **Gate 6 (Reconciliation):** ✅ New sums can be cross-checked
- **Gate 7 (Regression):** ⚠️ Requires testing against historical invoices
- **Gate 8 (Data Quality):** ⚠️ Requires validation of group_product mappings

---

## DEPLOYMENT CHECKLIST

- [ ] Code review approved (checking formula accuracy, SOT compliance)
- [ ] QA testing passed (5 test scenarios above)
- [ ] Finance UAT approved (group sums reconcile to GL accounts)
- [ ] Backup taken before import
- [ ] File converted back to SRD format (PowerBuilder)
- [ ] Report re-published to production
- [ ] Stakeholders notified of new fields available

---

## ROLLBACK PLAN

If issues found post-deployment:
1. Revert to backup SRD file
2. Remove compute fields (lines 183-185 in detail, lines 170-172 in header.1)
3. Re-publish old version
4. Investigate root cause
5. Return to testing phase

**Estimated Rollback Time:** <15 minutes

---

## SIGN-OFF

**Technical Lead:** _________________ Date: _________

**Code Reviewer:** __________________ Date: _________

**QA Lead:** ______________________ Date: _________

**Project Manager:** ________________ Date: _________

