# ARTEFACT 2: BEFORE vs AFTER FORMULA MATRIX
## Report: dw_rpt_jual_faktur1_rekap
**Date:** 2026-06-16  
**Scope:** Compute Field Changes Only

---

## EXECUTIVE SUMMARY

This matrix documents each formula added, its source of truth, validation logic, and governance compliance. No existing formulas were modified (ADDITIVE ONLY).

---

## ⚠️ IMPLEMENTATION CORRECTION (2026-06-16)

Dua bug ditemukan saat implementasi di PowerBuilder 11.5 dan sudah diperbaiki:

**BUG 1 — Operator `IN(...)` tidak didukung PowerBuilder DataWindow.**
`IN(...)` adalah sintaks SQL, bukan ekspresi DataWindow. Penyebab error
"incorrect syntax". Diganti dengan rangkaian kondisi `or`.

**BUG 2 — Field `group_produk` berisi NAMA group, bukan KODE.**
SQL retrieve mengisi `group_produk` dari subquery `nama_group`
(mis. `'UNIT TRUCK THERMO KING'`), sehingga `group_produk='TR'` tidak pernah cocok.
Kode `'TR','TB',...` di artefak ini = nilai `im_produk.group_product` (= `kode_group`).

**FIX (source of truth tetap group_product):**
- Ditambah kolom baru `kode_grp` = `im_produk.group_product` di SQL SELECT + column def.
- Formula memakai `kode_grp` dengan operator `or`.

**Formula final yang dipakai (pengganti yang di bawah):**
```
cunit_idr  = if(kode_grp='TR' or kode_grp='TB' or kode_grp='TYU' or kode_grp='FU' or kode_grp='BCS' or kode_grp='FUS' or kode_grp='OB' or kode_grp='NR' or kode_grp='BX', kotor_asli * penjualan_kurs, 0)
cjasa_idr  = if(kode_grp='JS01' or kode_grp='JS02' or kode_grp='JS03' or kode_grp='JS04' or kode_grp='JS05' or kode_grp='JS06' or kode_grp='JS07', kotor_asli * penjualan_kurs, 0)
cspare_idr = if(kode_grp='TS' or kode_grp='TL' or kode_grp='NDS' or kode_grp='LA' or kode_grp='FS' or kode_grp='OS' or kode_grp='FP' or kode_grp='CS' or kode_grp='TSA' or kode_grp='FL' or kode_grp='L' or kode_grp='MT', kotor_asli * penjualan_kurs, 0)
```
Blok formula di bawah (memakai `group_produk IN (...)`) adalah versi desain awal — gunakan versi di atas.

---

## DETAIL BAND COMPUTE FIELDS

### NEW FIELD 1: cunit_idr
**Position:** Detail band (added after line 182)  
**Status:** NEW (not in original report)

#### Formula
```powerscript
if(group_produk IN ('TR','TB','TYU','FU','BCS','FUS','OB','NR','BX'), 
   kotor_asli * penjualan_kurs, 
   0)
```

#### Formula Breakdown
| Component | Source | Validation |
|-----------|--------|-----------|
| `group_produk` | im_produk.group_product | ✅ Source of Truth (approved by framework) |
| Category list `('TR','TB','TYU','FU','BCS','FUS','OB','NR','BX')` | MAPPING_GROUP_PRODUCT.txt | ✅ 9 codes = UNIT category |
| `kotor_asli` | tsales2.kotor_asli | ✅ Original (unconverted) amount |
| `penjualan_kurs` | im_product_group.kurs | ✅ Exchange rate for conversion |
| Multiplication | Standard | ✅ Correct multi-currency logic |
| Default 0 | Logic | ✅ No revenue if category doesn't match |

#### Governance Compliance
- **Single Source of Truth Rule:** ✅ Uses ONLY group_produk (not penjualan code)
- **No Catch-All Logic:** ✅ Explicit IN list, not negative condition
- **Multi-Currency:** ✅ Applies exchange rate
- **Balance Check:** ✅ Contributes to sum validation

#### Data Sample Validation
From REVENUE_DISTRIBUTION.txt:
```
group_product | revenue (IDR) | expected_in_cunit_idr
-------------|--------------|---------------------
TR           | 568.7 Billion | YES
TB           | 283.2 Billion | YES
TYU          | 12.0 Billion  | YES
FU           | 9.6 Billion   | YES
BCS          | 4.9 Billion   | YES
BX           | 4.3 Billion   | YES
FUS          | 1.1 Billion   | YES
OB           | (included in TR) | YES via mapping
NR           | 11.6 Billion  | YES
```
**Total Unit Revenue Expected:** ~895 Billion IDR

---

### NEW FIELD 2: cjasa_idr
**Position:** Detail band (added after cunit_idr)  
**Status:** NEW (not in original report)

#### Formula
```powerscript
if(group_produk IN ('JS01','JS02','JS03','JS04','JS05','JS06','JS07'), 
   kotor_asli * penjualan_kurs, 
   0)
```

#### Formula Breakdown
| Component | Source | Validation |
|-----------|--------|-----------|
| `group_produk` | im_produk.group_product | ✅ Source of Truth |
| Category list `('JS01'...'JS07')` | MAPPING_GROUP_PRODUCT.txt | ✅ 7 codes = JASA category |
| `kotor_asli` | tsales2.kotor_asli | ✅ Original amount |
| `penjualan_kurs` | Exchange rate | ✅ Multi-currency |
| Default 0 | Logic | ✅ No revenue if not JASA |

#### Governance Compliance
- **Single Source of Truth Rule:** ✅ Uses ONLY group_produk
- **No Catch-All Logic:** ✅ Explicit IN list
- **Multi-Currency:** ✅ Applies exchange rate
- **Balance Check:** ✅ Contributes to sum validation

#### Data Sample Validation
From REVENUE_DISTRIBUTION.txt:
```
group_product | revenue (IDR) | expected_in_cjasa_idr
-------------|--------------|----------------------
JS01         | 695.9 Million | YES
JS02         | 8.3 Million   | YES
JS03         | 2,079.4 Million | YES
JS04         | 1,408.7 Million | YES
JS05         | 580.6 Million  | YES
JS06         | 85.3 Million   | YES
JS07         | 68.0 Million   | YES
```
**Total JASA Revenue Expected:** ~4.9 Billion IDR

---

### NEW FIELD 3: cspare_idr
**Position:** Detail band (added after cjasa_idr)  
**Status:** NEW (not in original report)

#### Formula
```powerscript
if(group_produk IN ('TS','TL','NDS','LA','FS','OS','FP','CS','TSA','FL','L','MT'), 
   kotor_asli * penjualan_kurs, 
   0)
```

#### Formula Breakdown
| Component | Source | Validation |
|-----------|--------|-----------|
| `group_produk` | im_produk.group_product | ✅ Source of Truth |
| Category list (12 codes) | MAPPING_GROUP_PRODUCT.txt | ✅ SPARE PARTS category |
| `kotor_asli` | tsales2.kotor_asli | ✅ Original amount |
| `penjualan_kurs` | Exchange rate | ✅ Multi-currency |
| Default 0 | Logic | ✅ No revenue if not SPARE |

#### Governance Compliance
- **Single Source of Truth Rule:** ✅ Uses ONLY group_produk
- **No Catch-All Logic:** ✅ Explicit IN list (12 items)
- **Multi-Currency:** ✅ Applies exchange rate
- **Balance Check:** ✅ Contributes to sum validation

#### Data Sample Validation
From REVENUE_DISTRIBUTION.txt:
```
group_product | revenue (IDR) | expected_in_cspare_idr
-------------|--------------|------------------------
TS           | 49.5 Billion  | YES
TL           | 3.2 Billion   | YES
NDS          | 686 Million   | YES
LA           | 157.5 Million | YES
FS           | 54.2 Million  | YES
OS           | 42.0 Million  | YES
FP           | (not listed)  | CHECK
CS           | (not listed)  | CHECK
TSA          | (not listed)  | CHECK
FL           | (not listed)  | CHECK
L            | 13.5 Billion  | YES
MT           | 2.2 Billion   | YES
```
**Total SPARE Revenue Expected:** ~69 Billion IDR

---

## GROUP HEADER.1 BAND COMPUTE FIELDS

### NEW FIELD 4: c_sum_unit_idr
**Position:** Group header.1 (added after line 169)  
**Status:** NEW (not in original report)

#### Formula
```powerscript
sum(cunit_idr for group 1)
```

#### Purpose
Summary of UNIT revenue per invoice (group 1 = per penjualan_bukti_reff)

#### Formula Validation
- Uses Detail field: `cunit_idr` ✅ (defined above)
- Scope: `for group 1` ✅ (aggregates per-invoice)
- Output: Decimal(19,2) ✅

---

### NEW FIELD 5: c_sum_jasa_idr
**Position:** Group header.1 (added after c_sum_unit_idr)  
**Status:** NEW (not in original report)

#### Formula
```powerscript
sum(cjasa_idr for group 1)
```

#### Purpose
Summary of JASA revenue per invoice

#### Formula Validation
- Uses Detail field: `cjasa_idr` ✅ (defined above)
- Scope: `for group 1` ✅ (aggregates per-invoice)
- Output: Decimal(19,2) ✅

---

### NEW FIELD 6: c_sum_spare_idr
**Position:** Group header.1 (added after c_sum_jasa_idr)  
**Status:** NEW (not in original report)

#### Formula
```powerscript
sum(cspare_idr for group 1)
```

#### Purpose
Summary of SPARE PARTS revenue per invoice

#### Formula Validation
- Uses Detail field: `cspare_idr` ✅ (defined above)
- Scope: `for group 1` ✅ (aggregates per-invoice)
- Output: Decimal(19,2) ✅

---

## BALANCE VALIDATION

### Per-Invoice Level (Group Header)
```
c_sum_unit_idr + c_sum_jasa_idr + c_sum_spare_idr 
MUST EQUAL 
sum(ckotor_idr for group 1)
```

**Tolerance:** 0 (exact match required due to deterministic formulas)

**Test Scenario:**
- Invoice with 3 line items: 1 UNIT, 1 JASA, 1 SPARE
- c_sum_unit_idr = sum of UNIT lines
- c_sum_jasa_idr = sum of JASA lines
- c_sum_spare_idr = sum of SPARE lines
- Total must equal invoice's ckotor_idr

---

## UNMODIFIED FORMULAS (For Reference)

| Field | Existing Formula | Status |
|-------|------------------|--------|
| ckotor | sum(ckotor for group 1) | ✅ UNCHANGED |
| ckotor_idr | sum(ckotor_idr for group 1) | ✅ UNCHANGED |
| pot_kurs | sum(pot_kurs for group 1) | ✅ UNCHANGED |
| pot_idr | sum(pot_idr for group 1) | ✅ UNCHANGED |

No existing formula was modified.

---

## SOURCE OF TRUTH AUDIT

### Rule: Use group_produk, NOT im_product_group_penjualan

| Formula | Field Used | Compliance |
|---------|-----------|-----------|
| cunit_idr | group_produk | ✅ SOT approved |
| cjasa_idr | group_produk | ✅ SOT approved |
| cspare_idr | group_produk | ✅ SOT approved |

**Reason:** group_produk is the single source of truth per SINGLE_SOURCE_OF_TRUTH_RULE.md.  
**Not Used:** im_product_group_penjualan (penjualan code) - intentionally avoided.

---

## SIGN-OFF

**Formulas Reviewed By:** _________________ Date: _________

**SOT Compliance Verified:** ______________ Date: _________

