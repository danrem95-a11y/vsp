# 📥 PANDUAN IMPORT DATAWINDOW (.SRD)
## dw_rpt_jual_faktur1_rekap_NEW.srd
**PowerBuilder 11.5 / Sybase SQL Anywhere 9**  
**Tanggal:** 2026-06-16

---

## 📋 FILE INFO

**File:** `dw_rpt_jual_faktur1_rekap_NEW.srd`  
**Lokasi:** `c:\BTV\debug\dw_rpt_jual_faktur1_rekap_NEW.srd`  
**Ukuran:** 220 KB  
**Format:** DataWindow (PowerBuilder)  
**Encoding:** UTF-16 LE  

---

## ✨ APA YANG BARU

### 6 Compute Fields Ditambahkan:

**Detail Band (3 fields):**
1. ✅ **cunit_idr** — Revenue UNIT (IDR)
   - Formula: `if(group_produk IN ('TR','TB','TYU','FU','BCS','FUS','OB','NR','BX'), kotor_asli * penjualan_kurs, 0)`

2. ✅ **cjasa_idr** — Revenue JASA (IDR)
   - Formula: `if(group_produk IN ('JS01','JS02','JS03','JS04','JS05','JS06','JS07'), kotor_asli * penjualan_kurs, 0)`

3. ✅ **cspare_idr** — Revenue SPARE PARTS (IDR)
   - Formula: `if(group_produk IN ('TS','TL','NDS','LA','FS','OS','FP','CS','TSA','FL','L','MT'), kotor_asli * penjualan_kurs, 0)`

**Group Header Band (3 fields):**
4. ✅ **c_sum_unit_idr** = `sum(cunit_idr for group 1)`
5. ✅ **c_sum_jasa_idr** = `sum(cjasa_idr for group 1)`
6. ✅ **c_sum_spare_idr** = `sum(cspare_idr for group 1)`

**Catatan:** Tidak ada formula lama yang diubah (additive only)

---

## 🚀 LANGKAH-LANGKAH IMPORT

### Step 1: Backup File Original

**PENTING!** Buat backup sebelum import:

```
Lokasi: C:\BTV\debug\
File Original: dw_rpt_jual_faktur1_rekap.srd

Caranya:
1. Buka Windows Explorer
2. Ke folder: C:\BTV\debug\
3. Klik kanan: dw_rpt_jual_faktur1_rekap.srd
4. Copy
5. Paste di folder yang sama
6. Rename ke: dw_rpt_jual_faktur1_rekap_BACKUP_20260616.srd
```

**Status:** ✅ Backup siap untuk rollback jika ada masalah

---

### Step 2: Buka PowerBuilder 11.5

```
1. Launch PowerBuilder 11.5
2. Open project yang berisi dw_rpt_jual_faktur1_rekap
3. Tunggu sampai fully loaded
```

---

### Step 3: Import SRD File

**METODE A: Via File Menu (Recommended)**

```
Menu: File → Open
1. Dialog terbuka
2. Navigate ke: C:\BTV\debug\
3. Cari file: dw_rpt_jual_faktur1_rekap_NEW.srd
4. Click: Open
```

PowerBuilder akan otomatis recognize file format dan import ke project.

**METODE B: Via Replace/Update**

```
Di Object Browser:
1. Klik kanan: dw_rpt_jual_faktur1_rekap (existing)
2. Pilih: "Import from File" atau "Replace"
3. Locate: C:\BTV\debug\dw_rpt_jual_faktur1_rekap_NEW.srd
4. Click: OK
```

**METODE C: Drag & Drop**

```
1. Buka Windows Explorer ke: C:\BTV\debug\
2. Cari: dw_rpt_jual_faktur1_rekap_NEW.srd
3. Drag file ke PowerBuilder Object Browser
4. Drop ke project tree
```

---

### Step 4: Verifikasi Import Berhasil

Setelah import, verifikasi 6 fields ada:

**Di PowerBuilder DataWindow Painter:**

```
1. Buka: dw_rpt_jual_faktur1_rekap (baru di-import)
2. Tab: Definition
3. Scroll down cari compute fields baru:

Detail Band:
   ✅ cunit_idr
   ✅ cjasa_idr  
   ✅ cspare_idr

Group Header:
   ✅ c_sum_unit_idr
   ✅ c_sum_jasa_idr
   ✅ c_sum_spare_idr

4. Periksa: No red error icons
5. Periksa: Script tab no errors
```

---

### Step 5: Compile & Test

```
1. Build → Rebuild (atau Ctrl+Shift+B)

2. Check error window:
   - No syntax errors
   - No undefined references
   - No database connection issues

3. Test dengan data:
   - Preview report dengan test data
   - Lihat compute fields calculate (bukan NULL/error)
   - Verifikasi values masuk akal
```

---

## ✅ CHECKLIST VERIFIKASI

Setelah import, check:

- [ ] File terbuka tanpa error
- [ ] Semua 6 compute fields terlihat di Definition
- [ ] No red error icons
- [ ] Compile tanpa error (Build → Rebuild)
- [ ] Preview shows data
- [ ] New fields calculate correctly
- [ ] No performance issues
- [ ] Original fields unchanged

**Jika semua ✅:** Import SUKSES → Lanjut ke QA testing

**Jika ada ❌:** Investigate error → Rollback jika perlu

---

## 🔧 TROUBLESHOOTING

### Error 1: "File not found"
```
Fix:
- Pastikan file ada: C:\BTV\debug\dw_rpt_jual_faktur1_rekap_NEW.srd
- Cek nama file (case-sensitive di beberapa OS)
- Coba copy file ke path lebih simple
```

### Error 2: "Invalid DataWindow format"
```
Fix:
- Verifikasi file size ≈ 220 KB
- Cek file tidak corrupted
- Coba gunakan refactored.txt instead
- Re-copy file jika perlu
```

### Error 3: Compile Error setelah import
```
Fix:
- Check database connection (DSN vsp)
- Verifikasi SQL Anywhere 9 connection
- Check table/column references valid
- Cek specific error di error window
```

### Error 4: Compute fields show NULL/Error
```
Fix:
- Check group_product field ada di data
- Verify kotor_asli dan penjualan_kurs tersedia
- Pastikan exchange rate data populated
- Test query terlebih dahulu
- Review formula syntax di Definition tab
```

### Error 5: Performance issues
```
Fix:
- 6 fields = negligible impact
- Check database connection speed
- Verify query performance
- Monitor CPU/memory
```

---

## 📝 LANGKAH SETELAH IMPORT SUKSES

### 1. Save Changes
```
File → Save (atau Ctrl+S)
```

### 2. Publish ke Test Environment
```
1. Rebuild application
2. Deploy ke test server  
3. Serahkan ke QA team
4. Execute 7 test cases (lihat ARTEFACT_3)
```

### 3. Document Changes
```
Update changelog:
- Tanggal: 2026-06-16
- Component: dw_rpt_jual_faktur1_rekap
- Changes: Added 6 compute fields untuk category breakdown
- Impact: Additive, no existing formula changes
- Testing: 7 test cases (QA in progress)
```

---

## 📊 EXPECTED DATA BREAKDOWN

Setelah import, report harus show:

```
Category      | Expected Revenue | % of Total
--------------+------------------+-----------
UNIT          | ~895 Billion IDR  | 92.5%
JASA          | ~4.9 Billion IDR  | 0.5%
SPARE PARTS   | ~69 Billion IDR   | 7.0%
--------------+------------------+-----------
TOTAL         | ~969 Billion IDR  | 100%
```

**Balance Check:** 
```
c_sum_unit_idr + c_sum_jasa_idr + c_sum_spare_idr = sum(ckotor_idr)
```

---

## ⏱️ ESTIMASI WAKTU

| Aktivitas | Waktu |
|-----------|-------|
| Backup | 2 min |
| Import | 2 min |
| Verifikasi | 5 min |
| Compile | 2 min |
| Test | 5 min |
| **Total** | **~16 min** |

---

## 🚨 JIKA PERLU ROLLBACK

Jika ada masalah serius:

```
1. Close dw_rpt_jual_faktur1_rekap yang problematic
2. Delete imported file dari project
3. Restore dari backup: dw_rpt_jual_faktur1_rekap_BACKUP_20260616.srd
4. Rename kembali ke: dw_rpt_jual_faktur1_rekap.srd
5. Rebuild project
6. Test dengan original version
```

**Rollback Time:** < 5 minutes

---

## ✅ FINAL STATUS

```
File: C:\BTV\debug\dw_rpt_jual_faktur1_rekap_NEW.srd
Format: DataWindow (.srd) untuk PowerBuilder 11.5
Encoding: UTF-16 LE
Size: 220 KB
Status: ✅ SIAP UNTUK IMPORT
```

**Langkah Berikutnya:** Follow Step 1-5 di atas, mulai dari Backup.

---

**Pertanyaan?** Contact: kimtechgurning@gmail.com

