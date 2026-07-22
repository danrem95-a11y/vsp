# RUNBOOK: Code-tuning f_transfer_* (result-identical) + index doc_reff

Tujuan: hilangkan **full-scan gl_journal (605rb baris) per-order** di modul refresh (NONITEM masih ~300 dtk
walau index voucher/voucher_manual sudah ada). Akar: SQL memakai pola yang **mematikan index**.

> Aturan Anda: SQL berubah WAJIB divalidasi **selisih=0** dulu. Perubahan di bawah **result-identical
> (terbukti)**, tapi tetap jalankan harness §3 sebelum dianggap final. Auto-mode SENGAJA menolak menimpa
> file produksi ini — Anda yang terapkan di PB IDE (edit SQL fungsinya) lalu re-import.

---

## 1. INDEX (di RUNBOOK_refresh_tuning.sql — pastikan sudah ada)
```sql
CREATE INDEX idx_glj_docreff ON gl_journal (doc_reff);   -- KRITIS, tadi terlewat
```
`doc_reff` dipakai delete+update per-order di f_transfer_po/ar/ap/hpp/nonitem/ekspedisi/adj. Tanpa index = full-scan.

---

## 2. REWRITE SQL (edit di PB IDE, per fungsi)

### Pola A — `left(voucher,N) = :var`  ➜  `voucher like :var || '%'`
Kenapa identik: `left(voucher,6)='PO2604'` ≡ voucher yang 6 char awalnya 'PO2604' ≡ `voucher like 'PO2604%'`
(prefix tak mengandung wildcard). `max(right(voucher,4))` tak terpengaruh. Efek: pakai `idx_glj_voucher` (range scan)
alih-alih full-scan — dan ini dijalankan **tiap generate voucher** di semua modul.

### Pola B — `isnull(doc_reff,'') = :var`  ➜  `doc_reff = :var`
Kenapa identik: `:var` = order_client (SELALU non-kosong). Baris doc_reff NULL tak match di kedua versi
(isnull→'' ≠ order; doc_reff=NULL → UNKNOWN). Efek: pakai `idx_glj_docreff`. (JANGAN ubah `isnull(doc_reff,'')=''`
— itu cek beda, untuk NULL/kosong; biarkan.)

### Daftar perubahan per fungsi (baris yang diedit)
| Fungsi | Ubah |
|--------|------|
| f_transfer_po | `left(voucher,6)=:ls_voucher` → `voucher like :ls_voucher \|\| '%'` |
| f_transfer_nonitempo | `isnull(doc_reff,'')=:arg_order_client` → `doc_reff=:arg_order_client` (delete PO) **dan** `left(voucher,6)` → like |
| f_transfer_ekspedisi | `isnull(doc_reff,'')=:arg_order_client` → `doc_reff=...` (delete EX) **dan** `left(voucher,6)` → like |
| f_transfer_ar | `left(voucher,6)` → like (2x). (baris `isnull(doc_reff,'')=:ls_link` = KOMENTAR, abaikan) |
| f_transfer_ap | `left(voucher,6)` → like (2x) |
| f_transfer_adjustment | `isnull(doc_reff,'')=:arg_order_client` → `doc_reff=...` **dan** `left(voucher,6)` → like |
| f_transfer_hpp | `left(voucher,6)` → like |
| f_transfer_dpkomisi | `left(voucher,9)=:ls_kode` → `voucher like :ls_kode \|\| '%'` (2x) **dan** `isnull(doc_reff,'')=:ls_reff` → `doc_reff=:ls_reff` (2x) |
| f_transfer_so, f_transfer_cons | sudah `where voucher=:x` (idx_glj_voucher) — **tak perlu diubah** |

(Versi hasil-rewrite ada di scratchpad `tuned/*.new` untuk pembanding diff.)

---

## 3. HARNESS VALIDASI (selisih=0) — WAJIB sebelum dipercaya
1. Pilih 1 periode uji (mis. April 2026). Snapshot SEBELUM:
```sql
SELECT modul_id, count(*) n, sum(debet) d, sum(kredit) k FROM gl_journal
 WHERE tgl BETWEEN '2026-04-01' AND '2026-04-30' GROUP BY modul_id ORDER BY modul_id;
-- catat juga hash per voucher:
SELECT voucher, sum(debet) d, sum(kredit) k FROM gl_journal
 WHERE tgl BETWEEN '2026-04-01' AND '2026-04-30' GROUP BY voucher ORDER BY voucher;
```
2. Terapkan index doc_reff + rewrite, re-import fungsi, **refresh periode uji**.
3. Snapshot SESUDAH (query sama) → **bandingkan**. Harus:
   - count / sum(debet) / sum(kredit) per modul **IDENTIK**
   - per-voucher **IDENTIK**
   - `selisih = 0` (kecuali closing R/L, yang di luar refresh)
4. Ukur waktu: `SELECT modul, duration_sec FROM refresh_jurnal_log ORDER BY id DESC;`
   Target NONITEM: ~300 dtk → **beberapa detik**.

## 4. ROLLBACK
Backup fungsi ada di scratchpad `srf_bak/` (belum tersentuh — auto-mode menolak overwrite). Atau `git checkout -- f_transfer_*.srf`.
Index: `DROP INDEX gl_journal.idx_glj_docreff;`
