-- RUNBOOK: Tambah kolom nomor seri ke TSTOK2 (detail Pembelian)
-- Tujuan: menyamakan skema TSTOK2 dengan TSALES2 agar dw_beli_entry12
--         (form Pembelian) bisa menyimpan No. Seri (EVAP), Kondisi,
--         Chasis, dan Engine -- sama seperti yang sudah ada di
--         dw_cons_entry12 (form WIP-Out / Konsinyasi Keluar).
--
-- Status: SUDAH DIEKSEKUSI & DIVERIFIKASI di prod (103.233.89.43 / vspnew)
--         pada sesi sebelumnya. Script ini murni ADDITIVE (ALTER TABLE ADD
--         COLUMN ... NULL) -- tidak menyentuh data lama, tidak butuh downtime.
--
-- Verifikasi (SYSCOLUMN) terakhir: 2026-11-04
--   CHASIS | width=50 | nulls=Y
--   COND   | width=20 | nulls=Y
--   ENGINE | width=50 | nulls=Y
--   EVAP   | width=20 | nulls=Y
--
-- CATATAN: Jika dijalankan ulang di database yang SUDAH punya kolom ini,
-- ALTER TABLE ADD akan ERROR ("column already exists"). Cek dulu dengan
-- query verifikasi di bagian bawah sebelum eksekusi, terutama kalau mau
-- dipakai di environment lain (misal DB lokal/dev yang belum di-sync).

ALTER TABLE TSTOK2 ADD EVAP   char(20) NULL;
ALTER TABLE TSTOK2 ADD COND   char(20) NULL;
ALTER TABLE TSTOK2 ADD CHASIS char(50) NULL;
ALTER TABLE TSTOK2 ADD ENGINE char(50) NULL;
commit;

-- Query verifikasi (jalankan setelah ALTER TABLE untuk konfirmasi):
-- SELECT c.column_name, c.width, c.nulls
-- FROM SYSCOLUMN c, SYSTABLE t
-- WHERE c.table_id = t.table_id
--   AND t.table_name = 'TSTOK2'
--   AND c.column_name IN ('EVAP','COND','CHASIS','ENGINE')
-- ORDER BY c.column_name;
