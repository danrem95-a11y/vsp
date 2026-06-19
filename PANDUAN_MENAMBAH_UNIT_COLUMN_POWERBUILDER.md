# PANDUAN: MENAMBAH UNIT COLUMN (VALUTA|IDR) DI POWERBUILDER 11.5
## dw_rpt_jual_faktur1_rekap
**Date:** 2026-06-16

---

## ✅ STATUS FILE

**File:** `dw_rpt_jual_faktur1_rekap_FINAL.srd`
- ✅ Sudah berisi 6 compute fields (cunit_idr, cjasa_idr, cspare_idr, c_sum_unit_idr, c_sum_jasa_idr, c_sum_spare_idr)
- ✅ Formula sesuai ARTEFACT_2
- ✅ Ready untuk import

---

## 📋 LANGKAH-LANGKAH MENAMBAH UNIT COLUMN DI POWERBUILDER

### Step 1: Import file ke PowerBuilder
```
File → Open → dw_rpt_jual_faktur1_rekap_FINAL.srd
```

### Step 2: Buka DataWindow Painter
```
Double-click pada dw_rpt_jual_faktur1_rekap di Object Browser
→ Switch to Design mode
```

### Step 3: Shift Kotor Column ke Kanan (agar ada space untuk Unit)

**Di Header section (y=288):**
1. Click pada "Kotor" text header
2. Right-click → Properties
3. Change X coordinate dari 2510 ke **3300** (shift 790px ke kanan)
4. Apply

**Di Sub-header section (y=356):**
1. Click pada "Valuta" sub-header (under Kotor)
2. Properties → Change X dari 2510 ke **3300**
3. Apply
4. Click pada "IDR" sub-header
5. Properties → Change X dari 2848 ke **3638**
6. Apply

Lakukan hal sama untuk semua kolom SETELAH Kotor (Potongan, Bersih, PPN, Grand Total, Lain-lain, dll) - shift semua +790px ke kanan.

### Step 4: Insert Unit Header (Main)

**Di Header band (y=288):**
1. Click pada Text tool dari toolbar
2. Click di posisi X=2510 (tempat Kotor lama)
3. Draw text box dengan:
   - X = 2510
   - Y = 288
   - Width = 827
   - Height = 64
4. Set properties:
   - Text = "Unit"
   - Font = Tahoma, -10pt, Bold
   - Border = 2
   - Background = gray (same as other headers)
   - Name = `unit_header`

### Step 5: Insert Unit Sub-headers

**Valuta sub-header (y=356):**
1. Insert Text box:
   - X = 2510
   - Y = 356
   - Width = 400
   - Height = 64
2. Properties:
   - Text = "Valuta"
   - Font = Tahoma, -10pt
   - Border = 2
   - Name = `unit_valuta_subheader`

**IDR sub-header (y=356):**
1. Insert Text box:
   - X = 2910 (2510 + 400)
   - Y = 356
   - Width = 417
   - Height = 64
2. Properties:
   - Text = "IDR"
   - Font = Tahoma, -10pt
   - Border = 2
   - Name = `unit_idr_subheader`

### Step 6: Insert Display Fields di Detail Band

**Valuta display field:**
1. Click pada Compute tool (atau Insert → Compute)
2. Click di detail band area at X=2510, Y=96
3. Properties:
   - Expression = `gl_curr_symbol` (untuk menampilkan currency code)
   - X = 2510
   - Y = 96 (atau 4 - depends on your detail band height)
   - Width = 400
   - Height = 64
   - Format = [general]
   - Name = `d_unit_currency`
   - Border = 1

**IDR display field:**
1. Insert Compute:
   - Expression = `cunit_idr`
   - X = 2910
   - Y = 96
   - Width = 417
   - Height = 64
   - Format = [DBN]
   - Name = `d_unit_idr`
   - Border = 1

### Step 7: Insert Group Header Sums

**Unit Currency sum (Group Header level 1):**
1. Insert Compute at group header.1:
   - Expression = `gl_curr_symbol`
   - X = 2510
   - Y = 12
   - Width = 400
   - Height = 64
   - Name = `g_unit_currency`

**Unit IDR sum (Group Header level 1):**
1. Insert Compute:
   - Expression = `sum(cunit_idr for group 1)`
   - X = 2910
   - Y = 12
   - Width = 417
   - Height = 64
   - Format = [DBN]
   - Name = `g_sum_unit_idr`

### Step 8: Compile & Test

```
Build → Rebuild (Ctrl+Shift+B)
```

**Verify:**
- ✓ No compilation errors
- ✓ Unit column tampil dengan 2 sub-columns (Valuta | IDR)
- ✓ Detail rows show currency code and unit amount in IDR
- ✓ Group header shows total unit amount
- ✓ Kotor column tidak tertimpa dan shifted ke kanan

### Step 9: Test dengan Data

```
Preview → Run Report dengan sample data
```

**Check:**
- ✓ Unit/Valuta shows currency (IDR, USD, dll)
- ✓ Unit/IDR shows converted amount
- ✓ Values calculate correctly (kotor_asli * exchange rate)
- ✓ Group sums match detail line totals

### Step 10: Save

```
File → Save (Ctrl+S)
```

---

## ⚡ TIPS POSITIONING

Jika kesulitan positioning, gunakan Grid:
```
View → Show Grid (untuk melihat pixel grid)
```

Atau gunakan Snap to Grid untuk alignment otomatis:
```
View → Snap to Grid (on/off)
```

---

## ✅ FINAL CHECKLIST

- [ ] File imported tanpa error
- [ ] Kotor column shifted ke kanan
- [ ] Unit column header ada
- [ ] Unit sub-headers (Valuta|IDR) ada
- [ ] Detail display fields ada dan calculate
- [ ] Group header sums ada
- [ ] Compile successful
- [ ] Preview menampilkan data dengan benar
- [ ] File saved

---

## 📞 JIKA ADA MASALAH

1. **Syntax error** → Check formula di Expression field (gunakan quotes yang benar)
2. **Kolom overlap** → Adjust width dan X coordinates
3. **Data tidak tampil** → Verify field names sesuai dengan compute fields yang ada
4. **Format salah** → Check Format field ([DBN] untuk currency, [general] untuk text)

---

**Status:** ✅ READY TO IMPLEMENT

Gunakan panduan ini untuk menambahkan Unit column secara manual di PowerBuilder DataWindow Painter.

