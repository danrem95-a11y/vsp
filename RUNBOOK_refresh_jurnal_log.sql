-- ============================================================================
-- RUNBOOK: Tabel log Refresh Transaksi + kandidat index (SQL Anywhere 9)
-- Jalankan di dbisql (32-bit ODBC DSN=vsp, dba/jakarta) ATAU dbeng9 -ti 0 offline.
-- AMAN / non-destruktif. Bagian INDEX: cek dulu index eksisting sebelum dibuat.
-- Konteks: modul w_refresh_transaksi_modern (lihat design_refresh_transaksi_modern.md)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) TABEL LOG  (aman dijalankan; kalau sudah ada, abaikan error "already exists")
-- ---------------------------------------------------------------------------
CREATE TABLE refresh_jurnal_log (
   id             INTEGER      NOT NULL DEFAULT AUTOINCREMENT,
   tgl            TIMESTAMP    DEFAULT CURRENT TIMESTAMP,
   user_id        VARCHAR(20),
   modul          VARCHAR(15),          -- SO/PO/NONITEM/EXP/AR/AP/ADJ/CONSOUT/CONSIN
   periode_awal   DATE,
   periode_akhir  DATE,
   start_time     TIMESTAMP,
   end_time       TIMESTAMP,
   duration_sec   INTEGER,
   jumlah_data    INTEGER,
   status         VARCHAR(10),          -- RUNNING / SUCCESS / ERROR
   error_message  LONG VARCHAR,
   PRIMARY KEY (id)
);

CREATE INDEX idx_refresh_log_tgl ON refresh_jurnal_log (tgl);
COMMIT;

-- Cara pakai dari PowerBuilder (dipakai of_log_start / of_log_end):
--   START : INSERT INTO refresh_jurnal_log
--             (user_id,modul,periode_awal,periode_akhir,start_time,status)
--           VALUES (:gs_user,:as_modul,:ldt1,:ldt2, CURRENT TIMESTAMP,'RUNNING');
--           SELECT @@identity INTO :il_log_id;          -- ambil id baris
--   END   : UPDATE refresh_jurnal_log
--             SET end_time=CURRENT TIMESTAMP,
--                 duration_sec=DATEDIFF(second,start_time,CURRENT TIMESTAMP),
--                 jumlah_data=:al_count, status=:as_status, error_message=:as_err
--           WHERE id=:il_log_id;

-- ---------------------------------------------------------------------------
-- 2) CEK INDEX EKSISTING DULU (jangan buat duplikat)
--    ASA9: pakai VIEW kompatibilitas SYS.SYSINDEXES (BUKAN sys.sysindex;
--    kolom index_category baru ada di ASA10/11+). SYSINDEXES sudah memberi
--    nama tabel (fname), nama index (iname), tipe (indextype), dan daftar
--    kolom (colnames) sekaligus -- tanpa join.
-- ---------------------------------------------------------------------------
SELECT fname AS tabel, iname AS index_name, indextype, colnames
FROM   SYS.SYSINDEXES
WHERE  fname IN ('gl_journal','tbyr1','tbyr2','ar_trans','ap_trans',
                 'tsales1','tsales2','tstok1','tstok2','sinv')
ORDER  BY fname, iname;

-- Kalau nama kolom view berbeda di build Anda, lihat semua kolomnya dulu:
--   SELECT * FROM SYS.SYSINDEXES WHERE fname = 'gl_journal';
-- Atau tanpa SQL: Sybase Central > (tabel) > tab Indexes.

-- ---------------------------------------------------------------------------
-- 3) KANDIDAT INDEX (dari SQL nyata di window) -- FASE 2, jalankan SATU-SATU
--    HANYA setelah: (a) cek belum ada di langkah #2, (b) benchmark before,
--    (c) validasi hasil selisih=0 (lihat design doc bagian 4).
--    Nama index diberi prefix idx_rtx_ agar mudah di-drop bila perlu.
-- ---------------------------------------------------------------------------
-- gl_journal: dipakai berulang (rebuild AR/AP, subquery yatim, clear memo)
-- CREATE INDEX idx_rtx_glj_vman   ON gl_journal (voucher_manual);
-- CREATE INDEX idx_rtx_glj_vurut  ON gl_journal (voucher, urut);
-- CREATE INDEX idx_rtx_glj_tgl    ON gl_journal (tgl);

-- tbyr1 / tbyr2: rebuild + patch yatim + backup copy
-- CREATE INDEX idx_rtx_tbyr1_tgl  ON tbyr1 (tgl, kas_id);
-- CREATE INDEX idx_rtx_tbyr1_vman ON tbyr1 (voucher_manual);
-- CREATE INDEX idx_rtx_tbyr1_vc   ON tbyr1 (voucher);
-- CREATE INDEX idx_rtx_tbyr2_vc   ON tbyr2 (voucher);
-- CREATE INDEX idx_rtx_tbyr2_buk  ON tbyr2 (bukti_id);

-- ar_trans / ap_trans: SELECT-per-row (cust_id/vendor_id/curr_id)
-- CREATE INDEX idx_rtx_ar_ordcl   ON ar_trans (order_client);
-- CREATE INDEX idx_rtx_ap_ordcl   ON ap_trans (order_client);

-- UPDATE HPP average (cb_9 SO)
-- CREATE INDEX idx_rtx_ts1_tgloke ON tsales1 (tgl, order_oke, tipe_trans);
-- CREATE INDEX idx_rtx_tk1_tgloke ON tstok1  (tgl, order_oke);
-- COMMIT;

-- ---------------------------------------------------------------------------
-- 4) STATISTICS (aman, non-destruktif) -- refresh sebelum benchmark
-- ---------------------------------------------------------------------------
-- CREATE STATISTICS gl_journal;
-- CREATE STATISTICS tbyr1;
-- CREATE STATISTICS tbyr2;
-- CREATE STATISTICS tsales1;
-- CREATE STATISTICS tsales2;
-- CREATE STATISTICS tstok1;
-- CREATE STATISTICS tstok2;
-- CREATE STATISTICS sinv;
