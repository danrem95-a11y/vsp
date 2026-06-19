# FIX FORMULA DI DISPLAY FIELDS
## dw_rpt_jual_faktur1_rekap
**Date:** 2026-06-16

---

## ✅ STATUS SAAT INI

Kolom structure sudah ada:
- ✅ Unit (dengan sub-kolom Valuta | IDR)
- ✅ Spare Parts (dengan sub-kolom IDR)
- ✅ Jasa (dengan sub-kolom IDR)
- ✅ Compute fields (cunit_idr, cjasa_idr, cspare_idr) sudah ada

**HANYA perlu fix formula di display fields!**

---

## 🔧 DETAIL BAND - FIX DISPLAY FIELD FORMULAS

### 1. Unit / Valuta Display Field
**Location:** Detail band, dibawah "Unit" / "Valuta" header

**Current:** (mungkin kosong atau salah)  
**Fix to:** `gl_curr_symbol`

**Langkah:**
1. Buka DataWindow Painter
2. Click pada display field di Unit/Valuta column (detail band)
3. Right-click → Properties (atau double-click untuk edit)
4. Tab: General / Script
5. Cari **Expression** field
6. **Clear existing value**
7. **Input:** `gl_curr_symbol`
8. OK / Apply
9. Save file

---

### 2. Unit / IDR Display Field
**Location:** Detail band, dibawah "Unit" / "IDR" header

**Current:** (mungkin kosong atau formula lain)  
**Fix to:** `cunit_idr`

**Langkah:**
1. Click pada display field di Unit/IDR column (detail band)
2. Properties → Expression
3. Clear existing
4. **Input:** `cunit_idr`
5. Format: `[DBN]` (atau `#,##0.00`)
6. OK / Apply

---

### 3. Spare Parts / IDR Display Field
**Location:** Detail band, dibawah "Spare Parts" / "IDR" header

**Current:** (mungkin kosong atau formula lain)  
**Fix to:** `cspare_idr`

**Langkah:**
1. Click pada display field di Spare Parts/IDR column (detail band)
2. Properties → Expression
3. Clear existing
4. **Input:** `cspare_idr`
5. Format: `[DBN]`
6. OK / Apply

---

### 4. Jasa / IDR Display Field
**Location:** Detail band, dibawah "Jasa" / "IDR" header

**Current:** (mungkin kosong atau formula lain)  
**Fix to:** `cjasa_idr`

**Langkah:**
1. Click pada display field di Jasa/IDR column (detail band)
2. Properties → Expression
3. Clear existing
4. **Input:** `cjasa_idr`
5. Format: `[DBN]`
6. OK / Apply

---

## 🔧 GROUP HEADER BAND - FIX SUM FORMULAS

### 5. Unit / Valuta Sum (Group Header Level 1)
**Location:** Group header.1 band, dibawah "Unit" / "Valuta" header

**Current:** (mungkin kosong atau salah)  
**Fix to:** `gl_curr_symbol`

**Langkah:**
1. Click pada compute field di Unit/Valuta column (group header.1)
2. Properties → Expression
3. Clear existing
4. **Input:** `gl_curr_symbol`
5. OK / Apply

---

### 6. Unit / IDR Sum (Group Header Level 1)
**Location:** Group header.1 band, dibawah "Unit" / "IDR" header

**Current:** (mungkin kosong atau formula lain)  
**Fix to:** `sum(cunit_idr for group 1)`

**Langkah:**
1. Click pada compute field di Unit/IDR column (group header.1)
2. Properties → Expression
3. Clear existing
4. **Input:** `sum(cunit_idr for group 1)`
5. Format: `[DBN]`
6. OK / Apply

---

### 7. Spare Parts / IDR Sum (Group Header Level 1)
**Location:** Group header.1 band, dibawah "Spare Parts" / "IDR" header

**Current:** (mungkin kosong atau formula lain)  
**Fix to:** `sum(cspare_idr for group 1)`

**Langkah:**
1. Click pada compute field di Spare Parts/IDR column (group header.1)
2. Properties → Expression
3. Clear existing
4. **Input:** `sum(cspare_idr for group 1)`
5. Format: `[DBN]`
6. OK / Apply

---

### 8. Jasa / IDR Sum (Group Header Level 1)
**Location:** Group header.1 band, dibawah "Jasa" / "IDR" header

**Current:** (mungkin kosong atau formula lain)  
**Fix to:** `sum(cjasa_idr for group 1)`

**Langkah:**
1. Click pada compute field di Jasa/IDR column (group header.1)
2. Properties → Expression
3. Clear existing
4. **Input:** `sum(cjasa_idr for group 1)`
5. Format: `[DBN]`
6. OK / Apply

---

## ✅ AFTER FIXING

### Compile & Test
```
Build → Rebuild (Ctrl+Shift+B)
```

**Verify:**
- ✓ No compilation errors
- ✓ Detail rows show:
  - Unit/Valuta: Currency code (IDR, USD, etc)
  - Unit/IDR: Unit amount in IDR
  - Spare Parts/IDR: Spare amount in IDR
  - Jasa/IDR: Jasa amount in IDR
- ✓ Group header shows totals for each category
- ✓ Values calculate correctly

### Test dengan Data
```
Preview → Run Report
```

**Check:**
- ✓ Currency display correct
- ✓ Amounts calculate with exchange rate
- ✓ Group sums match detail totals
- ✓ Balance: Unit + Spare + Jasa = Total Kotor

---

## 📋 FORMULA REFERENCE CHECKLIST

| Display Field | Expression | Format | Status |
|---------------|-----------|--------|--------|
| Unit/Valuta (detail) | `gl_curr_symbol` | [general] | ☐ Fixed |
| Unit/IDR (detail) | `cunit_idr` | [DBN] | ☐ Fixed |
| Spare Parts/IDR (detail) | `cspare_idr` | [DBN] | ☐ Fixed |
| Jasa/IDR (detail) | `cjasa_idr` | [DBN] | ☐ Fixed |
| Unit/Valuta (group) | `gl_curr_symbol` | [general] | ☐ Fixed |
| Unit/IDR (group) | `sum(cunit_idr for group 1)` | [DBN] | ☐ Fixed |
| Spare Parts/IDR (group) | `sum(cspare_idr for group 1)` | [DBN] | ☐ Fixed |
| Jasa/IDR (group) | `sum(cjasa_idr for group 1)` | [DBN] | ☐ Fixed |

---

## 🎯 QUICK REFERENCE

### Detail Band Formulas
```
Unit/Valuta    = gl_curr_symbol
Unit/IDR       = cunit_idr
Spare Parts/ID = cspare_idr
Jasa/IDR       = cjasa_idr
```

### Group Header Formulas
```
Unit/Valuta    = gl_curr_symbol
Unit/IDR       = sum(cunit_idr for group 1)
Spare Parts/ID = sum(cspare_idr for group 1)
Jasa/IDR       = sum(cjasa_idr for group 1)
```

---

## ⚠️ TIPS

1. **Double-check field names** - pastikan spelling benar (cunit_idr, bukan cunit_IDR)
2. **Use proper quotes** - PowerBuilder sensitive dengan quote format
3. **Format field** - currency fields gunakan [DBN] atau #,##0.00
4. **Test immediately** - jangan tunggu semua selesai, test setelah fix masing-masing field
5. **Check grid** - lihat di grid/data area bukan hanya design area

---

## ✅ STATUS AFTER COMPLETION

Setelah semua formula di-fix dan compile berhasil:

```
Report siap dengan:
✓ 6 compute fields (hidden calculation)
✓ 8 display fields (visible di report)
✓ Unit column dengan Valuta|IDR
✓ Spare Parts column dengan IDR
✓ Jasa column dengan IDR
✓ Multi-currency support (gl_curr_symbol + exchange rate)
✓ Group sums untuk validation
✓ Balance check: Unit + Spare + Jasa = Total Kotor
```

**READY FOR TESTING!**

