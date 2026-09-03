# EVIDENCE — RELEASE ACCEPTANCE (Redesign Engine Refresh HPP WIP-Out)

**Tujuan:** satu halaman keputusan ACC Produksi. Diisi Pak Wira setelah eksekusi. Semua baris harus **PASS**.
**Build:** FASE 1A + 1B (varian **TANPA tabel** — freeze via guard `hpp=0`). File: `n_cst_closing_stock.sru`, `w_refresh_transaksi_modern.srw`, `w_refresh_journal.srw`.
**Tanggal uji:** __________  **Diuji oleh:** __________  **Lingkungan:** [ ] non-prod [ ] prod

---

## 1. Ringkasan kriteria (isi kolom Hasil)

| Kriteria | Hasil | Evidence (query/artefak) |
|---|---|---|
| **G1–G5** (semua gate detektor) | ☐ PASS / ☐ FAIL | `DETEKTOR_residu_hpp_bulanan.sql` → 0 anomaly semua gate |
| **T1–T11** (acceptance dasar) | ☐ PASS / ☐ FAIL | `ACCEPTANCE_TEST_fase1.sql` (T5,T6) + DETEKTOR (T4=G5,T7=G4) |
| **Cross-period** (refresh Jul ≠ ubah Jan; jual Jul = WIP-Out Jan) | ☐ PASS / ☐ FAIL | `ACCEPTANCE_crossperiod.sql` 3a/3b/3c = LULUS |
| **Journal Authority** (I8) | ☐ PASS / ☐ FAIL | `ACCEPTANCE_journal_authority.sql` 3a=0 baris, G3=0, G5=0 |
| **Parallel-run** (UNEXPECTED=0) | ☐ PASS / ☐ FAIL | `PARALLELRUN_classify.sql` STEP 2: `3_UNEXPECTED`=0; NON-WIP semua UNCHANGED |
| **Idempotency** (refresh #1 = #2) | ☐ PASS / ☐ FAIL | `IDEMPOTENCY_metric.sql` LAPORAN B = 0 semua kelas |
| **Scope bulanan** (tak ubah periode < M) | ☐ PASS / ☐ FAIL | `ACCEPTANCE_TEST_fase1.sql` SIGNATURE ym<M sebelum=sesudah refresh M |
| **Rollback non-prod** | ☐ PASS / ☐ FAIL | `RUNBOOK_rollback_fase1.md` skenario R-A/R-B diuji di copy DB |

---

## 2. Metrik idempotensi (bukti numerik terkuat)

Sumber: `IDEMPOTENCY_metric.sql`. Metrik = jumlah baris yang **nilai** hpp-nya berubah.

**Refresh Jan→Des #1 (PRE → P1)** — churn koreksi (informasional):
```
Rows nilai berubah (WIP-Out)  : ______
Rows nilai berubah (WIP Sale) : ______
Rows nilai berubah (Non-WIP)  : ______
```

**Refresh Jan→Des #2 (P1 → P2)** — HARUS 0 (idempotent):
```
Rows nilai berubah (WIP-Out)  : ______   (target 0)
Rows nilai berubah (WIP Sale) : ______   (target 0)
Rows nilai berubah (Non-WIP)  : ______   (target 0)
```
> Bila pass #2 masih ada baris berubah: lampirkan LAPORAN C (drill) + penjelasan mengapa **tidak** mengubah nilai bisnis (mis. pembaruan teknis nilai-identik). Bila ada perubahan NILAI nyata → **FAIL**.

---

## 3. Kriteria ACC Produksi (semua wajib terpenuhi)
- [ ] DETEKTOR G1–G5 = 0 anomaly.
- [ ] Semua acceptance (termasuk cross-period & journal authority) = PASS.
- [ ] Parallel-run: UNEXPECTED = 0 (NON-WIP identik; WIP hanya → WIP-Out).
- [ ] Refresh #2 tidak mengubah **nilai** (idempotent); bila ada update, terdokumentasi tak mengubah hasil bisnis.
- [ ] Rollback berhasil diuji di non-produksi.

**Keputusan reviewer (design authority):** ☐ ACC PRODUKSI ☐ TAHAN — catatan: ________________
**Tanda tangan / tanggal:** ________________

---

## 4. Setelah stabil — FASE 2 (wajib, jangan tertunda permanen)
- [ ] Hapus blok R6 & R7 + instance var `ib_nvo_sole_hpp_authority` di **`w_refresh_transaksi_modern.srw`**.
- [ ] Hapus blok R6 & R7 + `ib_nvo_sole_hpp_authority` di **`w_refresh_journal.srw`**.
- [ ] (Opsional) hard-deprecate `w_refresh_journal` (peringatan/redirect ke Modern).
- [ ] Build + verifikasi G1–G5 tetap 0.
> Jangan biarkan flag verifikasi menjadi kode produksi permanen.
