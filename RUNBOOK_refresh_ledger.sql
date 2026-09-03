-- ============================================================
-- RUNBOOK: refresh_ledger (audit trail tiap refresh) — P3 hardening
-- Objek baru, non-destruktif. Jalankan di dbisql SEBELUM build PB yang mengisinya.
-- ============================================================
CREATE TABLE refresh_ledger (
  refresh_id      integer      DEFAULT AUTOINCREMENT,
  user_id         varchar(30),
  periode         char(7),        -- 'YYYY-MM'
  tanggal_mulai   date,
  tanggal_selesai date,
  modul           varchar(20),    -- SO/PO/NONITEM/EXP/AR/AP/ADJ/CONSOUT/CONSIN
  ts_start        timestamp,
  ts_end          timestamp,
  rows_deleted    integer,
  rows_inserted   integer,
  delta_gl_debet  numeric(20,2),
  delta_gl_kredit numeric(20,2),
  delta_stok      numeric(20,2),
  status          varchar(10),    -- SUCCESS / FAIL / ROLLBACK
  error_message   varchar(400),
  created_at      timestamp DEFAULT current timestamp,
  PRIMARY KEY (refresh_id)
);
COMMIT;
-- Cara isi (di PB, tiap of_refresh_*): INSERT baris di awal (ts_start, rows sebelum),
-- UPDATE di akhir (ts_end, rows sesudah, delta, status). Gunakan f_log yang sudah ada + angka delta.
