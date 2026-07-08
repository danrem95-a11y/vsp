-- ============================================================================
--  REKON PRODUCTION IMPLEMENTATION  (ASA9 + PowerBuilder 11.5)
--  Depends  : rekon_finalization_layer.sql  (rekon_account_map + view dasar:
--             v_gl_mutasi_bulan, v_gl_opening_tahun, v_stok_saldo_periode,
--             v_ap_sisa_vendor, v_ar_sisa_cust)  -- DEPLOY ITU DULU.
--  Grounding: gl_setup (acc_ap/acc_ar/acc_biaya_ekpedisi), im_product_group,
--             gl_journal(account_id,debet,kredit,posting,tgl,modul_id,voucher,
--             voucher_manual,site_id), gl_balance(AccountCode,Period,AmountDebet,
--             AmountCredit,site_id), ap_trans/ar_trans(order_client,tipe_trans,
--             vendor_id/cust_id,tgl,order_oke,ttl_netto,kurs), saldo_awal_faktur,
--             tbyr1(voucher,voucher_manual,flag_bayar,flag_vendor,tgl),
--             tbyr2(voucher,bukti_id,nilai_bayar_idr),
--             tbyr2_putih(bukti_id,flag_order,nilai_bayar_idr,tgl_bayar).
--  Rules    : NO CTE, NO window func, NO SELECT *, NO literal account_id,
--             NO '*=' outer join, NO NOT IN(concat). Semua akun dari map.
--  Sign     : AR/STOK aset (debet) -> selisih = sub - ledger.
--             AP liability (kredit) -> ledger negatif -> selisih = sub + ledger.
-- ============================================================================


-- ############################################################################
-- 1) SQL DDL — objek tambahan (tabel + index). Tabel dasar & index gl_journal
--    dll. sudah dibuat di rekon_finalization_layer.sql (TASK1/TASK5).
-- ############################################################################

-- 1.1  Index tambahan yang dibutuhkan layer ini (cek existing dulu; buat idle)
--      Payment linkage GL (kunci R11/GATE#2) & anchor join.
CREATE INDEX idx_gljrn_vmanual   ON gl_journal (voucher_manual, account_id, modul_id);
CREATE INDEX idx_gljrn_acc_post  ON gl_journal (account_id, posting, tgl);
CREATE INDEX idx_tbyr1_vmanual   ON tbyr1 (voucher_manual, flag_bayar, tgl);
CREATE INDEX idx_tbyr2_voucher   ON tbyr2 (voucher, bukti_id);
-- (idx_gljrn_voucher, idx_ram_acc_site, idx_ram_domain, idx_aptrans_order,
--  idx_artrans_order, idx_tbyr2_bukti sudah ada dari finalization layer.)

-- 1.2  SNAPSHOT SISTEM (domain-level, audit historikal) — spec final.
--      Supersede draft account-level; ini yang dibaca dashboard & disimpan.
CREATE TABLE rekon_snapshot_v2 (
    periode         DATE          NOT NULL,      -- tgl-1 bulan periode (YYYY-MM-01)
    domain          VARCHAR(4)    NOT NULL,      -- 'STOK' | 'AP' | 'AR'
    subledger_total NUMERIC(18,2) NOT NULL DEFAULT 0,
    ledger_total    NUMERIC(18,2) NOT NULL DEFAULT 0,
    selisih         NUMERIC(18,2) NOT NULL DEFAULT 0,
    gate1_status    VARCHAR(8)    NULL,          -- PASS | FAIL | NA
    gate2_status    VARCHAR(8)    NULL,          -- PASS | FAIL
    gate3_status    VARCHAR(8)    NULL,          -- PASS | FAIL
    created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
    created_by      VARCHAR(30)   NOT NULL DEFAULT CURRENT USER,
    PRIMARY KEY (periode, domain)
);
CREATE INDEX idx_snapv2_dom ON rekon_snapshot_v2 (domain, periode);


-- ############################################################################
-- 2) SQL VIEW PRODUCTION (ASA9, map-driven, audit-traceable)
--    Semua per (thn,bln) kumulatif YTD (bln<=periode) sesuai kontrak GATE.
-- ############################################################################

-- 2.1  v_rekon_stok_final  — per akun persediaan, per (thn,bln)
--      subledger = SINV saldo AKHIR bln (= SINV.periode bulan+1, dipetakan balik)
--      ledger    = opening tahun + Sigma mutasi GL (STOK) s/d bln
CREATE VIEW v_rekon_stok_final AS
SELECT sub.account_id, sub.thn, sub.bln,
       sub.subledger_value,
       ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
           WHERE o.domain='STOK' AND o.account_id=sub.account_id AND o.thn=sub.thn )
       + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
           WHERE m.domain='STOK' AND m.account_id=sub.account_id
             AND m.thn=sub.thn AND m.bln<=sub.bln ) )                 AS ledger_value,
       ( sub.subledger_value
       - ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
             WHERE o.domain='STOK' AND o.account_id=sub.account_id AND o.thn=sub.thn )
         + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
             WHERE m.domain='STOK' AND m.account_id=sub.account_id
               AND m.thn=sub.thn AND m.bln<=sub.bln ) ) )             AS selisih,
       CASE WHEN ABS( sub.subledger_value
              - ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
                    WHERE o.domain='STOK' AND o.account_id=sub.account_id AND o.thn=sub.thn )
                + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
                    WHERE m.domain='STOK' AND m.account_id=sub.account_id
                      AND m.thn=sub.thn AND m.bln<=sub.bln ) ) ) <= 10
            THEN 'COCOK' ELSE 'SELISIH' END                          AS status
FROM ( SELECT v.account_id,
              CASE WHEN MONTH(v.periode)=1 THEN YEAR(v.periode)-1 ELSE YEAR(v.periode) END AS thn,
              CASE WHEN MONTH(v.periode)=1 THEN 12 ELSE MONTH(v.periode)-1 END             AS bln,
              SUM(v.saldo_subledger) AS subledger_value
       FROM   v_stok_saldo_periode v
       GROUP BY v.account_id,
              CASE WHEN MONTH(v.periode)=1 THEN YEAR(v.periode)-1 ELSE YEAR(v.periode) END,
              CASE WHEN MONTH(v.periode)=1 THEN 12 ELSE MONTH(v.periode)-1 END ) sub;

-- 2.2  v_rekon_ap_final  — domain AP, per (thn,bln), kumulatif
--      subledger = Sigma v_ap_sisa_vendor (bln<=); ledger = opening+mutasi (negatif)
--      selisih   = subledger + ledger  (liability)
CREATE VIEW v_rekon_ap_final AS
SELECT sp.thn, sp.bln,
       ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ap_sisa_vendor a
         WHERE a.thn=sp.thn AND a.bln<=sp.bln )                        AS subledger_total,
       ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
           WHERE o.domain='AP' AND o.thn=sp.thn )
       + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
           WHERE m.domain='AP' AND m.thn=sp.thn AND m.bln<=sp.bln ) )  AS ledger_total,
       ( ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ap_sisa_vendor a
           WHERE a.thn=sp.thn AND a.bln<=sp.bln )
       + ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
             WHERE o.domain='AP' AND o.thn=sp.thn )
         + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
             WHERE m.domain='AP' AND m.thn=sp.thn AND m.bln<=sp.bln ) ) ) AS selisih,
       CASE WHEN ABS(
              ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ap_sisa_vendor a
                WHERE a.thn=sp.thn AND a.bln<=sp.bln )
            + ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
                  WHERE o.domain='AP' AND o.thn=sp.thn )
              + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
                  WHERE m.domain='AP' AND m.thn=sp.thn AND m.bln<=sp.bln ) ) ) <= 10
            THEN 'COCOK' ELSE 'SELISIH' END                            AS status
FROM ( SELECT DISTINCT m.thn, m.bln FROM v_gl_mutasi_bulan m WHERE m.domain='AP' AND m.bln>0 ) sp;

-- 2.3  v_rekon_ar_final  — domain AR, per (thn,bln), kumulatif
--      subledger = Sigma v_ar_sisa_cust (bln<=); ledger = opening+mutasi (positif)
--      selisih   = subledger - ledger  (asset)
CREATE VIEW v_rekon_ar_final AS
SELECT sp.thn, sp.bln,
       ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ar_sisa_cust a
         WHERE a.thn=sp.thn AND a.bln<=sp.bln )                        AS subledger_total,
       ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
           WHERE o.domain='AR' AND o.thn=sp.thn )
       + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
           WHERE m.domain='AR' AND m.thn=sp.thn AND m.bln<=sp.bln ) )  AS ledger_total,
       ( ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ar_sisa_cust a
           WHERE a.thn=sp.thn AND a.bln<=sp.bln )
       - ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
             WHERE o.domain='AR' AND o.thn=sp.thn )
         + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
             WHERE m.domain='AR' AND m.thn=sp.thn AND m.bln<=sp.bln ) ) ) AS selisih,
       CASE WHEN ABS(
              ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ar_sisa_cust a
                WHERE a.thn=sp.thn AND a.bln<=sp.bln )
            - ( ( SELECT ISNULL(SUM(o.saldo_awal),0) FROM v_gl_opening_tahun o
                  WHERE o.domain='AR' AND o.thn=sp.thn )
              + ( SELECT ISNULL(SUM(m.mutasi),0) FROM v_gl_mutasi_bulan m
                  WHERE m.domain='AR' AND m.thn=sp.thn AND m.bln<=sp.bln ) ) ) <= 10
            THEN 'COCOK' ELSE 'SELISIH' END                            AS status
FROM ( SELECT DISTINCT m.thn, m.bln FROM v_gl_mutasi_bulan m WHERE m.domain='AR' AND m.bln>0 ) sp;

-- 2.4  v_rekon_gl_bridge  — SETIAP baris gl_journal ber-akun-map + status anchor
--      Titik audit: subledger <-> ledger per baris GL.
--      anchor_type: INVOICE (voucher=order_client) | PAYMENT (voucher_manual=tbyr1)
--                   | OPENING (voucher=saldo_awal_faktur.bukti_id) | ORPHAN
--      has_subledger = 'Y' bila punya pasangan subledger, else 'N' (=> R9 orphan)
CREATE VIEW v_rekon_gl_bridge AS
SELECT m.domain, j.account_id, j.site_id,
       YEAR(j.tgl)  AS thn, MONTH(j.tgl) AS bln, j.tgl,
       j.modul_id, j.voucher, j.voucher_manual,
       ISNULL(j.debet,0)  AS debet,
       ISNULL(j.kredit,0) AS kredit,
       CASE
         WHEN EXISTS ( SELECT 1 FROM ap_trans p
                       WHERE p.order_client=j.voucher )
           OR EXISTS ( SELECT 1 FROM ar_trans a
                       WHERE a.order_client=j.voucher ) THEN 'INVOICE'
         WHEN EXISTS ( SELECT 1 FROM saldo_awal_faktur f
                       WHERE f.bukti_id=j.voucher ) THEN 'OPENING'
         WHEN EXISTS ( SELECT 1 FROM tbyr1 t1
                       WHERE t1.voucher_manual=j.voucher_manual
                         AND ISNULL(j.voucher_manual,'')<>'' ) THEN 'PAYMENT'
         ELSE 'ORPHAN'
       END AS anchor_type,
       CASE
         WHEN EXISTS ( SELECT 1 FROM ap_trans p  WHERE p.order_client=j.voucher )
           OR EXISTS ( SELECT 1 FROM ar_trans a  WHERE a.order_client=j.voucher )
           OR EXISTS ( SELECT 1 FROM saldo_awal_faktur f WHERE f.bukti_id=j.voucher )
           OR EXISTS ( SELECT 1 FROM tbyr1 t1 WHERE t1.voucher_manual=j.voucher_manual
                         AND ISNULL(j.voucher_manual,'')<>'' ) THEN 'Y'
         ELSE 'N'
       END AS has_subledger
FROM   gl_journal j
JOIN   rekon_account_map m
       ON  m.account_id = j.account_id
       AND m.is_active  = 'Y'
       AND (m.site_id='*' OR m.site_id=j.site_id)
       AND j.tgl >= m.effective_from
       AND (m.effective_to IS NULL OR j.tgl <= m.effective_to)
WHERE  j.posting='P';

-- 2.5  v_rekon_summary_kpi  — 1 baris per (thn,bln,domain): total & status
--      (STOK diagregasi lintas akun; AP/AR sudah domain-level).
CREATE VIEW v_rekon_summary_kpi AS
SELECT s.thn, s.bln, 'STOK' AS domain,
       SUM(s.subledger_value) AS subledger_total,
       SUM(s.ledger_value)    AS ledger_total,
       SUM(s.selisih)         AS selisih,
       CASE WHEN MAX(CASE WHEN s.status='SELISIH' THEN 1 ELSE 0 END)=0
            THEN 'COCOK' ELSE 'SELISIH' END AS status
FROM   v_rekon_stok_final s
GROUP BY s.thn, s.bln
UNION ALL
SELECT p.thn, p.bln, 'AP', p.subledger_total, p.ledger_total, p.selisih, p.status
FROM   v_rekon_ap_final p
UNION ALL
SELECT r.thn, r.bln, 'AR', r.subledger_total, r.ledger_total, r.selisih, r.status
FROM   v_rekon_ar_final r;


-- ############################################################################
-- 3) STORED PROCEDURE — ANOMALY ENGINE  sp_rekon_anomali  (R1..R11)
--    Output: RESULT SET terstruktur (bukan print). p_domain: STOK|AP|AR|ALL.
-- ############################################################################
CREATE PROCEDURE sp_rekon_anomali(
    IN p_domain VARCHAR(4)  DEFAULT 'ALL',
    IN p_thn    INTEGER     DEFAULT 0,
    IN p_bln    INTEGER     DEFAULT 12 )
RESULT ( rule_id VARCHAR(6), severity VARCHAR(8), category VARCHAR(40),
         domain VARCHAR(4), account_id VARCHAR(20),
         ref_key VARCHAR(120), nilai NUMERIC(18,2) )
BEGIN
   DECLARE ldt_awal DATE;
   DECLARE ldt_bln1 DATE;
   DECLARE ldt_bln2 DATE;

   DECLARE LOCAL TEMPORARY TABLE anom (
       rule_id VARCHAR(6), severity VARCHAR(8), category VARCHAR(40),
       domain VARCHAR(4), account_id VARCHAR(20),
       ref_key VARCHAR(120), nilai NUMERIC(18,2) ) NOT TRANSACTIONAL;
   DECLARE LOCAL TEMPORARY TABLE stoksub (
       account_id VARCHAR(20), thn INTEGER, mth INTEGER, saldo NUMERIC(18,2) ) NOT TRANSACTIONAL;
   DECLARE LOCAL TEMPORARY TABLE stokmut (
       account_id VARCHAR(20), thn INTEGER, bln INTEGER, mutasi NUMERIC(18,2) ) NOT TRANSACTIONAL;
   DECLARE LOCAL TEMPORARY TABLE stokopen (
       account_id VARCHAR(20), thn INTEGER, saldo_awal NUMERIC(18,2) ) NOT TRANSACTIONAL;
   DECLARE LOCAL TEMPORARY TABLE stokfin (
       account_id VARCHAR(20), thn INTEGER, bln INTEGER,
       subledger_value NUMERIC(18,2), ledger_value NUMERIC(18,2),
       selisih NUMERIC(18,2), status VARCHAR(8) ) NOT TRANSACTIONAL;

   SET ldt_awal = CAST(STRING(p_thn,'-01-01') AS DATE);
   SET ldt_bln1 = CAST(STRING(p_thn,'-',RIGHT('0'||STRING(p_bln),2),'-01') AS DATE);
   SET ldt_bln2 = DATEADD(day,-1,DATEADD(month,1,ldt_bln1));

   -- Materialisasi SEKALI (STOK). stokfin dihitung SET-BASED dari temp — TIDAK
   -- menyentuh v_rekon_stok_final (scalar-subquery-nya me-recompute agregasi
   -- gl_journal per baris => 77 dtk). Hasil identik.
   IF p_domain = 'ALL' OR p_domain = 'STOK' THEN
      INSERT INTO stoksub          -- SINV snapshot per akun/bulan (1 scan v_stok_saldo_periode)
      SELECT v.account_id, YEAR(v.periode), MONTH(v.periode), SUM(ISNULL(v.saldo_subledger,0))
      FROM   v_stok_saldo_periode v
      GROUP BY v.account_id, YEAR(v.periode), MONTH(v.periode);
      INSERT INTO stokmut          -- mutasi GL per akun/bulan (1 scan v_gl_mutasi_bulan)
      SELECT m.account_id, m.thn, m.bln, SUM(ISNULL(m.mutasi,0))
      FROM   v_gl_mutasi_bulan m WHERE m.domain='STOK'
      GROUP BY m.account_id, m.thn, m.bln;
      INSERT INTO stokopen         -- saldo awal tahun (1 scan v_gl_opening_tahun)
      SELECT o.account_id, o.thn, SUM(ISNULL(o.saldo_awal,0))
      FROM   v_gl_opening_tahun o WHERE o.domain='STOK'
      GROUP BY o.account_id, o.thn;
      -- stokfin = subledger (SINV akhir bln, dipetakan balik) vs ledger (opening + Sigma mutasi<=bln)
      INSERT INTO stokfin (account_id, thn, bln, subledger_value, ledger_value, selisih, status)
      SELECT sub.account_id, sub.thn, sub.bln, sub.sub,
             ISNULL(op.saldo_awal,0) + ISNULL(cm.cummut,0),
             sub.sub - (ISNULL(op.saldo_awal,0) + ISNULL(cm.cummut,0)),
             CASE WHEN ABS(sub.sub - (ISNULL(op.saldo_awal,0) + ISNULL(cm.cummut,0))) <= 10
                  THEN 'COCOK' ELSE 'SELISIH' END
      FROM ( SELECT ss.account_id,
                    CASE WHEN ss.mth=1 THEN ss.thn-1 ELSE ss.thn END AS thn,
                    CASE WHEN ss.mth=1 THEN 12 ELSE ss.mth-1 END      AS bln,
                    ss.saldo AS sub
             FROM stoksub ss ) sub
      LEFT OUTER JOIN stokopen op
             ON op.account_id=sub.account_id AND op.thn=sub.thn
      LEFT OUTER JOIN ( SELECT a.account_id, a.thn, a.bln, SUM(b.mutasi) AS cummut
                        FROM ( SELECT DISTINCT account_id, thn, bln FROM stokmut ) a
                        JOIN stokmut b ON b.account_id=a.account_id AND b.thn=a.thn AND b.bln<=a.bln
                        GROUP BY a.account_id, a.thn, a.bln ) cm
             ON cm.account_id=sub.account_id AND cm.thn=sub.thn AND cm.bln=sub.bln
      WHERE sub.thn=p_thn AND sub.bln<=p_bln;
   END IF;

   -- R1  UNPOSTED JOURNAL (semua domain) : jurnal posting<>'P' pada akun ber-map
   INSERT INTO anom
   SELECT 'R1','HIGH','UNPOSTED_JOURNAL', m.domain, j.account_id,
          STRING('n_baris=',COUNT(*)),
          CAST(SUM(ABS(ISNULL(j.debet,0))+ABS(ISNULL(j.kredit,0))) AS NUMERIC(18,2))
   FROM   gl_journal j
   JOIN   rekon_account_map m ON m.account_id=j.account_id AND m.is_active='Y'
   WHERE  ISNULL(j.posting,'')<>'P' AND j.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  (p_domain='ALL' OR m.domain=p_domain)
   GROUP BY m.domain, j.account_id;

   -- R2  MISSING LEDGER (STOK) : akun stok punya SINV tapi TANPA jurnal GL YTD
   INSERT INTO anom
   SELECT 'R2','HIGH','MISSING_LEDGER','STOK', ss.account_id,
          'sinv_ada_gl_kosong', CAST(SUM(ss.saldo) AS NUMERIC(18,2))
   FROM   stoksub ss
   WHERE  (p_domain='ALL' OR p_domain='STOK') AND ss.thn=p_thn
     AND  NOT EXISTS ( SELECT 1 FROM gl_journal j
                       WHERE j.account_id=ss.account_id AND j.posting='P'
                         AND j.tgl BETWEEN ldt_awal AND ldt_bln2 )
   GROUP BY ss.account_id
   HAVING SUM(ss.saldo) <> 0;

   -- R3  OPENING BALANCE GAP (STOK) : GL opening tahun vs SINV opening (Jan)
   INSERT INTO anom
   SELECT 'R3','HIGH','OPENING_BALANCE_GAP','STOK', o.account_id,
          'gl_open<>sinv_open',
          CAST(ISNULL(o.saldo_awal,0) - ISNULL(so.saldo,0) AS NUMERIC(18,2))
   FROM   v_gl_opening_tahun o
   LEFT OUTER JOIN ( SELECT account_id, saldo FROM stoksub WHERE thn=p_thn AND mth=1 ) so
          ON so.account_id = o.account_id
   WHERE  o.domain='STOK' AND o.thn=p_thn AND (p_domain='ALL' OR p_domain='STOK')
     AND  ABS( ISNULL(o.saldo_awal,0) - ISNULL(so.saldo,0) ) > 10;

   -- R4  GL-ONLY ACCOUNT (STOK) : akun ter-map tapi tak punya baris SINV (WIP dsb)
   INSERT INTO anom
   SELECT 'R4','INFO','GL_ONLY_NO_SINV','STOK', m.account_id,
          'map_tanpa_sinv', 0
   FROM   rekon_account_map m
   WHERE  m.domain='STOK' AND m.is_active='Y' AND (p_domain='ALL' OR p_domain='STOK')
     AND  NOT EXISTS ( SELECT 1 FROM stoksub ss WHERE ss.account_id=m.account_id );

   -- R5  LOOP-'19' RISK (STOK, proxy akun) : ada bulan dg |mutasi| > |saldo akhir|
   INSERT INTO anom
   SELECT 'R5','MED','LOOP19_RISK','STOK', sf.account_id,
          STRING('bln=',sf.bln,' |mut|>|akhir|'),
          CAST(sf.subledger_value AS NUMERIC(18,2))
   FROM   stokfin sf
   JOIN   stokmut sm ON sm.account_id=sf.account_id AND sm.thn=sf.thn AND sm.bln=sf.bln
   WHERE  (p_domain='ALL' OR p_domain='STOK')
     AND  sf.subledger_value <> 0
     AND  ABS(sm.mutasi) > ABS(sf.subledger_value);

   -- R6  SITE MISMATCH : akun dg site di jurnal yang tak ada di gl_balance
   INSERT INTO anom
   SELECT 'R6','MED','SITE_MISMATCH', m.domain, j.account_id,
          STRING('site=',j.site_id), CAST(SUM(ISNULL(j.debet,0)-ISNULL(j.kredit,0)) AS NUMERIC(18,2))
   FROM   gl_journal j
   JOIN   rekon_account_map m ON m.account_id=j.account_id AND m.is_active='Y' AND m.site_id<>'*'
   WHERE  j.posting='P' AND j.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  (p_domain='ALL' OR m.domain=p_domain)
     AND  NOT EXISTS ( SELECT 1 FROM gl_balance b
                       WHERE b.AccountCode=j.account_id AND b.site_id=j.site_id
                         AND YEAR(b.Period)=p_thn )
   GROUP BY m.domain, j.account_id, j.site_id;

   -- R7  PAYMENT PENDING (AP/AR) : TBYR1.flag_bayar=1 (pending) mengurangi sisa
   INSERT INTO anom
   SELECT 'R7','INFO','PAYMENT_PENDING', xd.domain, xd.acc,
          STRING('vmanual=',t1.voucher_manual),
          CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher=t1.voucher
   JOIN ( SELECT 'AP' AS domain, 'AP' AS acc FROM dummy
          UNION ALL SELECT 'AR','AR' FROM dummy ) xd
          ON (p_domain='ALL' OR p_domain=xd.domain)
   WHERE  t1.flag_bayar=1 AND t1.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  ( ( xd.domain='AP' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id) )
         OR ( xd.domain='AR' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id) ) )
   GROUP BY xd.domain, xd.acc, t1.voucher_manual
   HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0;

   -- R8  ADJUSTMENT PUTIH (AP/AR) : TBYR2_PUTIH non-kas pada periode
   INSERT INTO anom
   SELECT 'R8','INFO','ADJUSTMENT_PUTIH', xd.domain, xd.acc,
          STRING('bukti=',tp.bukti_id),
          CAST(SUM(ABS(ISNULL(tp.nilai_bayar_idr,0))) AS NUMERIC(18,2))
   FROM   tbyr2_putih tp
   JOIN ( SELECT 'AP' AS domain, 'AP' AS acc FROM dummy
          UNION ALL SELECT 'AR','AR' FROM dummy ) xd
          ON (p_domain='ALL' OR p_domain=xd.domain)
   WHERE  tp.tgl_bayar BETWEEN ldt_awal AND ldt_bln2
     AND  ( ( xd.domain='AP' AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=tp.bukti_id) )
         OR ( xd.domain='AR' AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=tp.bukti_id) ) )
   GROUP BY xd.domain, xd.acc, tp.bukti_id
   HAVING SUM(ABS(ISNULL(tp.nilai_bayar_idr,0))) <> 0;

   -- R9  GL-ANCHOR ORPHAN (AP/AR) : jurnal akun kontrol TANPA pasangan subledger
   --     AR: 103-001 debet>0 tanpa ar_trans/SAF ; AP: 226 kredit>0 tanpa ap_trans/SAF
   INSERT INTO anom
   SELECT 'R9','HIGH','GL_ORPHAN_VOUCHER','AR', j.account_id,
          STRING('voucher=',j.voucher), CAST(SUM(j.debet) AS NUMERIC(18,2))
   FROM   gl_journal j
   WHERE  (p_domain='ALL' OR p_domain='AR') AND j.debet>0 AND j.posting='P'
     AND  j.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  j.account_id IN ( SELECT m.account_id FROM rekon_account_map m
                            WHERE m.domain='AR' AND m.is_active='Y' )
     AND  NOT EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client=j.voucher )
     AND  NOT EXISTS ( SELECT 1 FROM saldo_awal_faktur f
                       WHERE f.bukti_id=j.voucher AND f.tipe_trans=1 )
   GROUP BY j.account_id, j.voucher;
   INSERT INTO anom
   SELECT 'R9','HIGH','GL_ORPHAN_VOUCHER','AP', j.account_id,
          STRING('voucher=',j.voucher), CAST(SUM(j.kredit) AS NUMERIC(18,2))
   FROM   gl_journal j
   WHERE  (p_domain='ALL' OR p_domain='AP') AND j.kredit>0 AND j.posting='P'
     AND  j.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  j.account_id IN ( SELECT m.account_id FROM rekon_account_map m
                            WHERE m.domain='AP' AND m.is_active='Y' )
     AND  NOT EXISTS ( SELECT 1 FROM ap_trans p WHERE p.order_client=j.voucher )
     AND  NOT EXISTS ( SELECT 1 FROM saldo_awal_faktur f
                       WHERE f.bukti_id=j.voucher AND f.tipe_trans IN (1,2) )
   GROUP BY j.account_id, j.voucher;

   -- R10 ROUNDING NOISE : selisih akun 0<|x|<=10 (info; ditangani summary)
   INSERT INTO anom
   SELECT 'R10','INFO','ROUNDING_NOISE','STOK', sf.account_id,
          'selisih<=10', CAST(sf.selisih AS NUMERIC(18,2))
   FROM   stokfin sf
   WHERE  (p_domain='ALL' OR p_domain='STOK') AND sf.thn=p_thn AND sf.bln=p_bln
     AND  ABS(sf.selisih) > 0 AND ABS(sf.selisih) <= 10;

   -- R11 DP APPLICATION POSTING GAP (AP/AR) — FINALIZED
   --     TBYR (flag_bayar 1,2) anchored ke subledger TAPI tanpa jurnal GL CI/CO
   --     dicocokkan by voucher_manual. = Down Payment tanpa jurnal (14 voucher).
   INSERT INTO anom
   SELECT 'R11','HIGH','DP_APPLICATION_GAP','AR',
          ( SELECT m.account_id FROM rekon_account_map m
            WHERE m.domain='AR' AND m.account_type='RECEIVABLE' AND m.is_active='Y' ),
          STRING('vmanual=',t1.voucher_manual),
          CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher=t1.voucher
   WHERE  (p_domain='ALL' OR p_domain='AR')
     AND  t1.flag_bayar IN (1,2) AND t1.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id )
     AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                       WHERE gj.modul_id='CI' AND gj.voucher_manual=t1.voucher_manual
                         AND gj.account_id IN ( SELECT m.account_id FROM rekon_account_map m
                                                WHERE m.domain='AR' AND m.is_active='Y' ) )
   GROUP BY t1.voucher_manual
   HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0;
   INSERT INTO anom
   SELECT 'R11','HIGH','DP_APPLICATION_GAP','AP',
          ( SELECT m.account_id FROM rekon_account_map m
            WHERE m.domain='AP' AND m.account_type='PAYABLE' AND m.is_active='Y' ),
          STRING('vmanual=',t1.voucher_manual),
          CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2))
   FROM   tbyr1 t1
   JOIN   tbyr2 t2 ON t2.voucher=t1.voucher
   WHERE  (p_domain='ALL' OR p_domain='AP')
     AND  t1.flag_bayar IN (1,2) AND t1.tgl BETWEEN ldt_awal AND ldt_bln2
     AND  EXISTS ( SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id )
     AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                       WHERE gj.modul_id='CO' AND gj.voucher_manual=t1.voucher_manual
                         AND gj.account_id IN ( SELECT m.account_id FROM rekon_account_map m
                                                WHERE m.domain='AP' AND m.is_active='Y' ) )
   GROUP BY t1.voucher_manual
   HAVING SUM(ISNULL(t2.nilai_bayar_idr,0)) <> 0;

   SELECT rule_id, severity, category, domain, account_id, ref_key, nilai
   FROM   anom
   ORDER BY CASE severity WHEN 'HIGH' THEN 1 WHEN 'MED' THEN 2 ELSE 3 END,
            rule_id, ABS(nilai) DESC;
END;


-- ############################################################################
-- 4) GATE VALIDATION QUERIES (SQL executable)  — args PB :arg_thn, :arg_bln
-- ############################################################################

-- GATE#1 — REPORT CONSISTENCY : total view vs total report opname (SISA_IDR).
--   Jalankan tiap query, bandingkan dg export dw_rpt_ap_opname/ar_opname periode
--   sama; PASS bila |selisih| <= 10. (report = DW, dibandingkan operator/loader.)
SELECT 'GATE1_AP' AS gate,
       ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ap_sisa_vendor a
         WHERE a.thn=:arg_thn AND a.bln<=:arg_bln ) AS total_view_sisa_idr;
SELECT 'GATE1_AR' AS gate,
       ( SELECT ISNULL(SUM(a.sisa_idr),0) FROM v_ar_sisa_cust a
         WHERE a.thn=:arg_thn AND a.bln<=:arg_bln ) AS total_view_sisa_idr;

-- GATE#2 — LEDGER CONSISTENCY : subledger vs gl_journal (per domain).
SELECT 'GATE2_STOK' AS gate, s.account_id, s.subledger_value, s.ledger_value,
       s.selisih, CASE WHEN s.status='COCOK' THEN 'PASS' ELSE 'FAIL' END AS gate_status
FROM   v_rekon_stok_final s
WHERE  s.thn=:arg_thn AND s.bln=:arg_bln
ORDER BY s.account_id;
SELECT 'GATE2_AP' AS gate, p.subledger_total, p.ledger_total, p.selisih,
       CASE WHEN p.status='COCOK' THEN 'PASS' ELSE 'FAIL' END AS gate_status
FROM   v_rekon_ap_final p WHERE p.thn=:arg_thn AND p.bln=:arg_bln;
SELECT 'GATE2_AR' AS gate, r.subledger_total, r.ledger_total, r.selisih,
       CASE WHEN r.status='COCOK' THEN 'PASS' ELSE 'FAIL' END AS gate_status
FROM   v_rekon_ar_final r WHERE r.thn=:arg_thn AND r.bln=:arg_bln;

-- GATE#2 detail — voucher orphan (subledger movement vs GL row), pakai bridge:
SELECT 'GATE2_ORPHAN' AS gate, b.domain, b.account_id, b.voucher, b.voucher_manual,
       b.debet, b.kredit, b.anchor_type
FROM   v_rekon_gl_bridge b
WHERE  b.thn=:arg_thn AND b.has_subledger='N'
ORDER BY (b.debet+b.kredit) DESC;

-- GATE#3 — INTEGRITY : unmapped / orphan / stale / overlap. Ideal: semua KOSONG.
-- 3a. akun persediaan belum ter-map
SELECT 'GATE3_UNMAPPED_STOK' AS gate, g.persediaan AS account_id
FROM   im_product_group g
WHERE  ISNULL(g.persediaan,'')<>''
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.domain='STOK' AND m.account_id=g.persediaan AND m.is_active='Y' )
GROUP BY g.persediaan;
-- 3b. GL voucher AP/AR-anchored di akun kontrol yang BELUM ter-map (orphan akun)
SELECT 'GATE3_UNMAPPED_APAR' AS gate, j.account_id, COUNT(*) AS n_baris
FROM   gl_journal j
WHERE  j.posting='P'
  AND  ( EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=j.voucher AND j.kredit>0)
      OR EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=j.voucher AND j.debet>0) )
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.account_id=j.account_id AND m.is_active='Y' )
GROUP BY j.account_id
HAVING COUNT(*) >= 5;
-- 3c. stale mapping : map aktif tapi tak pernah muncul di GL
SELECT 'GATE3_STALE_MAP' AS gate, m.domain, m.account_id
FROM   rekon_account_map m
WHERE  m.is_active='Y'
  AND  NOT EXISTS ( SELECT 1 FROM gl_journal j WHERE j.account_id=m.account_id )
  AND  NOT EXISTS ( SELECT 1 FROM gl_balance b WHERE b.AccountCode=m.account_id );
-- 3d. effective-date overlap (duplikasi mapping periode tumpang tindih)
SELECT 'GATE3_OVERLAP' AS gate, a.domain, a.account_id, a.site_id,
       a.effective_from AS from_a, b.effective_from AS from_b
FROM   rekon_account_map a
JOIN   rekon_account_map b
       ON  b.domain=a.domain AND b.account_type=a.account_type
       AND b.account_id=a.account_id AND b.site_id=a.site_id
       AND b.effective_from > a.effective_from
WHERE  a.is_active='Y' AND b.is_active='Y'
  AND  (a.effective_to IS NULL OR b.effective_from <= a.effective_to);


-- ############################################################################
-- 5) SNAPSHOT SYSTEM — builder per periode (tanpa intervensi manual)
--    sp_rekon_snapshot_build(p_thn,p_bln): hitung 3 domain + 3 GATE, upsert.
-- ############################################################################
CREATE PROCEDURE sp_rekon_snapshot_build( IN p_thn INTEGER, IN p_bln INTEGER )
BEGIN
   DECLARE ldt_per   DATE;
   DECLARE li_g3     INTEGER;   -- pelanggaran integritas (0 = PASS)
   DECLARE lc_g3     VARCHAR(8);

   SET ldt_per = CAST(STRING(p_thn,'-',RIGHT('0'||STRING(p_bln),2),'-01') AS DATE);

   -- GATE#3 global (integritas mapping) : hitung total pelanggaran
   SELECT COUNT(*) INTO li_g3 FROM (
        SELECT g.persediaan AS k FROM im_product_group g
        WHERE ISNULL(g.persediaan,'')<>''
          AND NOT EXISTS (SELECT 1 FROM rekon_account_map m
                          WHERE m.domain='STOK' AND m.account_id=g.persediaan AND m.is_active='Y')
        UNION ALL
        SELECT m.account_id FROM rekon_account_map m
        WHERE m.is_active='Y'
          AND NOT EXISTS (SELECT 1 FROM gl_journal j WHERE j.account_id=m.account_id)
          AND NOT EXISTS (SELECT 1 FROM gl_balance b WHERE b.AccountCode=m.account_id)
   ) gg;
   SET lc_g3 = CASE WHEN li_g3=0 THEN 'PASS' ELSE 'FAIL' END;

   -- bersihkan snapshot periode ini (idempotent)
   DELETE FROM rekon_snapshot_v2 WHERE periode=ldt_per;

   -- STOK (agregasi akun; gate2 FAIL bila ada akun selisih)
   INSERT INTO rekon_snapshot_v2
         (periode,domain,subledger_total,ledger_total,selisih,gate1_status,gate2_status,gate3_status)
   SELECT ldt_per,'STOK',
          ISNULL(SUM(s.subledger_value),0), ISNULL(SUM(s.ledger_value),0),
          ISNULL(SUM(s.selisih),0),
          'NA',
          CASE WHEN MAX(CASE WHEN s.status='SELISIH' THEN 1 ELSE 0 END)=0 THEN 'PASS' ELSE 'FAIL' END,
          lc_g3
   FROM   v_rekon_stok_final s
   WHERE  s.thn=p_thn AND s.bln=p_bln;

   -- AP
   INSERT INTO rekon_snapshot_v2
         (periode,domain,subledger_total,ledger_total,selisih,gate1_status,gate2_status,gate3_status)
   SELECT ldt_per,'AP', ISNULL(p.subledger_total,0), ISNULL(p.ledger_total,0),
          ISNULL(p.selisih,0), 'NA',
          CASE WHEN p.status='COCOK' THEN 'PASS' ELSE 'FAIL' END, lc_g3
   FROM   v_rekon_ap_final p WHERE p.thn=p_thn AND p.bln=p_bln;

   -- AR
   INSERT INTO rekon_snapshot_v2
         (periode,domain,subledger_total,ledger_total,selisih,gate1_status,gate2_status,gate3_status)
   SELECT ldt_per,'AR', ISNULL(r.subledger_total,0), ISNULL(r.ledger_total,0),
          ISNULL(r.selisih,0), 'NA',
          CASE WHEN r.status='COCOK' THEN 'PASS' ELSE 'FAIL' END, lc_g3
   FROM   v_rekon_ar_final r WHERE r.thn=p_thn AND r.bln=p_bln;
   -- Catatan GATE#1: 'NA' = perlu verifikasi vs export DW (GATE1 query sec.4);
   --   loader operator dapat UPDATE gate1_status setelah cocokkan report.
END;


-- ############################################################################
-- 6) POWERBUILDER DATAWINDOW SQL (ready-bind)  — struktur & binding saja.
-- ############################################################################
/*
 dw_rekon_summary  (grid dashboard; source: SNAPSHOT — instan)
 Retrieval args: arg_periode (date)
   SELECT s.domain, s.subledger_total, s.ledger_total, s.selisih,
          CASE WHEN ABS(s.selisih)<=10 THEN 'COCOK' ELSE 'SELISIH' END AS status,
          s.gate1_status, s.gate2_status, s.gate3_status
   FROM   rekon_snapshot_v2 s
   WHERE  s.periode = :arg_periode
   ORDER BY s.domain;
   -- Clicked(row): retrieve dw_rekon_detail_voucher dg domain+periode.

 dw_rekon_detail_voucher  (drill lvl-3: opname per voucher; REUSE kontrak)
 Retrieval args: arg_domain (char), arg_thn (int), arg_bln (int)
   -- AP: pakai SQL dw_rpt_ap_opname apa adanya + tak perlu ubah; contoh anchor
   --     ringkas berbasis bridge utk navigasi cepat:
   SELECT b.domain, b.account_id, b.voucher, b.voucher_manual, b.tgl,
          b.modul_id, b.debet, b.kredit, b.anchor_type, b.has_subledger
   FROM   v_rekon_gl_bridge b
   WHERE  b.domain = :arg_domain AND b.thn = :arg_thn AND b.bln <= :arg_bln
   ORDER BY b.has_subledger ASC, (b.debet+b.kredit) DESC;
   -- (Detail nilai SISA per faktur tetap dari dw_rpt_ap_opname/ar_opname existing,
   --  difilter vendor_id/cust_id — jangan tulis ulang logika opname.)
   -- Clicked(row): retrieve dw_rekon_gl_bridge dg voucher terpilih.

 dw_rekon_gl_bridge  (drill lvl-4: baris jurnal GL = titik audit)
 Retrieval args: arg_account (char), arg_thn (int), arg_bln (int), arg_voucher (char)
   SELECT b.account_id, b.tgl, b.modul_id, b.voucher, b.voucher_manual,
          b.debet, b.kredit, b.anchor_type, b.has_subledger
   FROM   v_rekon_gl_bridge b
   WHERE  b.account_id = :arg_account AND b.thn = :arg_thn AND b.bln = :arg_bln
     AND  (:arg_voucher = '' OR b.voucher = :arg_voucher
           OR b.voucher_manual = :arg_voucher)
   ORDER BY b.tgl, b.voucher;

 dw_rekon_anomali  (panel "Jelaskan Selisih"; source: stored procedure)
   -- PB: DataWindow "Stored Procedure" -> EXECUTE sp_rekon_anomali;
   --     arg: :arg_domain (STOK|AP|AR|ALL), :arg_thn, :arg_bln
   -- Kolom hasil: rule_id, severity, category, domain, account_id, ref_key, nilai
   -- Row R11 => actionable: "posting jurnal DP" (14 voucher DPR/DPB).

 EVENT FLOW (binding, tanpa UI design):
   w_rekon_dashboard.open
     -> dw_rekon_summary.Retrieve(:arg_periode)          [baca snapshot]
   dw_rekon_summary.clicked(domain)
     -> OpenWithParm(w_rekon_detail, domain+thn+bln)
        -> dw_rekon_detail_voucher.Retrieve(domain,thn,bln)
   dw_rekon_detail_voucher.clicked(voucher)
     -> OpenWithParm(w_rekon_gl_bridge, account+thn+bln+voucher)
        -> dw_rekon_gl_bridge.Retrieve(...)              [baris gl_journal]
   w_rekon_detail."Jelaskan Selisih".clicked
     -> dw_rekon_anomali (EXECUTE sp_rekon_anomali :domain,:thn,:bln)
*/


-- ############################################################################
-- 7) PERFORMANCE NOTES (ASA9)
-- ############################################################################
/*
 - Dashboard membaca rekon_snapshot_v2 (O(3) baris/periode) -> instan; view berat
   (v_rekon_*_final) HANYA dijalankan saat build snapshot / drill, bukan tiap open.
 - Semua filter akun lewat idx_ram_acc_site / idx_ram_domain (map kecil -> nested
   loop murah); gl_journal difilter (account_id,tgl,posting) -> idx_gljrn_acc_tgl_post.
 - Linkage pembayaran (R11/GATE#2) lewat idx_gljrn_vmanual + idx_tbyr1_vmanual.
 - Anti full-scan: hindari fungsi pada kolom ter-index di predikat besar; gunakan
   rentang tgl (BETWEEN ldt_awal AND ldt_bln2) BUKAN YEAR(tgl)= pada gl_journal.
 - Scalar-subquery kumulatif di v_rekon_*_final: aman krn beroperasi pada view
   agregat bulanan (kecil), bukan transaksi mentah.
 - Batch PB 11.5: SetTransObject + Retrieve dg argumen; JANGAN retrieve tanpa
   filter periode. Build snapshot dijadwalkan setelah closing/refresh (sekali).
 - DDL index dibuat saat idle (aplikasi memegang SHARE lock luas -> blok DDL).
 - Jalankan UPDATE STATISTICS pada gl_journal, sinv, tbyr1/2, ap_trans, ar_trans
   setelah index dibuat agar optimizer memilih index scan.

 URUTAN DEPLOY:
   0) rekon_finalization_layer.sql (map + view dasar + index) HARUS sudah jalan.
   1) Section 1  (index tambahan idle + tabel rekon_snapshot_v2)
   2) Section 2  (CREATE VIEW v_rekon_*_final, _gl_bridge, _summary_kpi)
   3) Section 3  (CREATE PROCEDURE sp_rekon_anomali)
   4) Section 5  (CREATE PROCEDURE sp_rekon_snapshot_build)
   5) Section 4 GATE queries -> validasi 1 periode baseline (April 2026)
   6) CALL sp_rekon_snapshot_build(2026,4) -> cek rekon_snapshot_v2
   7) Bind DataWindow (section 6) di PB 11.5.
*/
