# FINAL VALIDATION PROTOCOL
## Data-Driven Proof Before Implementation

**Status:** CRITICAL - Harus 100% proven sebelum coding  
**Target:** Membuktikan atau membantah teori mapping  
**Timeline:** 2-3 jam kerja

---

## POTENSI KONTRADIKSI YANG HARUS DIBUKTIKAN

### Theory vs Data

**Theory (dari analisis sebelumnya):**
```
penjualan=01 → bisa JS, bisa SP
penjualan=02 → selalu SP
penjualan=03 → selalu UNIT
```

**Reality check (HARUS DIBUKTIKAN):**
```
Apakah benar?
Atau ada kombinasi lain?
Atau ada satu kode yang ALWAYS menjadi satu kategori?
```

---

## QUERY SET 1: DETAIL EXAMINATION

### Query 1.1: Lihat Semua Data Kode 01 (Top 100 recent)

```sql
SELECT TOP 100
       tsales1.bukti_id,
       tsales1.tgl,
       tsales1.cust_id,
       mcust.cust_name,
       im_product_group.penjualan,
       im_produk.group_product,
       tsales2.stok_id,
       im_produk.nama_produk,
       tsales2.qty,
       tsales2.kotor
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE im_product_group.penjualan = '01'
  AND tsales1.tgl >= DATE('2026-01-01')
ORDER BY tsales1.tgl DESC;
```

**Output Analysis:**
- Lihat kolom: `penjualan` (seharusnya semua '01') dan `group_product` (apa saja?)
- **Expected:** Banyak baris dengan penjualan=01 tapi group_product berisi MIX dari JS dan SP
- **If found:** Pembuktian bahwa 01 ≠ kategori, hanya tipe penjualan

---

### Query 1.2: Lihat Semua Data Kode 02 (Top 100)

```sql
SELECT TOP 100
       tsales1.bukti_id,
       tsales1.tgl,
       tsales1.cust_id,
       mcust.cust_name,
       im_product_group.penjualan,
       im_produk.group_product,
       tsales2.stok_id,
       im_produk.nama_produk,
       tsales2.qty,
       tsales2.kotor
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE im_product_group.penjualan = '02'
  AND tsales1.tgl >= DATE('2026-01-01')
ORDER BY tsales1.tgl DESC;
```

**Output Analysis:**
- Lihat kolom: `penjualan` (seharusnya semua '02') dan `group_product` (apa saja?)
- **Expected:** Semua baris dengan group_product='SP'
- **If different:** Ada kategori lain untuk kode 02

---

### Query 1.3: Lihat Semua Data Kode 03 (Top 100)

```sql
SELECT TOP 100
       tsales1.bukti_id,
       tsales1.tgl,
       tsales1.cust_id,
       mcust.cust_name,
       im_product_group.penjualan,
       im_produk.group_product,
       tsales2.stok_id,
       im_produk.nama_produk,
       tsales2.qty,
       tsales2.kotar
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE im_product_group.penjualan = '03'
  AND tsales1.tgl >= DATE('2026-01-01')
ORDER BY tsales1.tgl DESC;
```

**Output Analysis:**
- Lihat kolom: `penjualan` (seharusnya semua '03') dan `group_product` (apa?)
- **Expected:** Semua baris dengan group_product='UNIT'
- **If different:** Ada issue

---

## QUERY SET 2: COMPREHENSIVE MAPPING TABLE

### Query 2.1: Aggregation Summary (seperti sebelumnya)

```sql
SELECT
    im_product_group.penjualan,
    im_produk.group_product,
    COUNT(*) as jml_transaksi,
    COUNT(DISTINCT tsales1.bukti_id) as jml_invoice,
    SUM(tsales2.kotor) as total_kotor
FROM tsales2
JOIN tsales1 ON tsales2.bukti_id = tsales1.bukti_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tgl >= DATE('2026-01-01')
  AND tsales1.tipe_trans <> '33'
  AND ISNULL(tsales2.qty, 0) <> 0
GROUP BY
    im_product_group.penjualan,
    im_produk.group_product
ORDER BY
    im_product_group.penjualan,
    im_produk.group_product;
```

**Expected Output:**
```
penjualan | group_product | jml_transaksi | jml_invoice | total_kotor
----------|---------------|---------------|-------------|-------------------
01        | JS            | 245           | 65          | 15234567890
01        | SP            | 178           | 48          | 8456789012
02        | SP            | 412           | 102         | 23456789012
03        | UNIT          | 89            | 45          | 45678901234
```

**Proof:**
- Jika ada 01 dengan BOTH JS dan SP → **PROOF bahwa 01 bukan kategori**
- Jika hanya ada kombinasi di atas → **PROOF bahwa mapping adalah fixed dan eksplisit**

---

## QUERY SET 3: BALANCE VALIDATION (CRITICAL!)

### Query 3.1: Sample Invoice 1 - Kode 01 Only

Pilih 1 invoice dengan HANYA kode 01 (dari query 1.1 results).

**Manual calculation:**

```
Contoh: Invoice INV-2026-001 dari query results

Line Items:
Seq | penjualan | group_product | qty | kotor
----|-----------|---------------|-----|----------
1   | 01        | JS            | 10  | 30.000.000
2   | 01        | SP            | 5   | 20.000.000
----|-----------|---------------|-----|----------
Total Kotor:                           50.000.000

Category Breakdown:
UNIT_IDR      = 0 (tidak ada kode 03)
JASA_IDR      = 30.000.000 (group_product=JS)
SPAREPART_IDR = 20.000.000 (group_product=SP)
KOTOR_IDR     = 50.000.000

Balance Check:
0 + 30.000.000 + 20.000.000 = 50.000.000 ✓ BALANCE

Result: PASS
```

**Document:** Catat invoice ID, tanggal, jumlah, dan hasil balance

---

### Query 3.2: Sample Invoice 2 - Kode 02 Only

Pilih 1 invoice dengan HANYA kode 02.

```
Expected:
UNIT_IDR      = 0
JASA_IDR      = 0
SPAREPART_IDR = [total kode 02]
KOTOR_IDR     = [total kode 02]

Balance: 0 + 0 + X = X ✓ (should always balance)
```

---

### Query 3.3: Sample Invoice 3 - Kode 03 Only

Pilih 1 invoice dengan HANYA kode 03.

```
Expected:
UNIT_IDR      = [total kode 03]
JASA_IDR      = 0
SPAREPART_IDR = 0
KOTOR_IDR     = [total kode 03]

Balance: X + 0 + 0 = X ✓ (should always balance)
```

---

### Query 3.4: Sample Invoice 4 - Kode 01+02+03 Mixed

Pilih 1 invoice dengan semua kode tercampur.

```
Expected:
UNIT_IDR      = sum(kotor where penjualan=03)
JASA_IDR      = sum(kotor where group_product=JS)
SPAREPART_IDR = sum(kotor where group_product=SP)
KOTOR_IDR     = sum(kotor where no filter)

Balance: UNIT + JASA + SPARE = KOTOR
```

---

### Query 3.5: Bulk Validation - 40 Sample Invoices

Create view/query untuk calculate semua kategori untuk 40 invoice random:

```sql
SELECT
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name,
    SUM(CASE WHEN im_product_group.penjualan='03' 
            THEN tsales2.kotor ELSE 0 END) as unit_idr,
    SUM(CASE WHEN im_produk.group_product='JS' 
            THEN tsales2.kotor ELSE 0 END) as jasa_idr,
    SUM(CASE WHEN im_produk.group_product='SP' 
            THEN tsales2.kotor ELSE 0 END) as spare_idr,
    SUM(tsales2.kotor) as kotor_idr,
    -- Balance check
    (SUM(CASE WHEN im_product_group.penjualan='03' 
             THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product='JS' 
             THEN tsales2.kotor ELSE 0 END) +
     SUM(CASE WHEN im_produk.group_product='SP' 
             THEN tsales2.kotor ELSE 0 END)) as sum_kategori,
    -- Flag untuk cek
    CASE 
        WHEN (SUM(CASE WHEN im_product_group.penjualan='03' 
                       THEN tsales2.kotor ELSE 0 END) +
              SUM(CASE WHEN im_produk.group_product='JS' 
                       THEN tsales2.kotor ELSE 0 END) +
              SUM(CASE WHEN im_produk.group_product='SP' 
                       THEN tsales2.kotor ELSE 0 END)) 
             = SUM(tsales2.kotor) 
        THEN 'BALANCE' 
        ELSE 'NOT BALANCE' 
    END as status_balance
FROM tsales1
JOIN tsales2 ON tsales1.bukti_id = tsales2.bukti_id
JOIN mcust ON tsales1.cust_id = mcust.cust_id
JOIN im_produk ON tsales2.stok_id = im_produk.produk_id
JOIN im_product_group ON im_produk.group_product = im_product_group.kode_group
WHERE tsales1.tgl >= DATE('2026-04-01')
  AND tsales1.tgl <= DATE('2026-06-15')
  AND tsales1.tipe_trans <> '33'
GROUP BY
    tsales1.bukti_id,
    tsales1.tgl,
    mcust.cust_name
ORDER BY
    tsales1.tgl DESC
```

**Critical Output:**
- **status_balance column:** HARUS SEMUA 'BALANCE'
- **Jika ada 'NOT BALANCE':** ❌ FORMULA BELUM BOLEH DI-DEPLOY
  - Investigasi: kategori apa yang missing?
  - Apakah ada group_product selain JS dan SP?

---

## HASIL YANG DIHARAPKAN

### Skenario A: IDEAL (Paling Aman untuk Coding)

```
Query Results:
✓ Kode 01 hadir dengan BOTH JS dan SP (multiple group_product)
✓ Kode 02 hadir HANYA dengan SP
✓ Kode 03 hadir HANYA dengan UNIT
✓ SEMUA 40 invoice BALANCE dengan formula:
  UNIT_IDR = penjualan=03
  JASA_IDR = group_product=JS
  SPARE_IDR = group_product=SP
  KOTOR_IDR = all

Kesimpulan:
✅ TEORI TERBUKTI
✅ SIAP CODING dengan formula eksplisit:
   if(penjualan='03', kotor*kurs, 0)
   if(group_product='JS', kotor*kurs, 0)
   if(group_product='SP', kotor*kurs, 0)
```

### Skenario B: ADA KATEGORI LAIN

```
Query Results:
⚠️ Ada group_product selain JS dan SP (misalnya: FRT, ACC, OTH)
⚠️ Ada kombinasi unexpected (misalnya: kode 02 dengan group_product != SP)
⚠️ Ada invoice yang NOT BALANCE

Kesimpulan:
❌ TIDAK BOLEH LANGSUNG CODING
✓ BUTUH DISKUSI LEBIH LANJUT
  - Identifikasi SEMUA kategori
  - Tanya business: "Kategori ini masuk kemana?"
  - Update formula untuk cover semua kategori
  - Re-validate balance
```

### Skenario C: DATA QUALITY ISSUE

```
Query Results:
🔴 Ada NULL di group_product atau penjualan
🔴 Ada anomali (kotor=0 atau negative)
🔴 Ada invoice dengan duplicate lines

Kesimpulan:
❌ DATA HARUS DIPERBAIKI DULU
✓ BUKAN MASALAH FORMULA
```

---

## DOKUMENTASI HASIL

### Spreadsheet Template (Excel/CSV)

| Nomor | Invoice ID | Tgl | Cust | UNIT_IDR | JASA_IDR | SPARE_IDR | KOTOR_IDR | Sum_Kategori | Status |
|-------|------------|-----|------|----------|----------|-----------|-----------|--------------|--------|
| 1 | INV-001 | 15-Jun-26 | PT A | 100jt | 30jt | 50jt | 180jt | 180jt | ✓ |
| 2 | INV-002 | 14-Jun-26 | PT B | 0 | 20jt | 60jt | 80jt | 80jt | ✓ |
| 3 | INV-003 | 13-Jun-26 | PT C | 150jt | 0 | 0 | 150jt | 150jt | ✓ |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |
| 40 | INV-040 | ... | ... | ... | ... | ... | ... | ... | ✓ |

**Summary Baris:**
- Total PASS: 40
- Total FAIL: 0 ← **HARUS 0, jika tidak ada = STOP**

---

## KRITERIA GO/NO-GO

### ✅ GO (Boleh Lanjut ke Coding)

```
[✓] Query Set 1: Detil kode 01/02/03 sudah dilihat
[✓] Query Set 2: Mapping aggregate sudah terbukti
[✓] Query Set 3: 40 invoice semua BALANCE
[✓] Tidak ada kategori unexpected
[✓] Business approval dari hasil profiling
```

### ❌ NO-GO (Stop, Harus Debug Dulu)

```
[✗] Ada invoice yang NOT BALANCE → FORMULA BUG
[✗] Ada kategori unexpected (selain JS, SP, UNIT) → PERLU MAPPING BARU
[✗] Ada data quality issue (NULL, invalid) → DATA HARUS DIPERBAIKI
[✗] Ada kombinasi penjualan+group_product yang tidak expected → INVESTIGASI
```

---

## FORMULA FINAL (Hanya Jika GO)

Jika semua validasi PASS, formula final EXPLICIT:

```powerbuilder
// Detail Band Computes

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

// Group Header Computes

compute_unit_idr = sum(cunit_idr for group 1)
compute_jasa_idr = sum(cjasa_idr for group 1)
compute_spare_idr = sum(cspare_idr for group 1)
compute_kotor_idr = sum(ckotor_idr for group 1)

// Validation (untuk regression test)
// compute_validation_balance = 
//   IF (compute_unit_idr + compute_jasa_idr + compute_spare_idr = compute_kotor_idr)
//   THEN "OK" ELSE "ERROR"
```

---

## NEXT STEPS

1. **Execute Query Set 1** → Lihat detail data
2. **Execute Query Set 2** → Lihat mapping
3. **Execute Query Set 3.5** → Validate 40 invoice
4. **Document di spreadsheet** → Track hasil
5. **Share hasil** → Review bersama
6. **Approve → Coding** atau **Debug → Refining mapping**

---

## TIMELINE

- **Query execution:** 30 menit
- **Manual validation:** 1 jam
- **Documentation:** 30 menit
- **Review & approval:** 30 menit
- **Total:** 2.5 - 3 jam

**TIDAK BOLEH SKIP TAHAP INI.**

