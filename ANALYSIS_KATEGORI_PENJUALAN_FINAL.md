# ANALISIS FINAL: REKAP PENJUALAN BY CUSTOMER
## Dengan Data Profiling Mandatory

**Status:** READY FOR DATA PROFILING (sebelum coding)  
**Risk Level:** CRITICAL - Memerlukan validasi data sebelum implementasi  
**Priority:** HIGH

---

## BAGIAN 1: PROBLEM STATEMENT

### 1.1 Issue yang Diidentifikasi

Current formula pada analisis sebelumnya:

```powerbuilder
cspare_idr = if(group_product<>'JS' AND penjualan<>'03', kotor_asli * penjualan_kurs, 0)
```

**Problem:** 
- Ini adalah **CATCH-ALL logic**
- Mengambil SEMUA yang bukan JS dan bukan 03
- **Risiko TINGGI:** Jika ada kategori baru (ACC, OTH, FRT, EXP, dll) akan SILENT masuk ke SPAREPART
- **Tidak ada warning/error** - data akan terlihat normal tapi mungkin SALAH
- **Tidak mudah diaudit** - sulit trace mana nilai yang seharusnya kemana

### 1.2 Why This Is Dangerous

Example scenario masa depan:

```
Data baru ada:
  group_product = 'FRT'  (Freight/Pengiriman)
  penjualan = '04'
  kotor = 100 jt
  
Dengan formula catch-all:
  group_product<>'JS' AND penjualan<>'03'
  → TRUE, 100 jt masuk ke SPAREPART
  
Padahal seharusnya:
  FRT adalah kategori TERPISAH, bukan SPAREPART!
  Akibat: Report SALAH, tidak terdeteksi
```

---

## BAGIAN 2: SOLUSI: DATA PROFILING MANDATORY

### 2.1 Query Profiling yang Harus Dijalankan

**File:** `profile_kategori_penjualan.sql` (sudah disiapkan)

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

**Apa yang ditampilkan:**
- SEMUA kombinasi penjualan + group_product yang ada di database
- Jumlah transaksi per kombinasi
- Range tanggal
- Total nilai per kombinasi

### 2.2 Expected Result (Asumsi)

Jika data sesuai requirement yang sudah ditentukan:

```
penjualan | group_product | jumlah_transaksi | jumlah_invoice | total_kotor       | tgl_pertama | tgl_terakhir
----------|---------------|------------------|----------------|-------------------|-------------|---------------
01        | JS            | 245              | 65             | Rp 15.234.567.890 | 2026-01-15  | 2026-06-15
01        | SP            | 178              | 48             | Rp 8.456.789.012  | 2026-01-20  | 2026-06-10
02        | SP            | 412              | 102            | Rp 23.456.789.012 | 2026-01-10  | 2026-06-14
03        | UNIT          | 89               | 45             | Rp 45.678.901.234 | 2026-01-05  | 2026-06-12
```

**If hasil seperti di atas:** ✅ **AMAN untuk hardcode**

```
penjualan | group_product | jumlah_transaksi | jumlah_invoice | total_kotor
----------|---------------|------------------|----------------|-------------------
01        | JS            | 245              | 65             | Rp 15.234.567.890
01        | SP            | 178              | 48             | Rp 8.456.789.012
02        | SP            | 412              | 102            | Rp 23.456.789.012
03        | UNIT          | 89               | 45             | Rp 45.678.901.234
04        | FRT           | 67               | 34             | Rp 5.678.901.234   ← UNEXPECTED!
```

**If ada kategori baru:** ⚠️ **HARUS HANDLE, jangan CATCH-ALL**

---

## BAGIAN 3: FORMULA MAPPING (BASED ON ACTUAL DATA)

### 3.1 Scenario A: Data Sesuai Asumsi (HANYA JS, SP, UNIT)

Jika profiling menunjukkan kombinasi hanya:
- penjualan=01, group_product=JS
- penjualan=01, group_product=SP
- penjualan=02, group_product=SP
- penjualan=03, group_product=UNIT

**Maka formula AMAN:**

```powerbuilder
// EXPLICIT & SAFE
cunit_idr = 
  if(im_product_group_penjualan='03',
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
```

**Keuntungan:**
- ✅ Eksplisit - jelas apa yang masuk kemana
- ✅ Tidak ada catch-all
- ✅ Jika ada kategori baru, data TIDAK masuk (akan hilang, ERROR visible)
- ✅ Mudah diaudit

### 3.2 Scenario B: Data Lebih Complex (Ada kategori lain)

Jika profiling menunjukkan ada kategori seperti:
- FRT (Freight)
- ACC (Accessories)
- OTH (Other)
- EXP (Expense)

**Maka HARUS buat EXPLICIT mapping:**

```powerbuilder
cunit_idr = 
  if(im_product_group_penjualan='03',
     kotor_asli * penjualan_kurs,
     0)

cjasa_idr = 
  if(group_product='JS',
     kotor_asli * penjualan_kurs,
     0)

cspare_idr = 
  if(group_product IN ('SP', 'ACC'),  // Explicit list
     kotor_asli * penjualan_kurs,
     0)

cfreight_idr = 
  if(group_product='FRT',
     kotor_asli * penjualan_kurs,
     0)

cother_idr = 
  if(group_product IN ('OTH', 'EXP'),
     kotor_asli * penjualan_kurs,
     0)
```

**Notes:**
- Setiap kategori EXPLICIT di-define
- Ada kolom untuk kategori yang tidak expected
- Jika ada kategori BENAR-BENAR baru, akan masuk ke "other" atau ERROR
- **Dapat di-review oleh user**

---

## BAGIAN 4: VALIDATION BALANCE TEST

### 4.1 Mandatory Testing SEBELUM Deployment

**Test:** Ambil minimal 20 invoice RANDOM dari database

Untuk setiap invoice, hitung:

```
UNIT_IDR   = sum(kotor where penjualan='03')
JASA_IDR   = sum(kotor where group_product='JS')
SPAREPART  = sum(kotor where group_product='SP' and penjualan<>'03')
KOTOR_IDR  = sum(kotor where no filter)

Check: UNIT_IDR + JASA_IDR + SPAREPART = KOTOR_IDR ± 0.01
```

### 4.2 Test Case Template

```
Invoice ID: INV-2026-001234
Customer:   PT MAJU JAYA
Date:       15-Jun-2026
Currency:   IDR

Line Item Breakdown:
Seq | Penjualan | group_product | Qty | Unit Price | Kotor (IDR)
----|-----------|---------------|-----|------------|-------------
1   | 03        | UNIT          | 1   | 150.000.000| 150.000.000
2   | 01        | JS            | 10  | 2.500.000  | 25.000.000
3   | 01        | SP            | 20  | 1.750.000  | 35.000.000
4   | 02        | SP            | 15  | 3.000.000  | 45.000.000
----|-----------|---------------|-----|------------|-------------
Total Kotor:                                        255.000.000

Kategori Breakdown:
UNIT_IDR       = 150.000.000  (line 1: penjualan=03)
JASA_IDR       =  25.000.000  (line 2: group_product=JS)
SPAREPART_IDR  =  80.000.000  (line 3+4: group_product=SP)
KOTOR_IDR      = 255.000.000  (all lines)

Balance Check:
150 + 25 + 80 = 255 ✓ BALANCE

Result: PASS
```

### 4.3 Invalid Invoice Example

```
Invoice ID: INV-2026-005678
Customer:   PT UNKNOWN
Date:       10-Jun-2026

Kategori Breakdown:
UNIT_IDR       = 100.000.000
JASA_IDR       =  50.000.000
SPAREPART_IDR  =  60.000.000
KOTOR_IDR      = 180.000.000

Balance Check:
100 + 50 + 60 = 210 ≠ 180 ✗ NOT BALANCE

Investigation:
→ Ada data yang tidak ter-capture
→ Cek apakah ada kategori/group_product yang tidak di-filter
→ Cek apakah ada exchange rate issue
→ Cek apakah ada data corruption

Result: FAIL - DEBUG DIPERLUKAN
```

---

## BAGIAN 5: MINIMUM VALIDATION CHECKLIST

Sebelum coding dimulai, HARUS sudah:

### 5.1 Data Profiling

- [ ] Query `profile_kategori_penjualan.sql` sudah di-run
- [ ] Hasil profiling dokumentasikan:
  - [ ] Semua kombinasi penjualan + group_product yang ada
  - [ ] Jumlah transaksi per kombinasi
  - [ ] Total nilai per kombinasi
  - [ ] Tidak ada NULL values di penjualan atau group_product
- [ ] Kesimpulan: Apakah ada kategori unexpected?

### 5.2 Category Definition

- [ ] Tentukan EXPLICIT list semua kategori yang ada di database
- [ ] Buat mapping table:
  ```
  penjualan | group_product | category_name   | is_reported
  ----------|---------------|-----------------|------------
  01        | JS            | JASA            | Y
  01        | SP            | SPARE PARTS     | Y
  02        | SP            | SPARE PARTS     | Y
  03        | UNIT          | UNIT            | Y
  [any_other]| [any_other]  | [define]        | Y/N
  ```

### 5.3 Balance Validation

- [ ] Pilih 20 invoice RANDOM dari data sebelum/sesudah periode
- [ ] Untuk SETIAP invoice, hitung UNIT + JASA + SPARE = KOTOR
- [ ] Dokumentasikan hasil:
  - [ ] Berapa invoice yang balance? (target: 100%)
  - [ ] Jika ada yang tidak balance, apakah reason-nya jelas?
  - [ ] Ada kategori yang tidak ter-capture?

### 5.4 Formula Definition

- [ ] Buat EXPLICIT formula untuk setiap kategori yang ditemukan
- [ ] Hindari catch-all logic (group_product<>'JS' AND penjualan<>'03')
- [ ] Dokumentasikan logika dengan contoh untuk setiap kategori

### 5.5 Approval

- [ ] Profiling results review oleh business/accounting
- [ ] Formula approval: "Ini benar ya, yang masuk UNIT, JASA, SPARE?"
- [ ] Lanjut ke coding hanya setelah approval

---

## BAGIAN 6: REKOMENDASI FINAL

### 6.1 Jika Data Simple (Scenario A: Hanya JS, SP, UNIT)

**Formula Safe yang direkomendasikan:**

```powerbuilder
// DETAIL BAND

// UNIT: Hanya penjualan=03
cunit_valuta = 
  if(im_product_group_penjualan='03' AND penjualan_curr_id<>'IDR',
     kotor_asli,
     0)

cunit_idr = 
  if(im_product_group_penjualan='03',
     kotor_asli * penjualan_kurs,
     0)

// JASA: Hanya group_product=JS
cjasa_idr = 
  if(group_product='JS',
     kotor_asli * penjualan_kurs,
     0)

// SPARE PARTS: Hanya group_product=SP
cspare_idr = 
  if(group_product='SP',
     kotor_asli * penjualan_kurs,
     0)

// KOTOR: Semua transaksi
ckotor_valuta = 
  if(penjualan_curr_id<>'IDR',
     kotor_asli,
     0)

ckotor_idr_total = 
  kotor_asli * penjualan_kurs

// GROUP HEADER

// UNIT
compute_unit_valuta = sum(cunit_valuta for group 1)
compute_unit_idr = sum(cunit_idr for group 1)

// JASA
compute_jasa_idr = sum(cjasa_idr for group 1)

// SPARE PARTS
compute_spare_idr = sum(cspare_idr for group 1)

// KOTOR
compute_kotor_valuta = sum(ckotor_valuta for group 1)
compute_kotor_idr = sum(ckotor_idr_total for group 1)
```

**Validation Formula (harus TRUE di setiap group):**

```
compute_unit_idr + compute_jasa_idr + compute_spare_idr = compute_kotor_idr
```

### 6.2 Jika Data Complex (Scenario B: Ada kategori lain)

Tidak boleh langsung code - harus:
1. Identifikasi SEMUA kategori dengan jelas
2. Tanya ke business: "Kategori X itu sebaiknya masuk kemana?"
3. Buat formula EXPLICIT untuk tiap kategori
4. Mungkin perlu tambah kolom di report

---

## BAGIAN 7: ACTION ITEMS (BEFORE CODING)

**HARUS DIKERJAKAN (dalam urutan ini):**

### 7.1 (Day 1) Data Profiling

```
1. Execute: profile_kategori_penjualan.sql
2. Export hasil ke CSV: profiling_hasil_2026_06_15.csv
3. Review hasil
4. Document findings
```

### 7.2 (Day 1-2) Mapping Review

```
1. Buat tabel mapping berdasarkan profiling:
   
   penjualan | group_product | proposed_category
   ----------|---------------|-------------------
   01        | JS            | JASA
   01        | SP            | SPARE_PARTS
   02        | SP            | SPARE_PARTS
   03        | UNIT          | UNIT
   [others]  | [others]      | [define]

2. Review dengan user/accounting
3. Dapatkan approval
4. Document decision
```

### 7.3 (Day 2) Balance Validation

```
1. Pilih 20 invoice sample
2. Manual calculate untuk setiap invoice:
   UNIT + JASA + SPARE = KOTOR?
3. Document hasil
4. Jika ada mismatch, investigate reason
5. Siapkan dokumentasi untuk auditor
```

### 7.4 (Day 3) Formula Build

```
1. Buat formula explicit berdasarkan approved mapping
2. Unit test di PowerBuilder
3. Test dengan 5 sample invoices (small, medium, large)
4. Verify no errors
```

### 7.5 (Day 3-4) QA Testing

```
1. Compile datawindow
2. Test report dengan 20 sample invoices
3. Verify balance untuk SETIAP invoice
4. Check Excel export
5. Check print preview
6. Sign-off QA
```

---

## KESIMPULAN

**TIDAK BOLEH LANGSUNG CODING.** 

Sebelum implementasi, WAJIB:

1. ✅ Data profiling selesai → tahu semua kategori yang ada
2. ✅ Mapping approval dari business → tahu data sesuai dengan requirement
3. ✅ Balance validation selesai → tahu formula akan produce angka yang benar
4. ✅ Explicit formula build → hindari catch-all yang dangerous

**Hanya setelah 4 item di atas selesai**, baru coding dimulai.

---

**Next Step:** User menjalankan query profiling dan share hasil-nya di sini.

