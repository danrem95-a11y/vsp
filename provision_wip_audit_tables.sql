-- ============================================================================
-- provision_wip_audit_tables.sql -- DEPLOYMENT ONE-TIME (jalankan SEKALI sebelum build baru live)
-- Membuat 3 tabel audit yang dipakai n_cst_closing_stock.sru (tier-3 fallback + gate wajib + detail).
-- Tidak menyentuh tabel bisnis manapun. Aman dijalankan di prod (DDL murni, tanpa data existing).
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM SYS.SYSTABLE WHERE table_name='wip_out_cost_log') THEN
CREATE TABLE wip_out_cost_log (
    log_id              INTEGER DEFAULT AUTOINCREMENT PRIMARY KEY,
    tgl_log             TIMESTAMP DEFAULT CURRENT TIMESTAMP,
    user_refresh        VARCHAR(50),
    bukti_id            VARCHAR(20),
    stok_id             VARCHAR(20),
    evap                VARCHAR(30),
    qty                 NUMERIC(14,2),
    hpp_lama            NUMERIC(18,4),
    hpp_final           NUMERIC(18,4),
    nilai_gl            NUMERIC(20,2),
    nilai_mutasi_lama   NUMERIC(20,2),
    selisih_sebelum     NUMERIC(20,2),
    sumber              VARCHAR(30)
)
END IF;

IF NOT EXISTS (SELECT 1 FROM SYS.SYSTABLE WHERE table_name='wip_out_gate_result') THEN
CREATE TABLE wip_out_gate_result (
    result_id       INTEGER DEFAULT AUTOINCREMENT PRIMARY KEY,
    tgl_check       TIMESTAMP DEFAULT CURRENT TIMESTAMP,
    periode_from    DATE,
    periode_to      DATE,
    account_id      VARCHAR(15),
    wip_out_mutasi  NUMERIC(20,2),
    wip_out_gl      NUMERIC(20,2),
    selisih         NUMERIC(20,2),
    status          VARCHAR(10)
)
END IF;

IF NOT EXISTS (SELECT 1 FROM SYS.SYSTABLE WHERE table_name='wip_out_gate_detail') THEN
CREATE TABLE wip_out_gate_detail (
    detail_id       INTEGER DEFAULT AUTOINCREMENT PRIMARY KEY,
    tgl_check       TIMESTAMP DEFAULT CURRENT TIMESTAMP,
    periode_from    DATE,
    periode_to      DATE,
    account_id      VARCHAR(15),
    bukti_id        VARCHAR(20),
    item_id         VARCHAR(20),
    mutasi          NUMERIC(20,2),
    gl              NUMERIC(20,2),
    selisih         NUMERIC(20,2)
)
END IF;

COMMIT;

-- Verifikasi:
SELECT table_name FROM SYS.SYSTABLE WHERE table_name IN ('wip_out_cost_log','wip_out_gate_result','wip_out_gate_detail');
