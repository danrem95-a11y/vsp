-- ============================================================================
-- REKON FINALIZATION LAYER v1.0 — ZERO HARDCODE + CONFIG-DRIVEN ENGINE
-- Target   : SQL Anywhere 9 (ASA9) + PowerBuilder 11.5
-- Depends  : rekonsiliasi_engine_vsp.md v2.0 (kontrak AP/AR/STOK/LEDGER final)
-- Grounding: gl_setup.acc_ap='226-001', acc_ar='103-001',
--            acc_biaya_ekpedisi='226-006' (= akun freight anchor AP report),
--            IM_PRODUCT_GROUP.PERSEDIAAN = daftar akun stok.
--            >>> SEMUA nilai di atas TIDAK ditulis literal di view/migration —
--                selalu dibaca dari gl_setup / im_product_group. <<<
-- Aturan   : no CTE, no window function, no SELECT *, no literal account_id.
-- ============================================================================


-- ============================================================================
-- TASK 1 — CORE CONFIG TABLE : rekon_account_map
-- Justifikasi tabel baru: satu-satunya objek konfigurasi engine (menggantikan
-- literal akun di view). Semua isinya dimigrasikan dari gl_setup /
-- im_product_group (TASK 2) — bukan input manual.
-- ============================================================================
CREATE TABLE rekon_account_map (
    domain         VARCHAR(4)   NOT NULL,   -- 'STOK' | 'AP' | 'AR'
    account_type   VARCHAR(20)  NOT NULL,   -- 'INVENTORY' | 'PAYABLE' | 'PAYABLE_FREIGHT' | 'RECEIVABLE'
    account_id     VARCHAR(20)  NOT NULL,   -- gl account code
    site_id        VARCHAR(10)  NOT NULL DEFAULT '*',  -- '*' = semua site
    is_active      CHAR(1)      NOT NULL DEFAULT 'Y',  -- 'Y'/'N'
    effective_from TIMESTAMP    NOT NULL DEFAULT '1900-01-01',
    effective_to   TIMESTAMP    NULL,                   -- NULL = open-ended
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT TIMESTAMP,
    created_by     VARCHAR(30)  NOT NULL DEFAULT CURRENT USER,
    PRIMARY KEY (domain, account_type, account_id, site_id, effective_from)
);

-- Join-performance index (account-first: dipakai filter dari sisi gl_journal)
CREATE INDEX idx_ram_acc_site ON rekon_account_map (account_id, site_id, is_active);
-- Domain-first index (dipakai daftar akun per domain di view)
CREATE INDEX idx_ram_domain   ON rekon_account_map (domain, is_active, account_id);


-- ============================================================================
-- TASK 2 — MIGRATION (CONFIG DIISI DARI SUMBER EXISTING, BUKAN MANUAL)
-- Idempotent: setiap INSERT dilindungi NOT EXISTS.
-- Site: memakai gl_setup.site_code bila terisi; '*' bila kosong.
-- Effective_from: SELALU '1900-01-01' (JANGAN pakai gl_setup.tgl_start — kalau
--   tgl_start = tanggal belakangan mis. 2026-05-31, data bulan sebelumnya
--   ter-filter keluar dari view; TERBUKTI bikin snapshot April kosong).
-- ============================================================================

-- 2.1  STOK / INVENTORY : seluruh akun persediaan dari IM_PRODUCT_GROUP
INSERT INTO rekon_account_map
       (domain, account_type, account_id, site_id, is_active, effective_from)
SELECT 'STOK', 'INVENTORY', g.persediaan,
       (SELECT CASE WHEN ISNULL(gs.site_code,'') = '' THEN '*'
                    ELSE gs.site_code END FROM gl_setup gs),
       'Y',
       '1900-01-01'   -- effective_from: JANGAN pakai gl_setup.tgl_start (bikin data lama ter-filter)
FROM   im_product_group g
WHERE  ISNULL(g.persediaan,'') <> ''
GROUP BY g.persediaan
HAVING NOT EXISTS (
        SELECT 1 FROM rekon_account_map m
        WHERE  m.domain = 'STOK'
          AND  m.account_type = 'INVENTORY'
          AND  m.account_id = g.persediaan );

-- 2.2  AP / PAYABLE : akun hutang utama dari gl_setup.acc_ap
INSERT INTO rekon_account_map
       (domain, account_type, account_id, site_id, is_active, effective_from)
SELECT 'AP', 'PAYABLE', gs.acc_ap,
       CASE WHEN ISNULL(gs.site_code,'') = '' THEN '*' ELSE gs.site_code END,
       'Y', '1900-01-01'
FROM   gl_setup gs
WHERE  ISNULL(gs.acc_ap,'') <> ''
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.domain='AP' AND m.account_type='PAYABLE'
                      AND m.account_id = gs.acc_ap );

-- 2.3  AP / PAYABLE_FREIGHT : akun freight-AP dari gl_setup.acc_biaya_ekpedisi
--      (report opname AP meng-anchor voucher pada acc_ap + akun ini)
INSERT INTO rekon_account_map
       (domain, account_type, account_id, site_id, is_active, effective_from)
SELECT 'AP', 'PAYABLE_FREIGHT', gs.acc_biaya_ekpedisi,
       CASE WHEN ISNULL(gs.site_code,'') = '' THEN '*' ELSE gs.site_code END,
       'Y', '1900-01-01'
FROM   gl_setup gs
WHERE  ISNULL(gs.acc_biaya_ekpedisi,'') <> ''
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.domain='AP' AND m.account_type='PAYABLE_FREIGHT'
                      AND m.account_id = gs.acc_biaya_ekpedisi );

-- 2.4  AR / RECEIVABLE : akun piutang dari gl_setup.acc_ar
INSERT INTO rekon_account_map
       (domain, account_type, account_id, site_id, is_active, effective_from)
SELECT 'AR', 'RECEIVABLE', gs.acc_ar,
       CASE WHEN ISNULL(gs.site_code,'') = '' THEN '*' ELSE gs.site_code END,
       'Y', '1900-01-01'
FROM   gl_setup gs
WHERE  ISNULL(gs.acc_ar,'') <> ''
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.domain='AR' AND m.account_type='RECEIVABLE'
                      AND m.account_id = gs.acc_ar );

-- 2.5  CANDIDATE DISCOVERY (REPORT-ONLY — TIDAK auto-insert):
--      akun lain yang secara data terikat voucher AP/AR (mis. PPN masukan,
--      potongan, uang muka). Auditor memutuskan apakah dimasukkan ke map.
--      (Data-driven classification per requirement; eksekusi saat idle.)
SELECT 'AP_CANDIDATE' AS class, gj.account_id,
       COUNT(*) AS n_baris, SUM(gj.kredit) AS total_kredit
FROM   gl_journal gj
WHERE  gj.kredit > 0 AND gj.posting = 'P'
  AND  EXISTS ( SELECT 1 FROM ap_trans p WHERE p.order_client = gj.voucher )
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.account_id = gj.account_id AND m.domain = 'AP' )
GROUP BY gj.account_id
HAVING COUNT(*) >= 5
ORDER BY total_kredit DESC;

SELECT 'AR_CANDIDATE' AS class, gj.account_id,
       COUNT(*) AS n_baris, SUM(gj.debet) AS total_debet
FROM   gl_journal gj
WHERE  gj.debet > 0 AND gj.posting = 'P'
  AND  EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client = gj.voucher )
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.account_id = gj.account_id AND m.domain = 'AR' )
GROUP BY gj.account_id
HAVING COUNT(*) >= 5
ORDER BY total_debet DESC;


-- ============================================================================
-- TASK 3 — REFACTORED VIEWS (ZERO HARDCODE, MAP-DRIVEN)
-- Pola filter map (dipakai konsisten):
--   account IN (SELECT m.account_id FROM rekon_account_map m
--               WHERE m.domain=<D> AND m.is_active='Y'
--                 AND (m.site_id='*' OR m.site_id = <site kolom>)
--                 AND <tgl kolom> >= m.effective_from
--                 AND (m.effective_to IS NULL OR <tgl kolom> <= m.effective_to))
-- ============================================================================

-- 3.A  v_gl_mutasi_bulan  (domain-aware, map-driven)
CREATE VIEW v_gl_mutasi_bulan AS
SELECT m.domain, j.account_id, j.site_id,
       YEAR(j.tgl)  AS thn,
       MONTH(j.tgl) AS bln,
       SUM(ISNULL(j.debet,0) - ISNULL(j.kredit,0)) AS mutasi
FROM   gl_journal j
JOIN   rekon_account_map m
       ON  m.account_id = j.account_id
       AND m.is_active  = 'Y'
       AND (m.site_id = '*' OR m.site_id = j.site_id)
       AND j.tgl >= m.effective_from
       AND (m.effective_to IS NULL OR j.tgl <= m.effective_to)
WHERE  j.posting = 'P'
GROUP BY m.domain, j.account_id, j.site_id, YEAR(j.tgl), MONTH(j.tgl);

-- 3.A2 v_gl_opening_tahun (map-driven)
CREATE VIEW v_gl_opening_tahun AS
SELECT m.domain, b.AccountCode AS account_id, b.site_id,
       YEAR(b.Period) AS thn,
       SUM(ISNULL(b.AmountDebet,0) - ISNULL(b.AmountCredit,0)) AS saldo_awal
FROM   gl_balance b
JOIN   rekon_account_map m
       ON  m.account_id = b.AccountCode
       AND m.is_active  = 'Y'
       AND (m.site_id = '*' OR m.site_id = b.site_id)
       AND b.Period >= m.effective_from
       AND (m.effective_to IS NULL OR b.Period <= m.effective_to)
GROUP BY m.domain, b.AccountCode, b.site_id, YEAR(b.Period);

-- 3.D  v_stok_saldo_periode (map-driven; hanya akun ber-map STOK aktif)
CREATE VIEW v_stok_saldo_periode AS
SELECT g.persediaan AS account_id, s.site_id, s.periode,
       SUM(ISNULL(s.nilai,0)) AS saldo_subledger,
       SUM(ISNULL(s.qty,0))   AS qty_subledger
FROM   sinv s
JOIN   im_produk        p ON p.produk_id  = s.stok_id
JOIN   im_product_group g ON g.kode_group = p.group_product
JOIN   rekon_account_map m
       ON  m.account_id = g.persediaan
       AND m.domain     = 'STOK'
       AND m.is_active  = 'Y'
       AND (m.site_id = '*' OR m.site_id = s.site_id)
       AND s.periode >= m.effective_from
       AND (m.effective_to IS NULL OR s.periode <= m.effective_to)
WHERE  p.stok_item = 'Y'
GROUP BY g.persediaan, s.site_id, s.periode;

-- 3.B  v_ap_sisa_vendor (ZERO HARDCODE: anchor akun dari map domain='AP')
CREATE VIEW v_ap_sisa_vendor AS
SELECT x.vendor_id, x.thn, x.bln,
       SUM(x.saf_idr) + SUM(x.inv_idr) + SUM(x.adj_idr) - SUM(x.byr_idr) AS sisa_idr
FROM (
   SELECT f.vendor_id, YEAR(f.periode) AS thn, 0 AS bln,
          SUM(CASE WHEN ISNULL(f.new_saldo,0) <> 0 THEN f.new_saldo
                   WHEN ISNULL(f.new_rate,0)  <> 0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate
                   ELSE ISNULL(f.saldo,0) END)      AS saf_idr,
          0 AS inv_idr, 0 AS adj_idr, 0 AS byr_idr
   FROM   saldo_awal_faktur f
   WHERE  f.tipe_trans IN (1,2)
     AND  MONTH(f.periode) = 1
     AND  EXISTS ( SELECT 1 FROM gl_journal gj
                   WHERE gj.voucher = f.bukti_id
                     AND gj.kredit  > 0
                     AND gj.account_id IN
                         ( SELECT m.account_id FROM rekon_account_map m
                           WHERE m.domain='AP' AND m.is_active='Y' ) )
   GROUP BY f.vendor_id, YEAR(f.periode)
   UNION ALL
   SELECT p.vendor_id, YEAR(p.tgl), MONTH(p.tgl),
          0,
          SUM(CASE WHEN p.tipe_trans = '05' THEN p.ttl_netto
                   ELSE (CASE WHEN p.tipe_trans IN ('02','06','16') THEN p.ttl_netto
                              WHEN p.tipe_trans = '12' THEN -ABS(p.ttl_netto)
                              ELSE 0 END) * ISNULL(p.kurs,1) END),
          0, 0
   FROM   ap_trans p
   WHERE  p.order_oke = 'Y'
     AND  p.tipe_trans IN ('02','05','12','06','16')
     AND  EXISTS ( SELECT 1 FROM gl_journal gj
                   WHERE gj.voucher = p.order_client
                     AND gj.kredit  > 0
                     AND gj.account_id IN
                         ( SELECT m.account_id FROM rekon_account_map m
                           WHERE m.domain='AP' AND m.is_active='Y' ) )
   GROUP BY p.vendor_id, YEAR(p.tgl), MONTH(p.tgl)
   UNION ALL
   SELECT ap.vendor_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar),
          0, 0,
          SUM(CASE WHEN tp.flag_order NOT IN (2,22) THEN ABS(tp.nilai_bayar_idr)
                   ELSE -ABS(tp.nilai_bayar_idr) END),
          0
   FROM   tbyr2_putih tp
   JOIN ( SELECT p2.order_client, MAX(p2.vendor_id) AS vendor_id
          FROM ap_trans p2
          WHERE EXISTS (SELECT 1 FROM gl_journal g4
                        WHERE g4.voucher = p2.order_client AND g4.kredit > 0
                          AND g4.account_id IN (SELECT m.account_id FROM rekon_account_map m
                                                WHERE m.domain='AP' AND m.is_active='Y'))
          GROUP BY p2.order_client ) ap
        ON ap.order_client = tp.bukti_id
   GROUP BY ap.vendor_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar)
   UNION ALL
   SELECT ap.vendor_id, YEAR(t1.tgl), MONTH(t1.tgl),
          0, 0, 0,
          SUM(ISNULL(t2.nilai_bayar_idr,0))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
   JOIN ( SELECT p2.order_client, MAX(p2.vendor_id) AS vendor_id
          FROM ap_trans p2
          WHERE EXISTS (SELECT 1 FROM gl_journal g4
                        WHERE g4.voucher = p2.order_client AND g4.kredit > 0
                          AND g4.account_id IN (SELECT m.account_id FROM rekon_account_map m
                                                WHERE m.domain='AP' AND m.is_active='Y'))
          GROUP BY p2.order_client ) ap
        ON ap.order_client = t2.bukti_id
   WHERE  t1.flag_bayar IN (1,2)
   GROUP BY ap.vendor_id, YEAR(t1.tgl), MONTH(t1.tgl)
) x
GROUP BY x.vendor_id, x.thn, x.bln;

-- 3.C  v_ar_sisa_cust (ZERO HARDCODE: anchor akun dari map domain='AR')
CREATE VIEW v_ar_sisa_cust AS
SELECT x.cust_id, x.thn, x.bln,
       SUM(x.saf_idr) + SUM(x.inv_idr) + SUM(x.adj_idr) - SUM(x.byr_idr) AS sisa_idr
FROM (
   SELECT f.vendor_id AS cust_id, YEAR(f.periode) AS thn, 0 AS bln,
          SUM(ROUND(CASE WHEN ISNULL(f.new_saldo,0) <> 0 THEN f.new_saldo
                         WHEN ISNULL(f.new_rate,0)  <> 0 THEN ISNULL(f.saldo_kurs,0)*f.new_rate
                         ELSE ISNULL(f.saldo,0) END, 2)) AS saf_idr,
          0 AS inv_idr, 0 AS adj_idr, 0 AS byr_idr
   FROM   saldo_awal_faktur f
   WHERE  f.tipe_trans = 1
     AND  MONTH(f.periode) = 1
     AND  EXISTS ( SELECT 1 FROM gl_journal gj
                   WHERE gj.voucher = f.bukti_id
                     AND gj.debet   > 0
                     AND gj.account_id IN
                         ( SELECT m.account_id FROM rekon_account_map m
                           WHERE m.domain='AR' AND m.is_active='Y' ) )
   GROUP BY f.vendor_id, YEAR(f.periode)
   UNION ALL
   SELECT ar.cust_id, YEAR(gj.tgl), MONTH(gj.tgl),
          0, SUM(gj.debet), 0, 0
   FROM   gl_journal gj
   JOIN ( SELECT a2.order_client, MAX(a2.cust_id) AS cust_id
          FROM ar_trans a2
          WHERE a2.order_oke = 'Y'
            AND a2.tipe_trans IN ('22','32','33','26','36')
          GROUP BY a2.order_client ) ar
        ON ar.order_client = gj.voucher
   WHERE  gj.debet > 0
     AND  gj.account_id IN
          ( SELECT m.account_id FROM rekon_account_map m
            WHERE m.domain='AR' AND m.is_active='Y' )
   GROUP BY ar.cust_id, YEAR(gj.tgl), MONTH(gj.tgl)
   UNION ALL
   SELECT ar.cust_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar),
          0, 0,
          SUM(CASE WHEN tp.flag_order = 11 THEN  ABS(tp.nilai_bayar_idr)
                   WHEN tp.flag_order = 1  THEN -ABS(tp.nilai_bayar_idr)
                   ELSE 0 END),
          0
   FROM   tbyr2_putih tp
   JOIN ( SELECT a2.order_client, MAX(a2.cust_id) AS cust_id
          FROM ar_trans a2 GROUP BY a2.order_client ) ar
        ON ar.order_client = tp.bukti_id
   WHERE  tp.flag_order IN (1,11)
   GROUP BY ar.cust_id, YEAR(tp.tgl_bayar), MONTH(tp.tgl_bayar)
   UNION ALL
   SELECT ar.cust_id, YEAR(t1.tgl), MONTH(t1.tgl),
          0, 0, 0,
          SUM(ISNULL(t2.nilai_bayar_idr,0))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
   JOIN ( SELECT a2.order_client, MAX(a2.cust_id) AS cust_id
          FROM ar_trans a2 GROUP BY a2.order_client ) ar
        ON ar.order_client = t2.bukti_id
   WHERE  t1.flag_bayar IN (1,2)
     AND  (t1.flag_vendor = 1 OR t1.flag_vendor IS NULL)
   GROUP BY ar.cust_id, YEAR(t1.tgl), MONTH(t1.tgl)
) x
GROUP BY x.cust_id, x.thn, x.bln;


-- ============================================================================
-- TASK 4 — VALIDATION FRAMEWORK (GATE SYSTEM)  — semua executable ASA9
-- Konvensi retrieve args PB: :arg_thn (int), :arg_bln (int)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- GATE #1 — REPORT CONSISTENCY
-- Σ view (agregat) HARUS = Σ SISA_IDR report opname (per-voucher) periode sama.
-- Query menghasilkan total view; bandingkan dgn Σ report (kolom SISA_IDR export
-- dw_rpt_ap_opname / dw_rpt_ar_opname periode identik). Selisih wajib <= 10.
-- ---------------------------------------------------------------------------
SELECT 'GATE1_AP' AS gate,
       SUM(v.sisa_idr) AS total_view_sisa_idr
FROM   v_ap_sisa_vendor v
WHERE  v.thn = :arg_thn AND v.bln <= :arg_bln;

SELECT 'GATE1_AR' AS gate,
       SUM(v.sisa_idr) AS total_view_sisa_idr
FROM   v_ar_sisa_cust v
WHERE  v.thn = :arg_thn AND v.bln <= :arg_bln;

-- ---------------------------------------------------------------------------
-- GATE #2 — GL CONSISTENCY (subledger vs ledger, per domain)
-- ---------------------------------------------------------------------------
-- 2a. STOK per akun (saldo akhir bulan = SINV periode bulan+1)
SELECT 'GATE2_STOK' AS gate,
       sub.account_id,
       ISNULL(sub.saldo_subledger,0) AS subledger_value,
       ISNULL(led.saldo_ledger,0)    AS ledger_value,
       (ISNULL(sub.saldo_subledger,0) - ISNULL(led.saldo_ledger,0)) AS selisih,
       CASE WHEN ABS(ISNULL(sub.saldo_subledger,0) - ISNULL(led.saldo_ledger,0)) <= 10
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM ( SELECT v.account_id, SUM(v.saldo_subledger) AS saldo_subledger
       FROM v_stok_saldo_periode v
       WHERE YEAR(v.periode) = CASE WHEN :arg_bln = 12 THEN :arg_thn + 1 ELSE :arg_thn END
         AND MONTH(v.periode) = CASE WHEN :arg_bln = 12 THEN 1 ELSE :arg_bln + 1 END
       GROUP BY v.account_id ) sub
LEFT OUTER JOIN
     ( SELECT o.account_id, (o.saldo_awal + ISNULL(m.mutasi_ytd,0)) AS saldo_ledger
       FROM v_gl_opening_tahun o
       LEFT OUTER JOIN ( SELECT account_id, thn, SUM(mutasi) AS mutasi_ytd
                         FROM v_gl_mutasi_bulan
                         WHERE domain='STOK' AND thn = :arg_thn AND bln <= :arg_bln
                         GROUP BY account_id, thn ) m
              ON m.account_id = o.account_id AND m.thn = o.thn
       WHERE o.domain='STOK' AND o.thn = :arg_thn ) led
       ON led.account_id = sub.account_id
ORDER BY sub.account_id;

-- 2b. AR total vs ledger (akun AR dari map, tanpa literal)
SELECT 'GATE2_AR' AS gate,
       ISNULL(sub.sisa_total,0)   AS subledger_value,
       ISNULL(led.saldo_ledger,0) AS ledger_value,
       (ISNULL(sub.sisa_total,0) - ISNULL(led.saldo_ledger,0)) AS selisih,
       CASE WHEN ABS(ISNULL(sub.sisa_total,0) - ISNULL(led.saldo_ledger,0)) <= 10
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM ( SELECT SUM(v.sisa_idr) AS sisa_total
       FROM v_ar_sisa_cust v
       WHERE v.thn = :arg_thn AND v.bln <= :arg_bln ) sub
LEFT OUTER JOIN
     ( SELECT SUM(o.saldo_awal + ISNULL(m.mutasi_ytd,0)) AS saldo_ledger
       FROM v_gl_opening_tahun o
       LEFT OUTER JOIN ( SELECT account_id, thn, SUM(mutasi) AS mutasi_ytd
                         FROM v_gl_mutasi_bulan
                         WHERE domain='AR' AND thn = :arg_thn AND bln <= :arg_bln
                         GROUP BY account_id, thn ) m
              ON m.account_id = o.account_id AND m.thn = o.thn
       WHERE o.domain='AR' AND o.thn = :arg_thn ) led ON 1=1;

-- 2c. AP total vs ledger (liability: ledger kredit → bandingkan dgn -saldo)
SELECT 'GATE2_AP' AS gate,
       ISNULL(sub.sisa_total,0)    AS subledger_value,
       -ISNULL(led.saldo_ledger,0) AS ledger_value_abs,
       (ISNULL(sub.sisa_total,0) + ISNULL(led.saldo_ledger,0)) AS selisih,
       CASE WHEN ABS(ISNULL(sub.sisa_total,0) + ISNULL(led.saldo_ledger,0)) <= 10
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM ( SELECT SUM(v.sisa_idr) AS sisa_total
       FROM v_ap_sisa_vendor v
       WHERE v.thn = :arg_thn AND v.bln <= :arg_bln ) sub
LEFT OUTER JOIN
     ( SELECT SUM(o.saldo_awal + ISNULL(m.mutasi_ytd,0)) AS saldo_ledger
       FROM v_gl_opening_tahun o
       LEFT OUTER JOIN ( SELECT account_id, thn, SUM(mutasi) AS mutasi_ytd
                         FROM v_gl_mutasi_bulan
                         WHERE domain='AP' AND thn = :arg_thn AND bln <= :arg_bln
                         GROUP BY account_id, thn ) m
              ON m.account_id = o.account_id AND m.thn = o.thn
       WHERE o.domain='AP' AND o.thn = :arg_thn ) led ON 1=1;

-- ---------------------------------------------------------------------------
-- GATE #3 — MAPPING INTEGRITY
-- ---------------------------------------------------------------------------
-- 3a. Akun persediaan (im_product_group) yang BELUM ter-map → wajib kosong
SELECT 'GATE3_STOK_UNMAPPED' AS gate, g.persediaan AS account_id, COUNT(*) AS n_group
FROM   im_product_group g
WHERE  ISNULL(g.persediaan,'') <> ''
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.domain='STOK' AND m.account_id = g.persediaan
                      AND m.is_active='Y' )
GROUP BY g.persediaan;

-- 3b. Akun GL ber-aktivitas AP/AR-anchored yang belum ter-map (kandidat/orphan)
--     (= query discovery TASK 2.5; wajib direview auditor, hasil ideal: kosong
--      atau semuanya berstatus keputusan-sadar "tidak termasuk rekonsiliasi")
-- 3c. Map row yang TIDAK pernah muncul di GL (stale mapping) → review
SELECT 'GATE3_STALE_MAP' AS gate, m.domain, m.account_id
FROM   rekon_account_map m
WHERE  m.is_active = 'Y'
  AND  NOT EXISTS ( SELECT 1 FROM gl_journal j
                    WHERE j.account_id = m.account_id )
  AND  NOT EXISTS ( SELECT 1 FROM gl_balance b
                    WHERE b.AccountCode = m.account_id );

-- 3d. Duplikasi mapping aktif yang tumpang-tindih periode (harus kosong)
SELECT 'GATE3_OVERLAP' AS gate,
       a.domain, a.account_id, a.site_id,
       a.effective_from AS from_a, b.effective_from AS from_b
FROM   rekon_account_map a
JOIN   rekon_account_map b
       ON  b.domain = a.domain
       AND b.account_type = a.account_type
       AND b.account_id = a.account_id
       AND b.site_id = a.site_id
       AND b.effective_from > a.effective_from
WHERE  a.is_active='Y' AND b.is_active='Y'
  AND  (a.effective_to IS NULL OR b.effective_from <= a.effective_to);


-- ============================================================================
-- TASK 5 — PERFORMANCE (FINAL HARDENING)
-- ============================================================================
-- 5.1 Index inti (cek existing dulu; buat saat idle — aplikasi memegang
--     SHARE lock luas yang dapat memblok DDL)
CREATE INDEX idx_gljrn_acc_tgl_post ON gl_journal(account_id, tgl, posting);
CREATE INDEX idx_gljrn_voucher      ON gl_journal(voucher);
CREATE INDEX idx_sinv_per_stok      ON sinv(periode, stok_id);
CREATE INDEX idx_saf_bukti          ON saldo_awal_faktur(bukti_id, tipe_trans);
CREATE INDEX idx_aptrans_order      ON ap_trans(order_client, tipe_trans, tgl);
CREATE INDEX idx_artrans_order      ON ar_trans(order_client, tipe_trans, tgl);
CREATE INDEX idx_tbyr2_bukti        ON tbyr2(bukti_id);
CREATE INDEX idx_tbyr1_voucher      ON tbyr1(voucher, flag_bayar, tgl);
CREATE INDEX idx_tbyr2p_bukti       ON tbyr2_putih(bukti_id, tgl_bayar);

-- 5.2 Anti full-scan:
--   * SEMUA filter akun via idx_ram_acc_site (map kecil, nested-loop murah).
--   * gl_journal selalu difilter account_id+tgl+posting (pakai idx 5.1).
--   * Larangan: '*=', NOT IN(subselect berkonkatenasi), fungsi di kolom
--     ter-index pada predikat (YEAR(tgl) di WHERE besar → gunakan rentang tgl
--     bila memungkinkan; view bulanan di sini beragregasi sekali lalu di-cache
--     optimizer per statement).
--   * Retrieve dashboard TIDAK memanggil view berat langsung → baca snapshot.

-- 5.3 Snapshot v2 — DINONAKTIFKAN DI SINI (di-supersede oleh rekon_production_impl.sql).
--   Tabel FINAL rekon_snapshot_v2 = versi DOMAIN-LEVEL (periode,domain,subledger_total,
--   ledger_total,selisih,gate1/2/3_status,created_at) + loader sp_rekon_snapshot_build,
--   dibuat di rekon_production_impl.sql Section 1.2 & Section 5. JANGAN buat versi
--   account-level di bawah ini agar tak bentrok. (Blok lama disimpan sbg komentar.)
-- ---------------------------------------------------------------------------------
-- CREATE TABLE rekon_snapshot_v2 ( thn INTEGER, bln INTEGER, site_id ..., account_id,
--   subledger_value, ledger_value, selisih, status, gate1_pass, gate2_pass, ... );
-- CREATE INDEX idx_snapv2_status ON rekon_snapshot_v2 (thn, bln, status);
-- (loader account-level STOK) -> diganti sp_rekon_snapshot_build (domain-level).

-- ============================================================================
-- DEPLOY ORDER (wajib urut):
--   1) TASK1 DDL map + index
--   2) TASK2 migration (2.1–2.4) → review hasil discovery 2.5 dgn auditor
--   3) DROP VIEW lama (jika ada versi hardcode) → CREATE view TASK3
--   4) TASK5 index (saat idle) → update statistics
--   5) TASK4 GATE1–GATE3 pada 1 periode tervalidasi (baseline stok = April
--      2026 yang sudah terbukti report=ledger) → dokumentasikan baseline
--   6) Isi rekon_snapshot_v2; dashboard membaca snapshot
-- ============================================================================


-- ============================================================================
-- TASK6  FORENSIC CLOSURE GATE#2 AP/AR  (root cause TERKUNCI 2026-07)
-- ----------------------------------------------------------------------------
-- FIX (sudah diterapkan di v_ap_sisa_vendor atas): blok adj (tbyr2_putih) &
--   byr (tbyr1+tbyr2) di-ANCHOR ke GL — hanya order_client dgn EXISTS
--   gl_journal(voucher=order_client, kredit>0, account_id IN map AP) yang dihitung.
--   Verifikasi live: AP subledger fixed = 8.238.241.410,02 = report (selisih 0,00).
--
-- BENCHMARK GL-live YTD s/d Apr 2026 (anchored=all, tak ada orphan jurnal):
--   AR 103-001       GL=20.117.869.958,91  sub=19.658.007.939,85  d=+459.861.950,00
--   AP 226-001(+006) GLnet=9.291.427.522,89 sub=8.238.241.410,02   d=+1.324.504.398,80
--
-- KLASIFIKASI GAP (linkage: gl_journal.voucher_manual = tbyr1.voucher_manual):
--   AR: MATCH 431 (47.361.445.587,46) | NO_GL_CI 9 = 459.861.950,00   (semua DPR)
--   AP: MATCH 131 (22.329.744.731,38) | NO_GL_CO 5 = 1.324.504.398,80 (semua DPB)
--   Hipotesis: A posting-belum(NO_GL_ENTRY)=VALID; B mapping-salah=DITOLAK
--   (nihil di GL/TDP/titipan 410-047); C period-shift=DITOLAK (ci_all/co_all=0).
--   ROOT CAUSE: penerapan Down Payment mengurangi subledger tanpa jurnal GL.
-- ----------------------------------------------------------------------------
-- R11 DETECTOR (jalankan per-domain; :p_account dari rekon_account_map)
--   AR: :p_modul='CI' + ar_trans/a.order_client ; AP: :p_modul='CO' + ap_trans/p.order_client
SELECT t1.voucher_manual,
       CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2)) AS gap_idr
FROM   tbyr1 t1
JOIN   tbyr2 t2 ON t2.voucher = t1.voucher
WHERE  t1.flag_bayar IN (1,2)
  AND  t1.tgl BETWEEN :arg_tgl1 AND :arg_tgl2
  AND  EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client = t2.bukti_id )
  AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                    WHERE gj.account_id = :p_account AND gj.modul_id = :p_modul
                      AND gj.voucher_manual = t1.voucher_manual )
GROUP BY t1.voucher_manual
HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0;
-- Deliverable akuntansi: posting 14 voucher DP -> GATE#2 harus 0 setelahnya.
-- ============================================================================
