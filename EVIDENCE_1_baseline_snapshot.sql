-- =====================================================================
-- EVIDENCE #1  BASELINE SNAPSHOT   (ASA9 / SQL Anywhere 9, dbisql 32-bit)
-- Jalankan di DB COPY, SETELAH refresh+close dgn kode LAMA (baseline bersih),
-- SEBELUM menerapkan patch moving-average fallback.
-- Sintaks ASA9: tanpa CTE, pakai SELECT..INTO + BEGIN/EXECUTE IMMEDIATE utk drop.
-- =====================================================================

-- ---------- 0) KONFIG PERIODE (satu tempat, dibaca semua script) ----------
BEGIN
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_cfg') THEN EXECUTE IMMEDIATE 'DROP TABLE _cfg'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_evap_stok') THEN EXECUTE IMMEDIATE 'DROP TABLE _evap_stok'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_pre_meta') THEN EXECUTE IMMEDIATE 'DROP TABLE _pre_meta'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_pre_tsales2_hpp') THEN EXECUTE IMMEDIATE 'DROP TABLE _pre_tsales2_hpp'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_pre_gl402') THEN EXECUTE IMMEDIATE 'DROP TABLE _pre_gl402'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_pre_sinv_evap') THEN EXECUTE IMMEDIATE 'DROP TABLE _pre_sinv_evap'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_pre_titipan_102020') THEN EXECUTE IMMEDIATE 'DROP TABLE _pre_titipan_102020'; END IF;
END;

-- >>> EDIT periode uji di sini SAJA <<<
SELECT CAST('2026-06-01' AS date) AS p1,        -- awal window uji
       CAST('2026-08-01' AS date) AS p2,        -- akhir (eksklusif)
       CAST('2026-07-01' AS date) AS close1,    -- SINV closing bln-1 (Juni)
       CAST('2026-08-01' AS date) AS close2,    -- SINV closing bln-2 (Juli)
       CAST('101' AS char(3))     AS site,
       CAST('102-020' AS char(7)) AS titipan_acc,
       CAST('2026-01-01' AS date) AS opening_period
INTO _cfg FROM SYS.DUMMY;

-- ---------- 1) daftar produk EVAP (dipakai lintas-script) ----------
SELECT DISTINCT stok_id INTO _evap_stok
FROM tsales2 WHERE ISNULL(evap,'') <> '';

-- ---------- 2) meta / timestamp eksekusi ----------
SELECT getdate() AS snapshot_time, 'BASELINE pre-patch' AS note INTO _pre_meta FROM SYS.DUMMY;

-- ---------- 3) snapshot HPP baris jual (yg akan berubah) ----------
SELECT a.bukti_id, b.urut, b.stok_id, ISNULL(b.evap,'') AS evap,
       CAST(ISNULL(b.qty,0)  AS numeric(18,2)) AS qty,
       CAST(ISNULL(b.hpp,0)  AS numeric(18,2)) AS hpp,
       a.tgl, a.tipe_trans
INTO _pre_tsales2_hpp
FROM tsales1 a, tsales2 b
WHERE a.bukti_id=b.bukti_id
  AND a.tgl >= (SELECT p1 FROM _cfg) AND a.tgl < (SELECT p2 FROM _cfg)
  AND a.tipe_trans IN ('22','32','26','36','88');

-- ---------- 4) snapshot GL agregat per akun/modul/bulan (COGS, titipan, persediaan) ----------
SELECT account_id, modul_id, YEAR(tgl) AS thn, MONTH(tgl) AS bln,
       CAST(SUM(debet) AS numeric(18,2))  AS tot_debet,
       CAST(SUM(kredit) AS numeric(18,2)) AS tot_kredit
INTO _pre_gl402
FROM gl_journal
WHERE posting='P' AND tgl >= (SELECT p1 FROM _cfg) AND tgl < (SELECT p2 FROM _cfg)
GROUP BY account_id, modul_id, YEAR(tgl), MONTH(tgl);

-- ---------- 5) snapshot SINV produk EVAP (deteksi phantom saldo akhir) ----------
SELECT s.periode, s.stok_id,
       CAST(ISNULL(s.qty,0)     AS numeric(18,2)) AS qty,
       CAST(ISNULL(s.nilai,0)   AS numeric(18,2)) AS nilai,
       CAST(ISNULL(s.hpp_avg,0) AS numeric(18,2)) AS hpp_avg
INTO _pre_sinv_evap
FROM sinv s
WHERE s.stok_id IN (SELECT stok_id FROM _evap_stok)
  AND s.periode >= (SELECT close1 FROM _cfg) AND s.periode <= (SELECT close2 FROM _cfg);

-- ---------- 6) snapshot Titipan 102-020 (saldo berjalan) ----------
SELECT (SELECT titipan_acc FROM _cfg) AS account_id,
  CAST((SELECT ISNULL(SUM(AmountDebet-AmountCredit),0) FROM gl_balance
        WHERE site_id=(SELECT site FROM _cfg) AND Period=(SELECT opening_period FROM _cfg)
          AND AccountCode=(SELECT titipan_acc FROM _cfg)) AS numeric(18,2)) AS opening,
  CAST((SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal
        WHERE posting='P' AND account_id=(SELECT titipan_acc FROM _cfg) AND tgl < (SELECT p2 FROM _cfg)) AS numeric(18,2)) AS ytd_mutasi
INTO _pre_titipan_102020 FROM SYS.DUMMY;

-- ---------- konfirmasi ----------
SELECT (SELECT snapshot_time FROM _pre_meta)         AS snapshot_time,
       (SELECT COUNT(*) FROM _pre_tsales2_hpp)       AS n_hpp_rows,
       (SELECT COUNT(*) FROM _pre_gl402)             AS n_gl_rows,
       (SELECT COUNT(*) FROM _pre_sinv_evap)         AS n_sinv_evap_rows,
       (SELECT COUNT(*) FROM _evap_stok)             AS n_evap_produk;
