# DEPLOY RUNBOOK — Dashboard Rekonsiliasi (ASA9 / vspnew)

Objek DB + menu. Jalankan lewat **dbisql** yang terhubung ke target. Urutan: **LOCAL dulu → validasi → PROD**.

- **LOCAL** = `C:\BTV\vspnew.db` (server `dbsrv9` lokal yang sedang jalan / atau start sendiri).
- **PROD** = `vspnew` @ 103.233.89.43:2638.
- Semua skrip ASA9, read-only kecuali CREATE/INSERT yang disebut. **Backup PROD dulu** sebelum langkah PROD.

---

## A. DEPLOY OBJEK (LOCAL, DB kosong dari objek rekon)

Jalankan berurutan di dbisql (LOCAL):

1. **`rekon_finalization_layer.sql`** — membuat:
   - `rekon_account_map` (+ index) dan migrasi isi dari `gl_setup`/`im_product_group`
   - base views: `v_gl_mutasi_bulan`, `v_gl_opening_tahun`, `v_stok_saldo_periode`, `v_ap_sisa_vendor`, `v_ar_sisa_cust`
   - (GATE queries TASK4 = untuk validasi, boleh dilewati saat deploy)
   - index TASK5.1
   > Snapshot di file ini sudah dinonaktifkan (dibuat di file berikut).

2. **`rekon_production_impl.sql`** — membuat:
   - index tambahan (Section 1.1) + tabel **`rekon_snapshot_v2`** (Section 1.2)
   - final views: `v_rekon_stok_final`, `v_rekon_ap_final`, `v_rekon_ar_final`, `v_rekon_gl_bridge`, `v_rekon_summary_kpi`
   - `sp_rekon_anomali` (Section 3), `sp_rekon_snapshot_build` (Section 5)
   > **Catatan eksekusi ASA9:** blok GATE (Section 4) dan R11 detector (TASK6) memakai `:arg_*` — itu contoh query, JANGAN dijalankan saat CREATE. Jalankan hanya CREATE VIEW/TABLE/PROCEDURE/INDEX. Set command separator dbisql ke `;` dan untuk CREATE PROCEDURE gunakan pemisah yang benar (di dbisql: jalankan tiap CREATE PROCEDURE sebagai satu batch, atau ubah delimiter).

3. **Bangun snapshot 1 periode baseline:**
   ```sql
   CALL sp_rekon_snapshot_build(2026, 4);
   COMMIT;
   ```

### A.1 WAJIB — cek `effective_from` map (gotcha kritis)
Setelah migrasi map, PASTIKAN `effective_from` = 1900-01-01. Bila migrasi lama memakai
`gl_setup.tgl_start` (mis. 2026-05-31), SEMUA data sebelum tanggal itu ter-filter keluar
→ view/snapshot KOSONG. Cek & perbaiki:
```sql
SELECT effective_from, count(*) FROM rekon_account_map GROUP BY effective_from;
UPDATE rekon_account_map SET effective_from='1900-01-01' WHERE effective_from > '1900-01-01';
COMMIT;
```
(Source `rekon_finalization_layer.sql` sudah dipatch memakai literal '1900-01-01'.)

---

## STATUS DEPLOY
- **LOCAL (vspnew @ ENG=vsp)** — ✅ SELESAI (2026-07): 24 map, 10 view, 2 proc, snapshot 2026-04
  (AP sub 8.238.241.410,02 · AR sub 19.658.007.939,85 · STOK sub 20.424.757.435,10),
  menu grup `61` REKONSILIASI (3 item). GATE2=FAIL = benar (DP gap + MAT terdeteksi).
- **PROD (103.233.89.43:2638)** — ⏳ pending (butuh koneksi PROD).

---

## B. VALIDASI (LOCAL)

Jalankan **`rekon_deployment_validation.sql`** bagian:
- TASK1.1 → harus 14 objek OK
- TASK1.6 → 0 voucher unresolved
- GATE A (`:arg_thn=2026,:arg_bln=4`) → 0 baris
- GATE C1–C4 → 0 baris
- TASK4.1 → 0 index hilang
- TASK7.1 certification → `verdict = CERTIFIED`

Jika ada error/objek hilang → perbaiki di LOCAL dulu. **Jangan lanjut PROD** sampai LOCAL bersih.

## C. DEPLOY OBJEK (PROD)  — *setelah LOCAL lulus*

> Di PROD, `rekon_account_map` **sudah ada** (24 baris dari sesi sebelumnya).

1. **`rekon_finalization_layer.sql`**:
   - `CREATE TABLE rekon_account_map` + 2 index → **akan error "already exists"** → **LEWATI** (normal).
   - migrasi INSERT (TASK2) → aman (ter-guard `NOT EXISTS`, no-op).
   - **base views (TASK3)** → jalankan (ini yang belum ada di PROD).
   - index TASK5.1 → jalankan; yang sudah ada akan error → lewati per-index.
2. **`rekon_production_impl.sql`** → jalankan penuh (final views, SP, snapshot, index).
3. `CALL sp_rekon_snapshot_build(2026, 4); COMMIT;`
4. Validasi PROD = ulangi bagian **B** → `CERTIFIED`.

## D. MENU (`sysleftmenu`) — LOCAL lalu PROD

Jalankan **`deploy_menu_rekon.sql`**:
1. LANGKAH 1: lihat `groupid`/`itemparentid` existing.
2. Isi `<GROUPID>`/`<GROUPDESC>` sesuai konvensi menu Anda (mis. group modul yang relevan), `windowobject='w_rekon_dashboard'`.
3. `COMMIT;`
4. Buka aplikasi → menu kiri harus muncul "Dashboard Rekonsiliasi" → klik = `Open(w_rekon_dashboard)`.

## E. Objek PB (sudah diimport)
`pb_rekon/` (8 DW + 7 window) → import → full build → sudah bersih (warning C0210 diperbaiki). Menu memanggil `w_rekon_dashboard`.

---

## Ringkasan urutan singkat
```
LOCAL: finalization.sql -> production_impl.sql -> build_snapshot -> VALIDASI(CERTIFIED)
PROD : finalization.sql(skip map CREATE) -> production_impl.sql -> build_snapshot -> VALIDASI(CERTIFIED)
MENU : deploy_menu_rekon.sql (LOCAL, lalu PROD)
```
