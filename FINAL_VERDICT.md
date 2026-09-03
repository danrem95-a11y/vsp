# FINAL VERDICT — Investigasi Penulis Opening SINV 2026 & Gap Rp 16.762.544.094,50

Audit forensik read-only prod vspnew. 2026-07-31. **Koreksi laporan sebelumnya:** audit trail TERNYATA ADA (`USER_LOG_BACKUP`, 133.406 baris, Apr-2024 … Jul-2026) — sebelumnya salah dinyatakan nihil.

---

## LANGKAH 1 — WRITE GRAPH lengkap (semua yang bisa menulis `sinv`)
**Sisi DATABASE:**
- Stored procedure yg menyebut sinv: **0**.
- Trigger pada/menyebut sinv: **0**.
- Scheduled event: 3 (`UPDATE HPP_TSTOK2` → hanya tstok2; `AutoBackupDatabase` → dbbackup; `auto_backup_log` → arsip user_log). **Tak satu pun menulis sinv.**

**Sisi SOURCE (embedded SQL / DataStore update):**
| Writer | Mekanisme | Nilai qty yang ditulis |
|---|---|---|
| `n_cst_closing_stock` (NVO, dipanggil REFRESH) | delete sinv periode + DataStore `ids_sinv.update()` | `dw_view.akhir` = **engine (9)** |
| `w_closing_stok` (Stock Opname) | delete sinv + `dw_sinv.update()`; L628 `ld_qty=dw_view.object.akhir` | `dw_view.akhir` = **engine (9)**; kode entri-fisik manual L263-417 **ter-comment mati** |
| `w_refresh_hppstok(_current)` | delete sinv periode + reinsert | engine |
| `w_refresh_stok` | delete sinv periode | engine |
| copy mati (`_20210603`, `_upd`) | — | — |
- **Tak ada** EXECUTE IMMEDIATE / dynamic SQL yang menulis sinv (yang ada: FA & `set isolation level`).

## LANGKAH 2–3 — Sifat writer & CALL GRAPH
```
Menu Refresh → w_refresh_transaksi_modern / w_refresh_journal
   → of_refresh_so → NVO n_cst_closing_stock.of_run(periode, ab_silent, ab_sinv_only, al_replace, al_minus)
      → dw_view=dw_refresh_stok (hitung AKHIR) → ids_sinv.update() → sinv(periode=bln+1)
      → cabang tahun (mm next='01'): tulis sinv 2026-01-01 HANYA bila al_replace=1
Menu Stock Opname → w_closing_stok → dw_view=dw_refresh_stok (AKHIR) → dw_sinv.update()
```
- Bisa tulis opening: **NVO year-branch (al_replace=1)** & w_closing_stok. Keduanya menulis **AKHIR engine**. Overwrite/replace (delete periode + insert). Bukan append.

## LANGKAH 4 — TIMELINE (dari USER_LOG_BACKUP)
- **Des-2025 di-refresh 47× (min.) oleh user `super`**, pertama **2025-12-30 12:09** (REFRESH SO periode 01-12-2025 s/d 31-12-2025), berlanjut s/d Mar-2026+.
- Aktivitas tutup-tahun 2025 di log = **HANYA REFRESH** (SO/PO/NONITEM/EXP/AR/AP/ADJ/WIPOUT/WIPIN). **Tidak ada** aksi "closing stok", "stock opname", "saldo awal", atau input manual saldo.

## LANGKAH 5 — SEMUA writer resmi menghasilkan qty engine (TERBUKTI)
- `dw_refresh_stok` retrieve dijalankan langsung utk Des-2025 → **AKHIR = 9** (TR.038A), = GL untuk **ketiga akun** (selisih <Rp1).
- Backup engine tertua `dw_refresh_stok.srd.bak_hppfix` (30-Jun-2026, = versi original sebelum fix Jun-Jul) → **juga AKHIR = 9**. Formula qty stabil lintas versi.
- ⇒ **Tidak ada jalur resmi kini/terarsip yang menghasilkan 45.** Nilai 45 di luar keluaran engine.

## LANGKAH 6 — EVIDENCE MATRIX media penulis 45
| Media | Mendukung | Membantah | Confidence |
|---|---|---|---|
| REFRESH (NVO year-open) | audit trail: hanya REFRESH di tutup-tahun; NVO memang penulis sinv opening | semua versi engine hitung 9; oto-minus menambah ke sinv **2025**-01 (bukan 2026-01); reefer selalu positif → oto-minus tak fire | **SEDANG** (proses & waktu cocok; nilai tak tereproduksi) |
| Direct SQL (dbisql) | bisa tulis nilai apa pun; **tak ter-log** di USER_LOG (logging app-level) | tak ada bukti positif | RENDAH |
| Import / restore parsial | bisa membawa nilai lama | tak ada bukti; DB tunggal | RENDAH |
| Stock Opname manual | window ada | kode entri-fisik ter-comment; hitung via dw=9; tak ada log opname | SANGAT RENDAH |
| Utility/script maintenance | bisa | tak ada file/bukti | RENDAH |
**Tak ada satu media pun yang TERBUKTI.**

## LANGKAH 7 — FIRST WRITE → BELUM TERBUKTI (kondisi STOP-2)
**Yang TERBUKTI:**
- Proses penulis sinv opening yang **ter-log** = **REFRESH oleh `super`, pertama 2025-12-30 12:09** (via NVO year-branch al_replace=1); ditulis **sekali**, tak ditimpa (refresh berikutnya al_replace=0).
- Nilai yang ditulis seharusnya = AKHIR engine = **9**.

**Yang TIDAK dapat dibuktikan:** mengapa nilai tersimpan **45**, dan baris/proses persis yang menulisnya.

**MENGAPA tidak dapat dibuktikan (bukan kehabisan ide — informasi memang sudah tiada):**
1. **Binary engine per 30-12-2025 tidak diarsipkan.** Backup tertua (30-Jun-2026) menghitung 9; tak ada artefak engine Des-2025.
2. **Tak ada timestamp entry transaksi.** `tstok1/tsales1` hanya punya `TGL` (tanggal transaksi), tak ada kolom "kapan baris di-entry". Maka state transaksi persis pada 30-12-2025 12:09 tak dapat direkonstruksi.
3. **NVO MENGHAPUS `sinv_minus` setiap run** (`delete from sinv_minus where periode=:ldt_tgl1`). Input antara (oto-minus) yang mungkin memengaruhi year-open sudah dimusnahkan oleh proses itu sendiri.
4. **Tulisan out-of-band tak ter-log.** USER_LOG mencatat aksi APLIKASI; UPDATE langsung via dbisql / import / restore **tidak** tercatat by design. Bila 45 berasal dari sana, jejaknya memang tak pernah ada.

⇒ Secara teori informasi, input yang menghasilkan 45 (engine-binary + urutan-entry + sinv_minus saat itu) **sudah tidak tersimpan di database**. Investigasi berhenti secara ilmiah di sini, bukan karena kurang usaha.

## LANGKAH 8 — Persamaan Pak Wira (matematis)
```
GL 102-001 + 102-003 + 102-006 + 102-020(WIP) = 16.799.042.160,43
engine-sinv(=GL 001+003+006) 14.931.351.144,87
  + Outstanding WIP-Out       1.799.966.015,56
  = 16.731.317.160,43
  residu = 67.725.000,00  (= GL 102-020 − Outstanding; angka BULAT → kandidat 1 voucher WIP; sub-residu akun WIP, TERPISAH dari gap 16,76 M)
```
**Terbukti:** engine-sinv + Outstanding WIP ≈ GL-total, residu 67,725 jt di akun WIP. Hipотesis Pak Wira **benar** untuk porsi WIP.

## LANGKAH 9 — WATERFALL (habis ke 0)
```
TOTAL GAP (sinv stok reefer − GL stok reefer 001/003/006)   16.762.544.094,50
  − Outstanding WIP-Out (Bucket A, real, GL 102-020)          1.512.525.638
  − Valuation                                                          0
  − GL Missing                                                         0
  − Broken Cycle / Manual (tak ada bukti)                              0
  − Phantom Quantity opening (Bucket D)                       15.250.018.456,50
  = REMAINING                                                          0,00
```
(Sub-residu akun WIP 67,725 jt = terpisah; kandidat 1 voucher, dapat dipecah bila diminta.)

---

## LANGKAH 10 — FINAL VERDICT (7 pertanyaan)
| # | Pertanyaan | Jawaban | Dasar |
|---|---|---|---|
| 1 | Redesign engine boleh diproduksi? | **YA.** | Engine hitung 9 = GL (benar), idempotent, single authority; gap **bukan** dari engine baru |
| 2 | Gap murni data historis? | **YA.** | 100% di opening 2026-01-01; 23 bln 2024-2025 konsisten; bukan mutasi Jan-Jul; bukan engine |
| 3 | Perlu koreksi data? | **Bucket D (15,25 M): data opening sinv terbukti ≠ engine=GL.** Perlu **regenerasi opening lewat engine** (bukan angka manual) bila ingin sinv=GL. Bucket A (1,51 M): tidak (WIP sah di 102-020) | engine=GL terbukti; opening phantom |
| 4 | Perlu koreksi jurnal? | **TIDAK.** | GL = transaksi sampai Rp<1; GL benar |
| 5 | Perlu gudang WIP virtual (102-020) usulan Pak Wira? | **Opsi sah & defensible** untuk membuat rekonsiliasi menyertakan WIP; Bucket A (1,51 M) memang di 102-020. Tidak wajib untuk memperbaiki data, tapi memperbaiki **metode rekonsiliasi** | WIP nyata di GL 102-020 |
| 6 | Cukup ubah laporan tanpa ubah data? | **Untuk Bucket A: YA** (sertakan 102-020 di rekon). **Untuk Bucket D: TIDAK** — 15,25 M adalah qty opening sinv yang salah; tak ada perubahan laporan yang membuatnya benar tanpa menyentuh nilai sinv | dua bucket beda sifat |
| 7 | Solusi paling defensible untuk auditor? | **Regenerasi saldo awal 2026 lewat engine yang sudah benar** (menghasilkan 9=GL, tanpa angka manual, terdokumentasi forensik ini) + rekonsiliasi menyertakan 102-020 untuk WIP. **Tidak** ada jurnal koreksi (GL sudah benar) | engine=GL; audit-traceable |

## Kesimpulan penulis (jujur)
- **Gap 100% terpecah:** Bucket A (WIP sah 1,51 M) + Bucket D (phantom qty opening 15,25 M). Remaining = 0.
- **First Write penulis 45: BELUM TERBUKTI (STOP-2).** Proses ter-log = REFRESH oleh `super` 30-12-2025; tetapi nilai 45 tak tereproduksi oleh engine mana pun & input aslinya sudah dimusnahkan sistem (sinv_minus dihapus, tak ada timestamp entry, out-of-band tak ter-log). Ini batas informasi-teoretis, bukan batas usaha.
- **Tidak** memberi label "manual/anomali/override" sebagai sebab — hanya menyatakan: qty opening sinv 2026-01-01 ≠ engine=GL; penulis pasti tak dapat diidentifikasi dari data yang tersisa.
