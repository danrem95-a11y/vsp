# STATUS PROYEK - ASSESSMENT AKURAT
## Rekap Penjualan By Customer - Report Fix

**Date:** 2026-06-16  
**Status:** ✅ SIAP PROFILING & DESIGN REVIEW FINAL  
**NOT Ready:** ❌ Belum siap coding  

---

## COMPLETION MATRIX

| Fase | Status | Keterangan |
|------|--------|-----------|
| **Root Cause Analysis** | ✅ Selesai | Ketemu: dw_rpt_jual tidak filter kategori |
| **Code Review** | ✅ Selesai | Reference impl di d_jual_faktur_lain.srd sudah ada |
| **Formula Design Awal** | ✅ Selesai | UNIT=03, JASA=JS, SPARE=SP (hipotesis) |
| **Risk Assessment** | ✅ Selesai | Identified 5 major risks |
| **Data Profiling** | ⏳ **PENDING** | Diagnostic script ready, tunggu hasil |
| **Balance Proof** | ⏳ **PENDING** | Query siap, tunggu hasil validation |
| **Design Review Final** | ⏳ **PENDING** | Tunggu profiling, approve formula |
| **Coding Implementation** | ❌ Belum | Baru setelah design review approval |
| **QA Testing** | ❌ Belum | Baru setelah coding selesai |
| **UAT** | ❌ Belum | Baru setelah QA pass |

---

## YANG SUDAH TERBUKTI (3 hal)

### 1. ✅ Root Cause Sudah Ketemu

**Evidence:**
```
dw_rpt_jual_faktur1_rekap.srd:
  compute_46: sum(ckotor for group 1)        ← SEMUA (tidak filter)
  compute_47: sum(ckotor_idr for group 1)    ← SEMUA (tidak filter)
```

**Bukti:**
- Tidak ada IF statement berdasarkan penjualan atau group_product
- Semua revenue (01, 02, 03) masuk ke satu kolom "Unit"
- Tidak ada kolom Jasa atau Spare Parts

**Kesimpulan:** ✅ Ini adalah **ROOT CAUSE yang valid**

---

### 2. ✅ Reference Implementation Sudah Ada

**Evidence:**
```
d_jual_faktur_lain.srd:
  compute_5: sum(if(group_product='JS',kotor,0) for all)
  compute_2: sum(if(group_product<>'JS',kotor,0) for all)
```

**Bukti:**
- Developer sebelumnya SUDAH pernah implement group_product filtering
- Logic sudah tested dan work di file lain
- Dapat di-copy pattern-nya

**Kesimpulan:** ✅ Ini adalah **PROVEN PATTERN**

---

### 3. ✅ Explicit Mapping Lebih Aman

**Perbandingan:**

```powerbuilder
// ❌ Catch-all (dangerous):
if(group_product<>'JS', ...)
→ Akan silent catch kategori baru: ACC, FRT, OTH

// ✅ Explicit (safe):
if(group_product='SP', ...)
→ Kategori baru tidak ter-capture, error visible
```

**Kesimpulan:** ✅ Ini adalah **BEST PRACTICE yang jelas**

---

## YANG MASIH HARUS DIBUKTIKAN (3 hal)

### 1. ❓ Apakah SP Memang Satu-satunya Non-JS?

**Pertanyaan:** Hasil agregasi group_product akan menunjukkan apa?

**Scenario A: IDEAL (hanya ada 3 kategori)**
```
group_product | jumlah | total_kotor | pct
JS            | 245    | 15.2M       | 20%
SP            | 590    | 58.9M       | 78%
UNIT          | 89     | 2.1M        | 3%
```
→ ✅ Formula AMAN: if(group_product='SP')

**Scenario B: KOMPLEKS (ada kategori ekstra)**
```
group_product | jumlah | total_kotor | pct
JS            | 245    | 15.2M       | 20%
SP            | 590    | 58.9M       | 70%
ACC           | 34     | 5.2M        | 6%   ← UNEXPECTED!
UNIT          | 89     | 2.1M        | 3%
FRT           | 12     | 500K        | 1%   ← UNEXPECTED!
```
→ ❌ Formula TIDAK AMAN: masih missing ACC + FRT

**Apa yang dijalankan:**
```sql
Query 4.5 (diag_group_product_agregasi.txt)
→ Akan show agregasi dengan % dominan
→ Akan terlihat kategori aneh yang jarang tapi ada
```

**Target:** Semua non-JS category harus identified untuk decide:
- Apakah masuk Spare Parts?
- Atau kategori separate?

---

### 2. ❓ Apakah penjualan='03' SELALU group_product='UNIT'?

**Pertanyaan:** Ada mapping lain antara kode 03 dan group_product?

**Scenario A: IDEAL (1-to-1 mapping)**
```
penjualan | group_product | jumlah
01        | JS            | 245
01        | SP            | 178
02        | SP            | 412
03        | UNIT          | 89      ← Hanya ini!
```
→ ✅ Formula AMAN: if(penjualan='03')

**Scenario B: COMPLEX (03 ada 2 kategori)**
```
penjualan | group_product | jumlah
01        | JS            | 245
01        | SP            | 178
02        | SP            | 412
03        | UNIT          | 89
03        | SP            | 12      ← UNEXPECTED!
```
→ ❌ Formula SALAH: unit_idr jadi 12 juta lebih (ketambah dari 03+SP)

**Apa yang dijalankan:**
```sql
Query 1 (diag_penjualan_kombinasi.txt)
→ Akan show SEMUA kombinasi penjualan + group_product
→ Akan terlihat jika kode 03 pair dengan grup selain UNIT
```

**Target:** Jika ada 03+SP atau 03+JS, formula Unit harus direvisi jadi:
```
if(group_product='UNIT', kotor*kurs, 0)   ← Bukan if(penjualan='03')
```

---

### 3. ❓ Balance Proof - Apakah UNIT + JASA + SPARE = KOTOR?

**Pertanyaan:** Untuk 100% invoice, apakah formula akan balance?

**Scenario A: SEMUA BALANCE (target)**
```
Invoice 1: 100 + 30 + 50 = 180 = 180 ✓
Invoice 2: 0 + 20 + 60 = 80 = 80 ✓
Invoice 3: 150 + 0 + 0 = 150 = 150 ✓
...
Invoice 40: ... = ... ✓

Result: 0 rows NOT BALANCE → ✅ FORMULA BENAR
```

**Scenario B: ADA YANG NOT BALANCE (problem)**
```
Invoice 5: 100 + 30 + 50 = 180 ≠ 190 ✗
Invoice 17: 0 + 0 + 0 = 0 ≠ 50 ✗

Result: 2+ rows NOT BALANCE → ❌ FORMULA SALAH
        Harus investigate kategori apa yang missing
```

**Apa yang dijalankan:**
```sql
Query 5.5 (diag_balance_not_ok.txt)
→ Hanya menampilkan invoice yang NOT BALANCE
→ Target: File HARUS KOSONG (0 rows)
→ Jika ada rows: investigate mana kategori yang missing
```

**Target:** Jika ada variance > 1, harus:
1. Cek kombinasi penjualan+group_product apa yang ada di invoice tersebut
2. Identifikasi: "Kategori X mana yang tidak ter-capture?"
3. Update formula untuk include kategori tersebut
4. Re-run validation
5. Jika tetap tidak balance, ada bug di formula atau data quality issue

---

## DIAGNOSTIC SCRIPT: QUERIES YANG DIJALANKAN

| Query | File Output | Purpose | Critical? |
|-------|-------------|---------|-----------|
| 1 | diag_penjualan_kombinasi.txt | Matrix mapping | 🔴 YES |
| 2 | diag_kode_01_detail.txt | Detail kode 01 | 🟡 Reference |
| 3 | diag_group_product_values.txt | Inventory | 🔴 YES |
| 4 | diag_penjualan_codes.txt | Inventory | 🟡 Reference |
| 4.5 | diag_group_product_agregasi.txt | Kategori dominan | 🔴 YES |
| 5 | diag_balance_validation.txt | 40 invoices summary | 🟡 Reference |
| 5.5 | diag_balance_not_ok.txt | Only NOT BALANCE | 🔴 YES |

**Critical output yang HARUS diperiksa:**
- ✅ Query 1: Semua kombinasi penjualan+group_product
- ✅ Query 4.5: Apakah hanya JS, SP, UNIT atau ada lain?
- ✅ Query 5.5: **HARUS KOSONG** (0 rows)

---

## DESIGN REVIEW CHECKLIST

### Sebelum Approve Formula

```
Dari file: diag_penjualan_kombinasi.txt
□ Apakah ada kombinasi penjualan+group_product selain:
  ✓ 01+JS
  ✓ 01+SP
  ✓ 02+SP
  ✓ 03+UNIT

Dari file: diag_group_product_agregasi.txt
□ Apakah ada group_product selain:
  ✓ JS (Jasa)
  ✓ SP (Spare Parts)
  ✓ UNIT (Unit)

Dari file: diag_balance_not_ok.txt
□ HARUS kosong (0 rows)
□ Jika ada rows, apakah variance-nya kecil (< 2)?

DESIGN DECISION:
□ Jika 3 checklist di atas semua PASS:
  → ✅ APPROVE formula: UNIT=03, JASA=JS, SPARE=SP
  
□ Jika ada combinasi unexpected:
  → ❌ HOLD design, update mapping, re-validate
  
□ Jika ada invoice NOT BALANCE:
  → ❌ STOP, investigate root cause sebelum coding
```

---

## FORMULA YANG AKAN DI-APPROVE (tergantung hasil)

### SCENARIO A: Jika IDEAL (hanya JS, SP, UNIT)

```powerbuilder
cunit_idr = if(im_product_group_penjualan='03', kotor_asli*kurs, 0)
cjasa_idr = if(group_product='JS', kotor_asli*kurs, 0)
cspare_idr = if(group_product='SP', kotor_asli*kurs, 0)
ckotor_idr = kotor_asli * kurs
```

### SCENARIO B: Jika KOMPLEKS (ada kategori lain)

Formula harus di-update untuk include semua kategori.
Contoh: Jika ada ACC (Accessories), harus:

```powerbuilder
cunit_idr = if(group_product='UNIT', kotor_asli*kurs, 0)
cjasa_idr = if(group_product='JS', kotor_asli*kurs, 0)
cspare_idr = if(group_product IN ('SP','ACC'), kotor_asli*kurs, 0)
ckotor_idr = kotor_asli * kurs
```

Atau buat kolom terpisah untuk ACC (tergantung business requirement).

---

## NEXT STEPS

### Hari Ini: PROFILING

1. Run diagnostic script
2. Tunggu sampai selesai (5-10 menit)
3. Verify 6 output files tergenerate

### Setelah Profiling: DESIGN REVIEW

1. Share 6 file hasil ke Claude
2. Claude review terhadap 3 pertanyaan kritis
3. Jika IDEAL: Approval formula & planning coding
4. Jika KOMPLEKS: Discuss alternative design

### Setelah Design Approval: CODING

1. Edit dw_rpt_jual_faktur1_rekap.srd
2. Implement approved formula
3. Compile & test

---

## RISK MITIGATION STRATEGY

**Risk:** Formula salah → Reporting misleading

**Mitigation Strategy:**
```
1. ✅ Design review KETAT (3 critical validations)
2. ✅ Balance proof WAJIB (diag_balance_not_ok.txt harus kosong)
3. ✅ Explicit formula (no catch-all)
4. ✅ Coding review sebelum deploy
5. ✅ UAT dengan business (validasi 20+ sample invoices)
6. ✅ Rollback plan (jika ada issue, back to old report)
```

---

## TIMELINE (REALISTIC)

| Phase | Activity | Duration | Blocker |
|-------|----------|----------|---------|
| Day 1 | Diagnostic profiling | 30 min | Wait for script |
| Day 1-2 | Design review | 1-2 hours | Data interpretation |
| Day 2-3 | Formula approval | 30 min | Design review decision |
| Day 3 | Coding | 2-3 hours | Approved formula |
| Day 3-4 | QA testing | 2 hours | Coding completion |
| Day 4 | UAT | 1 hour | QA sign-off |
| **Total** | | **9-13 hours** | |

---

## KESIMPULAN

**Status Proyek:**
```
✅ Analysis Phase: SELESAI (root cause, pattern, risk identified)
⏳ Profiling Phase: IN PROGRESS (diagnostic script ready)
⏳ Design Review Phase: WAITING (pending profiling results)
❌ Implementation Phase: NOT STARTED (waiting design approval)
```

**Tidak boleh langsung coding karena:**
1. 3 asumsi KRITIS harus dibuktikan dengan data
2. Balance validation HARUS 100% sebelum deploy
3. Jika ada kategori unexpected, design harus di-update

**Jika langsung coding tanpa validation:**
- ⚠️ Risk: Formula salah → report misleading → perlu fix lagi
- ⚠️ Risk: Data loss atau double count tidak terdeteksi
- ⚠️ Risk: Audit trail tidak jelas

**Strategi yang aman:** Profiling → Design Review → Coding → QA → UAT

---

**Prepared by:** Claude (berdasarkan feedback user)  
**Last Updated:** 2026-06-16  
**Status:** Ready for Diagnostic Execution

