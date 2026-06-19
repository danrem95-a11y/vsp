# INSTRUKSI: DATA PROFILING PENJUALAN BY CATEGORY
## (Mandatory sebelum coding Report Rekap Penjualan)

**File Analysis:** `ANALYSIS_KATEGORI_PENJUALAN_FINAL.md` (untuk detail lengkap)

---

## TL;DR (Yang Harus Dilakukan)

### Problem
Saya proposed formula dengan catch-all logic:
```
group_product<>'JS' AND penjualan<>'03'  ← DANGEROUS!
```

User benar: ini akan **silent mengambil kategori baru** yang tidak expect.

### Solusi
**PROFILING DATA DULU** untuk tahu kombinasi APA SAJA yang ada.

---

## STEP 1: Run This Query

**File:** `profile_kategori_penjualan.sql` (sudah di-create)

Jalankan query ini di database (SQL Anywhere/DBISAM):

```sql
SELECT
    im_product_group.penjualan,
    im_produk.group_product,
    COUNT(*) as jumlah_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jumlah_invoice,
    SUM(tsales2.kotor) as total_kotor,
    MIN(tsales1.tgl) as tgl_pertama,
    MAX(tsales1.tgl) as tgl_terakhir
FROM
    tsales2
    JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
    JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
    JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE
    tsales1.tgl >= DATE('2026-01-01')
    AND tsales1.tipe_trans <> '33'
    AND ISNULL(tsales2.qty, 0) <> 0
GROUP BY
    im_product_group.penjualan,
    im_produk.group_product
ORDER BY
    im_product_group.penjualan,
    im_produk.group_product;
```

---

## STEP 2: Expected Result Format

Hasil query akan terlihat seperti:

```
penjualan | group_product | jumlah_transaksi | jumlah_invoice | total_kotor
----------|---------------|------------------|----------------|-------------------
01        | JS            | 245              | 65             | 15234567890
01        | SP            | 178              | 48             | 8456789012
02        | SP            | 412              | 102            | 23456789012
03        | UNIT          | 89               | 45             | 45678901234
```

**Copy-paste hasil ini ke sini untuk kami analisis.**

---

## STEP 3: Key Questions to Answer

Dari hasil profiling, pastikan:

1. **Kombinasi apa saja yang ada?**
   - Hanya JS, SP, UNIT? ✅ AMAN
   - Ada kategori lain (FRT, ACC, OTH, EXP)? ⚠️ PERLU HANDLE

2. **Apakah NULL values?**
   - penjualan NULL atau blank? → data quality issue
   - group_product NULL atau blank? → data quality issue

3. **Berapa banyak data per kategori?**
   - Ada kategori yang sangat kecil (< 5 transaksi)? → mungkin exception/error

4. **Apakah ada kombinasi unexpected?**
   - Contoh: penjualan='03' dengan group_product='JS'? → unusual
   - Contoh: penjualan='01' dengan group_product='UNIT'? → unusual

---

## STEP 4: After Profiling - What We'll Do

Once hasil profiling di-share:

### If Data Simple (JS, SP, UNIT only)
```
Formula: EXPLICIT & SAFE

cunit_idr = if(penjualan='03', kotor * kurs, 0)
cjasa_idr = if(group_product='JS', kotor * kurs, 0)
cspare_idr = if(group_product='SP', kotor * kurs, 0)
ckotor_idr = kotor * kurs

Validation: UNIT + JASA + SPARE = KOTOR (20 test invoices)
```

✅ **Langsung ke coding**

### If Data Complex (ada kategori lain)
```
Action items:
1. Identifikasi semua kategori
2. Tanya business: "Kategori X sebaiknya masuk kemana?"
3. Buat formula explicit untuk tiap kategori
4. Mungkin perlu tambah kolom di report
```

⚠️ **Butuh discussion lebih lanjut sebelum coding**

---

## STEP 5: Validation After Coding

Setelah formula siap, WAJIB test:

```
For 20 random invoices:
  UNIT_IDR + JASA_IDR + SPAREPART_IDR = KOTOR_IDR ± 0.01
  
Jika semua 20 invoice BALANCE → OK untuk deploy
Jika ada yang tidak BALANCE → ada bug → debug
```

---

## FILE SUMMARY

| File | Purpose |
|------|---------|
| `profile_kategori_penjualan.sql` | Query untuk profiling |
| `ANALYSIS_KATEGORI_PENJUALAN_FINAL.md` | Detailed analysis & full action plan |
| `DATA_PROFILING_INSTRUCTION.md` | Ini file - TL;DR version |

---

## Next Action

**User:**
1. Execute `profile_kategori_penjualan.sql` di database
2. Share hasil query di sini
3. Kami akan analyze dan determine formula yang tepat

**Claude:**
Akan create final formula & coding plan setelah hasil profiling diterima.

