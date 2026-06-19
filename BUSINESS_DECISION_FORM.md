# KONFIRMASI MAPPING KATEGORI
## Report Rekap Penjualan By Customer

**Tanggal:** 2026-06-16  
**Tujuan:** Konfirmasi kategori revenue untuk 3 group product sebelum implementasi report  
**Status:** Pending business owner approval

---

## LATAR BELAKANG

Dalam proses pengembangan report "Rekap Penjualan By Customer", kami telah melakukan profiling data historis untuk memetakan semua group product ke dalam 3 kategori utama:

- **UNIT** (Equipment/Machinery)
- **JASA** (Services)
- **SPARE PARTS** (Components & Materials)

Dari 34 group product yang ada, 31 sudah dapat dipetakan dengan confidence tinggi (>90%).

**Namun ada 3 group product yang memerlukan keputusan bisnis:**

- **L (LOKAL)** - Rp 13.5 Miliar (1.4% of revenue)
- **BX (BOX FIBERGLASS)** - Rp 4.3 Miliar (0.4% of revenue)
- **MT (MATERIAL TAMBAHAN)** - Rp 2.2 Miliar (0.2% of revenue)

**Total yang menunggu keputusan: Rp 20.0 Miliar (2.0% of total revenue)**

Angka ini terlalu material untuk diasumsikan. Oleh karena itu, kami perlu konfirmasi bisnis sebelum coding dimulai.

---

## PERTANYAAN 1: L (LOKAL)

### Data
| Field | Value |
|-------|-------|
| **Kode Group** | L |
| **Nama** | LOKAL |
| **Penjualan Code** | 400-121 |
| **Revenue Historis** | Rp 13,534,236,658 |
| **% dari Total** | 1.4% |

### Pertanyaan
**L (LOKAL) masuk kategori mana dalam report Rekap Penjualan?**

- [ ] **UNIT** — Dijual sebagai unit/equipment
- [ ] **JASA** — Layanan/installation related
- [ ] **SPARE PARTS** — Komponen, parts, material pendukung
- [ ] **Lainnya, silakan jelaskan:** ___________________________________

### Catatan Teknis
Kode "LOKAL" di industri refrigerasi biasanya mengindikasikan:
- Local spare parts (komponen lokal)
- Local non-OEM components
- Local supplier parts

Namun nama ini terlalu umum untuk konklusi otomatis.

---

## PERTANYAAN 2: BX (BOX FIBERGLASS)

### Data
| Field | Value |
|-------|-------|
| **Kode Group** | BX |
| **Nama** | BOX FIBERGLASS |
| **Penjualan Code** | 400-301 |
| **Revenue Historis** | Rp 4,288,684,469 |
| **% dari Total** | 0.4% |

### Pertanyaan
**BX (BOX FIBERGLASS) masuk kategori mana dalam report Rekap Penjualan?**

- [ ] **UNIT** — Refrigerated body/cargo box (bagian dari unit solution)
- [ ] **JASA** — Layanan pemasangan/modifikasi box
- [ ] **SPARE PARTS** — Komponen/aksesori pengganti
- [ ] **Lainnya, silakan jelaskan:** ___________________________________

### Catatan Teknis
**BX PALING BERISIKO JIKA SALAH DIKATEGORIKAN** karena:
- Box fiberglass bisa dianggap sebagai "refrigerated body" yang merupakan bagian integral dari solusi unit
- Atau bisa dianggap sebagai accessory/spare yang dapat diganti
- Revenue Rp 4.3B adalah material (0.4% dari total)
- Salah kategorisasi akan menggeser revenue antar kategori

---

## PERTANYAAN 3: MT (MATERIAL TAMBAHAN)

### Data
| Field | Value |
|-------|-------|
| **Kode Group** | MT |
| **Nama** | MATERIAL TAMBAHAN |
| **Penjualan Code** | 400-410 |
| **Revenue Historis** | Rp 2,243,897,714 |
| **% dari Total** | 0.2% |

### Pertanyaan
**MT (MATERIAL TAMBAHAN) masuk kategori mana dalam report Rekap Penjualan?**

- [ ] **UNIT** — Material yang menjadi bagian dari unit
- [ ] **JASA** — Material untuk instalasi/service
- [ ] **SPARE PARTS** — Consumables/materials pendukung
- [ ] **Lainnya, silakan jelaskan:** ___________________________________

### Catatan Teknis
"Material Tambahan" di industri ini biasanya mencakup:
- Consumables (oli, freon, chemicals)
- Installation materials (pipa, kabel, insulation)
- Supporting materials (gasket, fasteners)

Pada praktik laporan keuangan, items seperti ini umumnya digabung ke kategori "SPARE PARTS" karena sifatnya pendukung.

---

## IMPLIKASI KEPUTUSAN

### Jika Mapping Disetujui:

**Kategori akan dikunci dan akan digunakan untuk:**

1. **Report Rekap Penjualan By Customer** - Summary breakdown revenue per customer
2. **Finance Summary** - Ringkasan total UNIT, JASA, SPARE PARTS
3. **Analisis Trend** - Historical analysis per kategori
4. **KPI Dashboard** - Performance per revenue category

**Semua formula akan hardcode berdasarkan keputusan bisnis ini.**

### Jika Mapping Salah:

- Report akan menampilkan angka yang tidak akurat
- Tren analysis akan bias
- Decision making berdasarkan data yang salah

---

## TIMELINE

| Aktivitas | Target |
|-----------|--------|
| **Dikirim ke Business** | 2026-06-16 |
| **Deadline Jawaban** | 2026-06-17 |
| **Mapping Dikunci** | 2026-06-17 |
| **Coding Dimulai** | 2026-06-17 |
| **Testing Dimulai** | 2026-06-18 |
| **UAT Dimulai** | 2026-06-19 |

---

## CATATAN PENTING

✅ **Jika Business tidak menjawab salah satu pertanyaan**, mapping tidak akan dikunci dan coding HOLD.

✅ **Jika Business memberikan jawaban berbeda dari ekspektasi**, kami akan re-kalkulasi dan validate sebelum coding dimulai.

✅ **Keputusan ini adalah FINAL** dan akan menjadi source of truth untuk coding phase dan seterusnya.

---

## APPROVAL SIGN-OFF

Setelah menerima jawaban bisnis atas 3 pertanyaan di atas:

**Technical Lead approval:** ___________________ Date: ___________

**Business Owner approval:** ___________________ Date: ___________

**Project Manager approval:** ___________________ Date: ___________

---

**Silakan jawab 3 pertanyaan di atas dan return form ini.**

**Contact:** kimtechgurning@gmail.com

**Questions?** Hubungi tim development.

