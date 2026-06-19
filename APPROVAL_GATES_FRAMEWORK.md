# APPROVAL GATES FRAMEWORK
## Rekap Penjualan By Customer - Report Fix

**Framework Status:** ✅ FINAL  
**Date:** 2026-06-16  
**Owner:** Project Technical Review  

---

## PURPOSE

Mencegah implementasi formula yang salah sebelum dibuktikan dengan data produksi.

**Tujuan Approval Gates:**
- ✅ Validasi hipotesis formula terhadap data real
- ✅ Deteksi edge case/kategori unexpected
- ✅ Memastikan balance integrity sebelum coding
- ✅ Menurunkan risk production deployment

---

## APPROVAL GATES (4 GATES WAJIB LOLOS)

### GATE 1: Mapping Kategori ✅ WAJIB LOLOS

**File:** `diag_penjualan_kombinasi.txt`

**Deskripsi:**
Matrix kombinasi `penjualan` code vs `group_product`.

**Expected Pattern (AMAN):**
```
penjualan | group_product | jumlah | total_kotor
----------|---------------|--------|-------------
01        | JS            | 245    | 15.2M
01        | SP            | 178    | 8.5M
02        | SP            | 412    | 23.5M
03        | UNIT          | 89     | 45.7M
```

**Red Flag Pattern (STOP - HARUS INVESTIGATE):**
```
03 | SP          ← Kode 03 dengan SP? Unexpected!
03 | JS          ← Kode 03 dengan JS? Unexpected!
02 | UNIT        ← Kode 02 dengan UNIT? Unexpected!
02 | JS          ← Kode 02 dengan JS? Unexpected!
01 | UNIT        ← Kode 01 dengan UNIT? Unexpected!
```

**Approval Criteria:**
```
✅ PASS: Hanya 4 kombinasi: (01,JS), (01,SP), (02,SP), (03,UNIT)
❌ FAIL: Ada kombinasi di atas red flag
⚠️  INVESTIGATE: Jika ada kombinasi lain
    → Tanya business: "Kombinasi ini seharusnya kemana?"
    → Update mapping design sebelum coding
```

**Formula Impact Jika FAIL:**
```
Jika ada: 03+SP dan formula if(penjualan='03', ...)
  → Unit akan include SP items juga ❌ SALAH

Solusi: Ganti ke if(group_product='UNIT', ...)
```

---

### GATE 2: Inventory Group Product ✅ WAJIB LOLOS

**File:** `diag_group_product_agregasi.txt`

**Deskripsi:**
Agregasi semua nilai `group_product` dengan persentase dari total kotor.

**Expected Pattern (AMAN):**
```
group_product | jumlah | total_kotor | pct
JS            | 245    | 15.2M       | 20%
SP            | 590    | 58.9M       | 78%
UNIT          | 89     | 2.1M        | 3%
```

**Red Flag Pattern (STOP - JANGAN SILENT CATCH):**
```
group_product | jumlah | total_kotor | pct
JS            | 245    | 15.2M       | 20%
SP            | 590    | 58.9M       | 70%
ACC           | 34     | 5.2M        | 6%   ← UNEXPECTED!
UNIT          | 89     | 2.1M        | 3%
FRT           | 12     | 0.5M        | 1%   ← UNEXPECTED!
```

**Approval Criteria:**
```
✅ PASS: Hanya 3 kategori: JS, SP, UNIT
❌ FAIL: Ada kategori selain ketiga di atas
⚠️  INVESTIGATE: Jika ada kategori baru
    → Tanya business: "ACC/FRT ini kategori apa? Masuk ke Spare Parts?"
    → JANGAN asal masukkan ke formula
    → Update design, add kolom baru, atau adjust mapping
    → Re-validate balance sebelum coding
```

**Formula Impact Jika FAIL:**
```
Jika ada ACC (5%) dan formula if(group_product='SP', ...)
  → ACC tidak akan ter-capture
  → UNIT + JASA + SPARE < KOTOR ❌ NOT BALANCE
  → Report akan misleading (missing 5% revenue)

Solusi: 
  Opsi A: if(group_product IN ('SP','ACC'), ...)
  Opsi B: Buat kolom ACC terpisah
  Tergantung business decision
```

---

### GATE 3: Orphan Category Audit ✅ WAJIB LOLOS

**File:** `diag_orphan_category.txt`

**Deskripsi:**
Audit untuk kategori yang bukan JS, SP, atau UNIT.
Ini untuk mencegah silent bug ketika ada produk baru ditambahkan.

**Expected Pattern (AMAN):**
```
[File KOSONG - 0 rows]
```

**Red Flag Pattern (STOP IMMEDIATELY):**
```
group_product | jumlah | total_kotor
ACC           | 34     | 5.2M
FRT           | 12     | 0.5M
OTH           | 8      | 1.2M
```

**Approval Criteria:**
```
✅ PASS: File kosong (0 rows) ATAU hanya NULL
❌ FAIL: Ada nilai apa pun selain JS, SP, UNIT
    → STOP JANGAN LANJUT
    → Masalah data quality atau ada produk baru tidak ter-mapping
    → Harus investigate dan clean up SEBELUM coding
```

**Why This Gate is CRITICAL:**
```
This is the bug yang biasanya baru terdeteksi SETELAH go-live.

Skenario:
  - Coding deploy, test OK dengan data existing
  - 3 bulan kemudian: Produk ACC ditambahkan
  - ACC tidak ada di formula → Silent tidak ter-capture
  - Beberapa bulan kemudian: "Laporan tidak balance!"

Dengan gate ini, deteksi lebih awal saat profiling.
```

---

### GATE 4: Balance Validation ✅ WAJIB LOLOS

**File:** `diag_balance_not_ok.txt`

**Deskripsi:**
Query menampilkan HANYA invoice yang NOT BALANCE.
Jika formula benar, file harus kosong.

**Expected Pattern (AMAN):**
```
[File KOSONG - 0 rows]
```

**Red Flag Pattern (STOP - FORMULA BUG):**
```
bukti_id      | tgl  | unit | jasa | spare | kotor | variance
INV-001       | ... | 100  | 30   | 50    | 180   | 0        ✓
INV-002       | ... | 0    | 20   | 60    | 80    | 0        ✓
INV-003       | ... | 150  | 0    | 0     | 150   | 0        ✓
INV-005       | ... | 100  | 30   | 50    | 190   | 10       ✗ NOT BALANCE
INV-017       | ... | 0    | 0    | 0     | 50    | 50       ✗ NOT BALANCE
```

**Approval Criteria:**
```
✅ PASS: 0 rows - Semua invoice balance
❌ FAIL: Ada baris apa pun (> 0 rows)
    → NOT BALANCE = formula salah
    → STOP JANGAN CODING
    → Investigate:
       1. Cek kombinasi penjualan+group_product di invoice tsb
       2. Apakah ada kategori yang missing dari formula?
       3. Update formula
       4. Re-run query ini
    → Jika tetap ada: Mungkin ada bug di query atau data quality issue
```

**Variance Interpretation:**
```
variance = ABS((UNIT + JASA + SPARE) - KOTOR)

variance = 0     → ✅ Perfect balance
variance < 1     → ✅ OK (rounding error)
variance > 1     → ❌ NOT BALANCE - investigate
variance >> 100  → 🔴 CRITICAL - major category missing
```

**Root Cause Investigation (Jika FAIL):**

```
Invoice INV-005: variance = 10

Steps:
1. Lihat transaksi detail di invoice INV-005
2. Breakdown per penjualan + group_product:
   
   penjualan | group_product | kotor
   01        | JS            | 30  → Masuk JASA ✓
   01        | SP            | 50  → Masuk SPARE ✓
   03        | ???           | 10  ← UNKNOWN!
   
3. Jika group_product = NULL atau tidak ada mapping:
   → Data quality issue (NULL di database)
   → Atau ada kode 03 dengan group_product yang tidak expected
   
4. Update formula untuk handle case ini
5. Re-validate
```

---

## APPROVAL GATE CHECKLIST

```
SEBELUM CODING DIMULAI, SEMUA HARUS ✅:

□ GATE 1: Mapping Kategori
  File: diag_penjualan_kombinasi.txt
  ✅ Hanya (01,JS), (01,SP), (02,SP), (03,UNIT)
  ✅ Tidak ada kombinasi unexpected
  
□ GATE 2: Inventory Group Product  
  File: diag_group_product_agregasi.txt
  ✅ Hanya JS, SP, UNIT
  ✅ Tidak ada ACC/FRT/OTH/EXP/MISC
  
□ GATE 3: Orphan Category Audit
  File: diag_orphan_category.txt
  ✅ KOSONG (0 rows)
  ✅ Jika ada: harus investigate dulu
  
□ GATE 4: Balance Validation
  File: diag_balance_not_ok.txt
  ✅ KOSONG (0 rows)
  ✅ Semua invoice balance
  ✅ Jika ada: harus fix formula dulu

HASIL APPROVAL DECISION:

✅ ALL GATES PASS
   → APPROVE formula untuk coding
   → Proceed to implementation phase
   
⚠️  GATE DENGAN WARNING (ada kategori unexpected)
   → HOLD design review
   → Discuss dengan business
   → Update design jika perlu
   → Re-run diagnostic
   → Re-validate gates
   
❌ ANY GATE FAIL
   → STOP coding completely
   → Investigate root cause
   → Fix data quality atau update formula
   → Re-run diagnostic
   → Re-validate gates
```

---

## FINAL FORMULA (Jika Semua Gates PASS)

```powerbuilder
// ===== DETAIL BAND =====

cunit_idr = 
  if(penjualan='03',
     kotor_asli * penjualan_kurs,
     0)

cjasa_idr = 
  if(group_product='JS',
     kotor_asli * penjualan_kurs,
     0)

cspare_idr = 
  if(group_product='SP',
     kotor_asli * penjualan_kurs,
     0)

ckotor_idr = 
  kotor_asli * penjualan_kurs

// ===== GROUP HEADER =====

compute_unit_idr = sum(cunit_idr for group 1)
compute_jasa_idr = sum(cjasa_idr for group 1)
compute_spare_idr = sum(cspare_idr for group 1)
compute_kotor_idr = sum(ckotor_idr for group 1)

// ===== VALIDATION =====
// compute_balance_check = 
//   IF (compute_unit_idr + compute_jasa_idr + compute_spare_idr 
//       = compute_kotor_idr)
//     THEN "OK" ELSE "ERROR"
```

---

## IF GATES FAIL - ALTERNATIVE DESIGNS

### Scenario: Ada kategori ACC (Accessories)

**Problem:**
- diag_group_product_agregasi.txt menunjukkan ACC ada 5% dari total
- Query 4.1 menunjukkan ACC adalah kategori yang jelas (tidak NULL, not mistype)

**Decision Options:**

**Option A: Masukkan ACC ke Spare Parts**
```powerbuilder
cspare_idr = if(group_product IN ('SP','ACC'), kotor*kurs, 0)
// Result: UNIT + JASA + SPARE akan balance
// Note: ACC dianggap sebagai "extended" spare parts
```

**Option B: Buat kolom ACC terpisah**
```powerbuilder
cacc_idr = if(group_product='ACC', kotor*kurs, 0)
// Result: Report punya kolom ACC terpisah
// Note: User bisa lihat breakdown ACC vs SP
// Kolom layout: UNIT | JASA | SPARE | ACC | KOTOR
```

**Option C: Classify ACC ke UNIT atau JASA**
```
// Tanya ke business:
// "ACC (accessories) itu sebaiknya counted sebagai apa?"
// - Part of UNIT?
// - Part of SPARE PARTS?
// - Separate line item?
```

**Process if Option Chosen:**
1. Update formula sesuai pilihan
2. Re-run `diag_balance_validation.txt` 
3. Verify balance untuk 40 invoices
4. Baru lanjut coding

---

## IMPLEMENTATION WORKFLOW

```
Approval Gates Framework
      ↓
Run Diagnostic Script (5-10 min)
      ↓
Generate 7 Files Output
      ↓
Review 4 Gates:
├─ Gate 1: diag_penjualan_kombinasi.txt
├─ Gate 2: diag_group_product_agregasi.txt  
├─ Gate 3: diag_orphan_category.txt
└─ Gate 4: diag_balance_not_ok.txt
      ↓
      ├─ ✅ ALL PASS? → SIGN-OFF + CODING
      │
      └─ ⚠️ FAIL?
         ├─ Investigate root cause
         ├─ Design adjustment (jika perlu)
         ├─ Re-run diagnostic
         └─ Re-validate gates
            ↓
            └─ ✅ PASS now? → SIGN-OFF + CODING
                ❌ Still fail? → ESCALATE/STOP
```

---

## AUTHORITY & SIGN-OFF

| Role | Responsibility | Approval Authority |
|------|---------------|--------------------|
| Technical | Analyze diagnostic results | ✅ Claude/Developer |
| Business | Decide on unexpected categories | ✅ Finance/Product Owner |
| QA | Verify balance proof | ✅ QA Lead |
| Project Manager | Gate decision | ✅ Project Lead |

**Sign-Off Template:**
```
APPROVAL GATES REVIEW SIGN-OFF

Date: [date]
Diagnostic Run: [timestamp]

GATE 1 - Mapping Kategori:        ✅ PASS / ⚠️ WARNING / ❌ FAIL
GATE 2 - Inventory Group Product: ✅ PASS / ⚠️ WARNING / ❌ FAIL  
GATE 3 - Orphan Category Audit:   ✅ PASS / ⚠️ WARNING / ❌ FAIL
GATE 4 - Balance Validation:      ✅ PASS / ⚠️ WARNING / ❌ FAIL

DECISION: 
  ✅ Approve formula for coding
  ⚠️  Hold pending design clarification  
  ❌ Stop - must investigate further

Approved by: [Name]
Date: [date]
```

---

## CONCLUSION

Approval Gates Framework ini memastikan:
1. ✅ Formula dibuktikan dengan data real SEBELUM coding
2. ✅ Edge cases & unexpected categories terdeteksi early
3. ✅ Balance integrity dijamin sebelum production
4. ✅ Risk production deployment diminimalisir

**No exceptions.** Jika ANY gate fails, tidak boleh lanjut ke coding.

---

**Document Status:** ✅ FINAL & APPROVED FOR USE  
**Last Updated:** 2026-06-16

