# LAPORAN ANALISIS FINAL
## Rekap Penjualan By Customer - Report Formula Validation

**Status:** ANALYSIS COMPLETE (Data validation pending)  
**Date:** 2026-06-16  
**Source:** Code analysis + data profiling protocol  
**Next Step:** Run diagnostic script dan share hasil  

---

## BAGIAN 1: RINGKASAN EKSEKUTIF

### Potensi Masalah Ditemukan

Pada **dw_rpt_jual_faktur1_rekap.srd** (report utama):
- ❌ Tidak menggunakan `group_product` untuk filter kategori revenue
- ❌ Semua amounts (kode 01, 02, 03) dijumlahkan tanpa pemisahan kategori
- ❌ **Tidak ada validasi balance** (UNIT + JASA + SPARE = KOTOR)

### Reference Implementation Ditemukan

Pada **d_jual_faktur_lain.srd** (reference datawindow):
- ✅ Menggunakan `group_product='JS'` untuk Jasa
- ✅ Menggunakan `group_product<>'JS'` untuk Spare Parts
- ✅ Logic sudah ada, tinggal diaplikasikan ke report utama

### Root Cause

**Old Developer Asumsi:**
```
Kode 01 = otomatis Jasa + Spare Parts
Harus dipisah 50/50 ke dua kategori
```

**Fakta Sebenarnya:**
```
Kode 01 BISA memiliki MULTIPLE group_product:
  - group_product='JS' → Masuk JASA
  - group_product='SP' → Masuk SPARE PARTS
  
Source of truth adalah group_product, BUKAN penjualan code
```

---

## BAGIAN 2: EXISTING FORMULA (SALAH)

### Detail Band Compute Fields (dw_rpt_jual_faktur1_rekap.srd)

**Current (WRONG):**

```powerbuilder
ckotor = if(penjualan_curr_id='IDR', 0, kotor_asli)
  // Mengambil SEMUA kotor asing tanpa filter kategori
  
ckotor_idr = kotor_asli * penjualan_kurs
  // Mengambil SEMUA kotor IDR tanpa filter kategori
```

**Problem:**
- TIDAK memfilter berdasarkan penjualan code atau group_product
- Semua kode 01, 02, 03 masuk ke kolom yang sama ("Unit")
- Tidak ada pemisahan kategori
- Tidak ada double counting logic (seharusnya ada untuk kode 01)

### Group Summary (WRONG)

```powerbuilder
compute_46: sum(ckotor for group 1)           // Semua
compute_47: sum(ckotor_idr for group 1)       // Semua
// ... 15+ compute fields lainnya, semua tanpa filter
```

**Result:**
```
Kolom "Unit" ditampilkan = Rp X (total SEMUA kode)
Kolom "Spare Parts" = TIDAK ADA
Kolom "Jasa" = TIDAK ADA
```

---

## BAGIAN 3: REFERENCE IMPLEMENTATION (BENAR)

### Formula di d_jual_faktur_lain.srd

**Pattern yang sudah benar:**

```powerbuilder
// JASA - menggunakan group_product
compute_5: sum(if(group_product='JS', kotor, 0) for all)

// SPARE PARTS - menggunakan group_product
compute_2: sum(if(group_product<>'JS', kotor, 0) for all)
```

**Key Insight:**
- Menggunakan `group_product` sebagai sumber kebenaran
- TIDAK menggunakan `penjualan` code untuk kategori
- Logic sudah proven di report lain

---

## BAGIAN 4: FORMULA YANG HARUS DIGUNAKAN

### Berdasarkan Code Analysis Existing

#### Scenario: Jika data menunjukkan HANYA kombinasi JS, SP, UNIT

**Formula Explicit & Safe:**

```powerbuilder
// ===== DETAIL BAND =====

// UNIT: Hanya penjualan='03'
cunit_idr = 
  if(im_product_group_penjualan='03',
     kotor_asli * penjualan_kurs,
     0)

cunit_valuta = 
  if(im_product_group_penjualan='03' AND penjualan_curr_id<>'IDR',
     kotor_asli,
     0)

// JASA: Hanya group_product='JS' (seperti reference impl)
cjasa_idr = 
  if(group_product='JS',
     kotor_asli * penjualan_kurs,
     0)

// SPARE PARTS: Hanya group_product='SP'
cspare_idr = 
  if(group_product='SP',
     kotor_asli * penjualan_kurs,
     0)

// KOTOR: Total semua (tanpa filter)
ckotor_idr = kotor_asli * penjualan_kurs

ckotor_valuta = 
  if(penjualan_curr_id<>'IDR',
     kotor_asli,
     0)

// ===== GROUP HEADER =====

compute_unit_idr = sum(cunit_idr for group 1)
compute_unit_valuta = sum(cunit_valuta for group 1)

compute_jasa_idr = sum(cjasa_idr for group 1)

compute_spare_idr = sum(cspare_idr for group 1)

compute_kotor_idr = sum(ckotor_idr for group 1)
compute_kotor_valuta = sum(ckotor_valuta for group 1)

// ===== VALIDATION (CRITICAL) =====
// Compute ini untuk regression testing:
// compute_balance_check: 
//   IF (compute_unit_idr + compute_jasa_idr + compute_spare_idr = compute_kotor_idr)
//     THEN "OK" ELSE "ERROR"
```

**Key Benefits:**
- ✅ Eksplisit - tidak ada catch-all logic
- ✅ Mudah diaudit dan debug
- ✅ Tidak akan silent catch kategori baru
- ✅ Mengikuti pattern dari reference implementation
- ✅ Memungkinkan validation balance

---

## BAGIAN 5: VALIDASI FORMULA (HARUS DIBUKTIKAN)

### Persyaratan Balance

**Untuk SETIAP group invoice, HARUS:**

```
UNIT_IDR + JASA_IDR + SPAREPART_IDR = KOTOR_IDR
```

**Contoh BENAR:**
```
UNIT         = 100 jt
JASA         = 30 jt
SPARE PARTS  = 50 jt
────────────────────
SUM KATEGORI = 180 jt

KOTOR        = 180 jt

Result: ✓ BALANCE
```

**Contoh SALAH:**
```
UNIT         = 100 jt
JASA         = 30 jt
SPARE PARTS  = 50 jt
────────────────────
SUM KATEGORI = 180 jt

KOTOR        = 200 jt  ← TIDAK BALANCE!

Result: ✗ INVESTIGATE
```

### Test Data yang Dibutuhkan

Dari diagnostic script, HARUS divalidasi:
- [ ] 40 invoices random - semuanya BALANCE
- [ ] 5 invoices dengan kode 01 - check apakah split dengan benar ke JS dan SP
- [ ] 5 invoices dengan kode 02 - semua ke SPARE PARTS
- [ ] 5 invoices dengan kode 03 - semua ke UNIT
- [ ] 5 invoices mixed - validate balance untuk kombinasi kompleks

**Jika ada invoice NOT BALANCE:**
- 🔴 STOP jangan deploy
- Investigasi kategori apa yang missing
- Apakah ada group_product selain JS, SP, UNIT?

---

## BAGIAN 6: FIELD YANG HARUS DIUBAH

### File: dw_rpt_jual_faktur1_rekap.srd

#### Detail Band (Band: detail)

| Field Name | Action | Formula |
|------------|--------|---------|
| cunit_valuta | NEW | `if(im_product_group_penjualan='03' AND penjualan_curr_id<>'IDR', kotor_asli, 0)` |
| cunit_idr | MODIFY from ckotor | `if(im_product_group_penjualan='03', kotor_asli * penjualan_kurs, 0)` |
| cjasa_idr | NEW | `if(group_product='JS', kotor_asli * penjualan_kurs, 0)` |
| cspare_idr | NEW | `if(group_product='SP', kotor_asli * penjualan_kurs, 0)` |
| ckotor_valuta | RENAME from ckotor | `if(penjualan_curr_id<>'IDR', kotor_asli, 0)` |
| ckotor_idr | RENAME from ckotor_idr | `kotor_asli * penjualan_kurs` (keep logic) |

#### Group Header (Band: header.1)

| Compute | Action | Formula |
|---------|--------|---------|
| compute_unit_valuta | NEW | `sum(cunit_valuta for group 1)` |
| compute_unit_idr | MODIFY | `sum(cunit_idr for group 1)` |
| compute_jasa_idr | NEW | `sum(cjasa_idr for group 1)` |
| compute_spare_idr | NEW | `sum(cspare_idr for group 1)` |
| compute_kotor_valuta | MODIFY | `sum(ckotor_valuta for group 1)` |
| compute_kotor_idr | MODIFY | `sum(ckotor_idr for group 1)` |

#### Column Layout (Header)

**NEW Layout:**
```
Customer | Unit Valuta | Unit IDR | Jasa IDR | Spare Parts IDR | Kotor Valuta | Kotor IDR
```

**OLD Layout (berapa field?):**
```
(dari code analysis: ~14 kolom amount, tapi semuanya "Unit")
```

### File: w_rpt_jual.srw

**Status:** ✅ NO CHANGE NEEDED

Alasan:
- Window sudah handle dynamic datawindow loading
- Export/print function already loop through columns generically
- Tidak ada hardcoded column count

### File: d_jual_faktur.srd (Reference Detail)

**Status:** ⚠️ CHECK ONLY

Pastikan field `group_product` tersedia di SELECT (untuk consistency)

---

## BAGIAN 7: ANALISIS RISIKO

### Risk 1: Data Quality Issue

**Risk:** NULL values di group_product atau penjualan

**Mitigation:**
- Query profiling sudah include ISNULL check
- Jika ditemukan NULL, harus investigate data quality
- Jangan lanjut coding sebelum issue diselesaikan

**Impact:** HIGH

---

### Risk 2: Kategori Tidak Terduga

**Risk:** Ada group_product selain 'JS', 'SP', 'UNIT'

**Scenario:**
```
Ditemukan: group_product = 'FRT', 'ACC', 'OTH'
Formula saat ini: if(group_product='SP', ...)
Result: Kategori baru tidak ter-capture, revenue hilang
```

**Mitigation:**
- Query profiling mendeteksi semua kombinasi
- Jika ditemukan kategori baru:
  - Tanya business: "Kategori X kemana?"
  - Update formula untuk include kategori baru
  - Re-validate balance

**Impact:** CRITICAL if not detected early

---

### Risk 3: Balance Not Achieved

**Risk:** UNIT + JASA + SPARE ≠ KOTOR untuk beberapa invoice

**Root Cause Potential:**
- Ada kategori yang tidak di-filter
- Exchange rate handling salah
- Formula ada yang keliru

**Mitigation:**
- Diagnostic script check 40 invoices
- Jika ada NOT BALANCE → investigate & fix formula
- Jangan deploy sebelum 100% balance

**Impact:** CRITICAL - Report akan misleading

---

### Risk 4: Excel Export Column Shift

**Risk:** Pengguna yang punya saved Excel template dengan column references

**Mitigation:**
- Dokumentasikan: "Report layout berubah tanggal [date]"
- Column order: sesuaikan dari requirement (Customer | Unit Val | Unit IDR | Jasa | Spare | Kotor Val | Kotor IDR)
- User perlu re-create Excel templates jika ada

**Impact:** LOW - Excel export tetap berfungsi

---

### Risk 5: Report Performance

**Risk:** 6 compute field baru + complex IF logic = slow report

**Mitigation:**
- Compute fields sudah exist di d_jual_faktur_lain.srd (proven)
- Performance overhead minimal
- Monitor jika group size > 10.000 lines

**Impact:** LOW

---

## BAGIAN 8: TESTING CHECKLIST

### Pre-Deployment

- [ ] Diagnostic script selesai, hasil direview
- [ ] SEMUA kombinasi penjualan+group_product identified
- [ ] 40 invoices validation SEMUA BALANCE
- [ ] Business approval formula
- [ ] Formula hardcoded (no catch-all logic)

### Coding Phase

- [ ] Edit dw_rpt_jual_faktur1_rekap.srd
- [ ] Add 3 compute fields: cunit_valuta, cjasa_idr, cspare_idr
- [ ] Modify 3 compute fields: cunit_idr, ckotor_valuta, ckotor_idr
- [ ] Add 3 group header computes: compute_unit_valuta, compute_jasa_idr, compute_spare_idr
- [ ] Modify 3 group header computes: compute_unit_idr, compute_kotor_valuta, compute_kotor_idr
- [ ] Reorder columns di group header per requirement
- [ ] Compile DW - no errors

### QA Testing

- [ ] Open report di w_rpt_jual.srw
- [ ] Test dengan 5 sample invoices (dari diagnostic data)
- [ ] Check: Column layout correct
- [ ] Check: Values match formula (manual calculation)
- [ ] Check: UNIT + JASA + SPARE = KOTOR (formula validation)
- [ ] Check: Excel export works, columns visible
- [ ] Check: Print preview OK
- [ ] Check: Filter/retrieve still works
- [ ] Performance test: Large dataset (1000+ lines)

### Regression Testing

- [ ] Run same validation on 40 invoices post-deployment
- [ ] Compare: old report values vs new report values
- [ ] KOTOR harus 100% sama (no data loss)
- [ ] UNIT + JASA + SPARE harus ALL = KOTOR

---

## BAGIAN 9: IMPLEMENTATION TIMELINE

| Phase | Task | Duration | Owner |
|-------|------|----------|-------|
| 1 | Run diagnostic script | 1 hour | User |
| 2 | Review results + approve formula | 1 hour | User/Business |
| 3 | Code formula change | 2 hours | Claude |
| 4 | QA testing | 2 hours | User |
| 5 | UAT + approval | 1 hour | Business |
| 6 | Deploy to production | 1 hour | User |
| **TOTAL** | | **8 hours** | |

---

## BAGIAN 10: NEXT STEPS

### Immediate (Hari Ini)

1. **Run diagnostic script:** `c:\BTV\debug\DIAGNOSTIC_SCRIPT_MASTER.ps1`
   ```
   powershell -ExecutionPolicy Bypass -File c:\BTV\debug\DIAGNOSTIC_SCRIPT_MASTER.ps1
   ```

2. **Share hasil files:**
   - diag_penjualan_kombinasi.txt
   - diag_kode_01_detail.txt
   - diag_group_product_values.txt
   - diag_penjualan_codes.txt
   - diag_balance_validation.txt

### Review Phase (Based on Diagnostic Results)

1. **If IDEAL scenario:**
   - Kombinasi: only (01,JS), (01,SP), (02,SP), (03,UNIT)
   - Balance: ALL 40 invoices pass
   - → **GO for coding**

2. **If COMPLEX scenario:**
   - Ada kategori selain JS, SP, UNIT
   - → **Stop, update formula untuk handle semua kategori**

3. **If DATA QUALITY issue:**
   - Ada NULL atau anomali
   - → **Stop, fix data dulu**

---

## KESIMPULAN

### Current Status
- ❌ Report salah - tidak memisahkan kategori dengan benar
- ✅ Reference implementation sudah ada di d_jual_faktur_lain.srd
- ✅ Formula sudah diidentifikasi
- ⏳ Data validation masih pending

### Formula Rekomendasi
```
UNIT     = if(penjualan='03', kotor*kurs, 0)
JASA     = if(group_product='JS', kotor*kurs, 0)
SPARE    = if(group_product='SP', kotor*kurs, 0)
KOTOR    = kotor*kurs (no filter)

Validation: UNIT + JASA + SPARE = KOTOR (100%)
```

### Next Blocker
**Diagnostic script results** - harus lihat data nyata untuk confirm formula 100% correct sebelum implement.

---

**Document prepared:** 2026-06-16  
**Version:** Final Analysis (Ready for Diagnostic Execution)  
**Status:** Awaiting Data Profiling Results

