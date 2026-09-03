# RUNBOOK — Recovery SINV + Prevention (audit-safe)
Root cause: bug refresh/closing HISTORIS menulis SINV > engine. Engine sekarang = GL ke rupiah (FINAL_ROOT_CAUSE_DEFINITIVE.md).
Prinsip: BUKAN write-off, BUKAN ketik angka — **regenerasi SINV dari engine terverifikasi**.

## TAHAP 1 — RECOVERY (regenerasi SINV = Engine = GL)

### Mekanisme
SINV opening 2026 salah tulis. Regenerasi dari engine: jalankan closing engine yang menulis
`sinv[bulan+1]` = AKHIR `dw_refresh_stok` (yang terbukti = GL).

Karena phantom ada di OPENING 2026 (closing Des-2025), regenerasi = **re-close Des-2025 dgn al_replace=1**
(fitur year-close yang SUDAH ada di hardening P2), lalu **re-refresh Jan-Feb** agar opening benar merambat.

### Langkah (COPY-DB dulu — WAJIB)
1. **Backup DB prod penuh** (titik pulih).
2. **Restore ke COPY-DB** (mesin/port terpisah).
3. **Recovery closing Des-2025** (regen opening 2026):
   - Via aplikasi: Refresh Modern → periode **Desember 2025** → jalankan (engine hardened memakai al_replace=1 saat batas tahun → tulis ulang sinv[2026-01-01] = engine = GL).
   - ATAU panggil NVO langsung: `n_cst_closing_stock.of_run(f_bom('2025-12-01'), false, true, 1, 0, st)` (ab_sinv_only=true → hanya sinv, GL tak disentuh).
4. **Re-refresh Jan-2026 lalu Feb-2026** (urut) → opening benar merambat ke sinv Feb, Mar.
5. **VALIDASI** (query `validation_post_closing.sql`): 102-001/003/006/010/101/110 → **gap ≤ Rp1**.
   - 102-201 diharapkan MASIH beda (−23,96 jt) → itu **isu GL saldo-awal MT** terpisah (lihat catatan bawah), bukan phantom sinv.
6. **BUKTI IDEMPOTEN** (`idempotency_evidence.sql`): ulangi recovery closing (RUN2), checksum sinv RUN1==RUN2 (delta 0).
7. Bila 5 & 6 lulus → **paket evidence** (before/after gap, checksum) → baru **prod**:
   - prod: ulangi langkah 3-5 pada prod (agent tak eksekusi; Bapak jalankan).

### Yang TIDAK disentuh
- **GL** (gl_journal/gl_balance) — sudah benar (= engine).
- **HPP WIP / serial / Konsinyasi** (Bagian A/B utuh).
- **Transaksi** (tstok/tsales) — semua benar; hanya SINV (data turunan) diregenerasi.

## TAHAP 2 — PREVENTION (validasi tiap closing)
Pasang `validation_post_closing.sql` di **akhir setiap refresh/closing**:
- Hitung gap = SINV − LEDGER per akun.
- **gap ≤ Rp1 → PASS**; **> Rp1 → FAIL/WARNING**, jangan finalisasi, tandai review + tulis `refresh_ledger.status='WARNING'`.
- Desain pemasangan PB ada di komentar file SQL.
→ Bila bug refresh terulang, langsung terdeteksi saat closing (bukan berbulan kemudian).

## Isu terpisah (jangan dicampur)
- **102-201 (MT) −23,96 jt:** sinv = engine, **GL yang lebih tinggi** → saldo-awal GL 102-201 (warisan tutup buku), bukan phantom sinv. Koreksi terpisah (samakan gl_balance 102-201 ke engine/stok), kecil & terdokumen.
- **WIP 102-020 (Bagian A)** & **costing (Bagian B)** — independen, tetap berlaku.

## VALIDASI IDEMPOTENCY (WAJIB sebelum prod — usulan Pak Wira)
Recovery harus deterministik: **jalankan dua kali, hasil identik.**
```
Re-close Des -> Refresh Jan-Feb -> VALIDASI (SINV=GL)   [RUN #1]
Re-close Des -> Refresh Jan-Feb -> VALIDASI (SINV=GL)   [RUN #2]
checksum(RUN#1) == checksum(RUN#2)  ->  delta 0
```
- **RUN#2 mengubah angka → ada bug laten (JANGAN prod).**
- **RUN#2 tidak mengubah apa pun → recovery deterministik, aman jadi SOP.**
Terbukti di LOCAL (cascade Des->Jan->Feb dijalankan 2×, checksum identik — lihat evidence eksekusi).

## PREVENTION jadi bagian SOP CLOSING (usulan Pak Wira)
Setiap closing selesai, WAJIB kontrol:
```
Closing selesai
  -> hitung ulang ENGINE (dw_refresh_stok)
  -> bandingkan: ENGINE vs SINV vs GL
  -> jika |selisih| > Rp1  ->  CLOSING FAIL (jangan finalisasi, tandai review)
```
Pasang `validation_post_closing.sql` di akhir refresh; tulis status ke `refresh_ledger`.
→ Bug seperti gap Rp10,11 M langsung ketahuan saat closing, bukan berbulan kemudian.

## Definition of Done (audit-safe — final)
- [ ] Backup DB dibuat sebelum eksekusi.
- [ ] Recovery via **NVO / proses closing resmi** (bukan UPDATE SQL) — re-close Des-2025 (al_replace=1) + re-refresh Jan-Feb.
- [ ] **SINV = Engine = GL** (`validation_post_closing.sql`, gap ≤ Rp1; NVO recompute hpp presisi → tanpa residu).
- [ ] **WIP 102-020 tidak berubah** (delta GL 102-020 = 0).
- [ ] **HPP WIP tidak berubah** (Σ hpp×qty '88' = 0 delta).
- [ ] **Idempotent**: re-close kedua tidak mengubah hasil (delta 0).
- [ ] Costing: WIP sale = HPP WIP-Out; non-WIP = average.
- [ ] Mutasi Jan-Feb tidak berubah (regen di closing/opening, bukan gerakan).
- [ ] Prevention aktif (validasi otomatis tiap closing).
- [ ] Kesimpulan audit terdokumen (FINAL_ROOT_CAUSE_DEFINITIVE.md).
→ Semua ✓ → deploy prod.

## Isu terpisah tersisa
- **102-201 (MT) −23,96 jt**: sinv=engine, GL yang beda → koreksi saldo-awal GL 102-201 sendiri.
