-- =====================================================================
-- run_evap_patch_validation.sql   (ASA9 / SQL Anywhere 9)
-- MASTER CLOSING GATE untuk patch HPP EVAP moving-average fallback.
-- Prasyarat urutan di DB COPY:
--   1) EVIDENCE_1_baseline_snapshot.sql   (refresh+close kode PRE-PATCH dulu, lalu snapshot)
--   2) Apply patch (2088 fallback + f_insert_cons_in) -> Full Build
--   3) Refresh+close Juni & Juli #1  -> jalankan blok SNAPSHOT-POST1 di bawah
--   4) Refresh+close Juni & Juli #2  (utk uji idempotent)
--   5) Jalankan SISA script ini -> laporan gate + keputusan
-- Gate 1 (compile) diisi manual; Gate 6 butuh _post1_tsales2_hpp (blok di bawah).
-- =====================================================================

-- ============ (jalankan SETELAH refresh #1, SEBELUM refresh #2) : SNAPSHOT-POST1 ============
-- BEGIN
--   IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_post1_tsales2_hpp') THEN EXECUTE IMMEDIATE 'DROP TABLE _post1_tsales2_hpp'; END IF;
-- END;
-- SELECT a.bukti_id,b.urut,CAST(ISNULL(b.hpp,0) AS numeric(18,2)) AS hpp
--   INTO _post1_tsales2_hpp FROM tsales1 a,tsales2 b
--  WHERE a.bukti_id=b.bukti_id AND a.tgl>=(SELECT p1 FROM _cfg) AND a.tgl<(SELECT p2 FROM _cfg)
--    AND a.tipe_trans IN ('22','32','26','36','88');
-- ==========================================================================================

-- ---------- (re)build _cmp_hpp agar self-contained ----------
BEGIN
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_cmp_hpp') THEN EXECUTE IMMEDIATE 'DROP TABLE _cmp_hpp'; END IF;
  IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_val_result') THEN EXECUTE IMMEDIATE 'DROP TABLE _val_result'; END IF;
  IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_gate_manual') THEN
     EXECUTE IMMEDIATE 'CREATE TABLE _gate_manual (gate varchar(40), status varchar(10))';
  END IF;
END;

SELECT p.bukti_id,p.urut,p.stok_id,p.evap,p.tgl,p.tipe_trans,
  CAST(p.qty AS numeric(18,2)) AS qty, p.hpp AS hpp_pre,
  CAST(ISNULL(b.hpp,0) AS numeric(18,2)) AS hpp_post,
  CAST(ISNULL(b.hpp,0)-p.hpp AS numeric(18,2)) AS delta_hpp,
  CAST(ISNULL((SELECT MAX(c2.hpp) FROM tsales1 c1,tsales2 c2
        WHERE c1.bukti_id=c2.bukti_id AND c1.tipe_trans='88'
          AND c2.stok_id=p.stok_id AND c2.evap=p.evap AND ISNULL(c2.hpp,0)>0),0) AS numeric(18,2)) AS fallback_cost
INTO _cmp_hpp
FROM _pre_tsales2_hpp p, tsales2 b
WHERE p.bukti_id=b.bukti_id AND p.urut=b.urut AND ISNULL(b.hpp,0) <> p.hpp;

CREATE TABLE _val_result (gate varchar(40), status varchar(10), detail varchar(200));

-- ===== GATE 1 : SQL COMPILE / FULL BUILD (manual) =====
INSERT INTO _val_result
SELECT 'Gate1 SQL Compile',
  ISNULL((SELECT status FROM _gate_manual WHERE gate='Gate1 SQL Compile'),'PENDING'),
  'isi manual: INSERT INTO _gate_manual VALUES(''Gate1 SQL Compile'',''PASS'') stlh Full Build 0 error';

-- ===== GATE 2 : HPP REGRESSION (target 0) =====
INSERT INTO _val_result
SELECT 'Gate2 HPP Regression',
  CASE WHEN (SELECT COUNT(*) FROM _cmp_hpp
             WHERE NOT (evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost))=0
       THEN 'PASS' ELSE 'FAIL' END,
  'regression rows = ' || CAST((SELECT COUNT(*) FROM _cmp_hpp
      WHERE NOT (evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost)) AS varchar(20))
   || ' ; safe_change = ' || CAST((SELECT COUNT(*) FROM _cmp_hpp
      WHERE evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost) AS varchar(20));

-- ===== GATE 3 : COGS RECONCILE (|selisih| <= 5 tiap bulan) =====
INSERT INTO _val_result
SELECT 'Gate3 COGS Reconcile',
  CASE WHEN (SELECT COUNT(*) FROM (
       SELECT po.bln, ABS((po.hp_post-ISNULL(pr.hp_pre,0))-ISNULL(exp.d,0)) AS ab FROM
         (SELECT MONTH(tgl) bln,SUM(debet) hp_post FROM gl_journal WHERE posting='P' AND modul_id='HP'
            AND tgl>=(SELECT p1 FROM _cfg) AND tgl<(SELECT p2 FROM _cfg) GROUP BY MONTH(tgl)) po
         LEFT OUTER JOIN (SELECT bln,SUM(tot_debet) hp_pre FROM _pre_gl402 WHERE modul_id='HP' GROUP BY bln) pr ON pr.bln=po.bln
         LEFT OUTER JOIN (SELECT MONTH(tgl) bln,SUM(qty*delta_hpp) d FROM _cmp_hpp
            WHERE tipe_trans='22' AND evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost GROUP BY MONTH(tgl)) exp ON exp.bln=po.bln
       ) z WHERE ab > 5) = 0
       THEN 'PASS' ELSE 'FAIL' END,
  'bulan di luar ambang(>5) = ' || CAST((SELECT COUNT(*) FROM (
       SELECT po.bln, ABS((po.hp_post-ISNULL(pr.hp_pre,0))-ISNULL(exp.d,0)) AS ab FROM
         (SELECT MONTH(tgl) bln,SUM(debet) hp_post FROM gl_journal WHERE posting='P' AND modul_id='HP'
            AND tgl>=(SELECT p1 FROM _cfg) AND tgl<(SELECT p2 FROM _cfg) GROUP BY MONTH(tgl)) po
         LEFT OUTER JOIN (SELECT bln,SUM(tot_debet) hp_pre FROM _pre_gl402 WHERE modul_id='HP' GROUP BY bln) pr ON pr.bln=po.bln
         LEFT OUTER JOIN (SELECT MONTH(tgl) bln,SUM(qty*delta_hpp) d FROM _cmp_hpp
            WHERE tipe_trans='22' AND evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost GROUP BY MONTH(tgl)) exp ON exp.bln=po.bln
       ) z WHERE ab > 5) AS varchar(20));

-- ===== GATE 4 : INVENTORY CLEAN (phantom EVAP = 0) =====
INSERT INTO _val_result
SELECT 'Gate4 Inventory Clean',
  CASE WHEN (SELECT COUNT(*) FROM sinv s WHERE s.stok_id IN (SELECT stok_id FROM _evap_stok)
        AND s.periode>=(SELECT close1 FROM _cfg) AND s.periode<=(SELECT close2 FROM _cfg)
        AND ISNULL(s.qty,0)=0 AND ISNULL(s.nilai,0)<>0)=0
       THEN 'PASS' ELSE 'FAIL' END,
  'phantom (qty=0 & nilai<>0) = ' || CAST((SELECT COUNT(*) FROM sinv s WHERE s.stok_id IN (SELECT stok_id FROM _evap_stok)
        AND s.periode>=(SELECT close1 FROM _cfg) AND s.periode<=(SELECT close2 FROM _cfg)
        AND ISNULL(s.qty,0)=0 AND ISNULL(s.nilai,0)<>0) AS varchar(20));

-- ===== GATE 5 : TITIPAN RELEASE (penurunan ~ koreksi COGS) =====
INSERT INTO _val_result
SELECT 'Gate5 Titipan Release',
  CASE WHEN ABS(
      ( (SELECT opening+ytd_mutasi FROM _pre_titipan_102020)
        - ((SELECT opening FROM _pre_titipan_102020)
           + (SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal WHERE posting='P'
              AND account_id=(SELECT titipan_acc FROM _cfg) AND tgl<(SELECT p2 FROM _cfg))) )
      - (SELECT ISNULL(SUM(qty*delta_hpp),0) FROM _cmp_hpp
           WHERE tipe_trans='22' AND evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost)
    ) <= 5 THEN 'PASS' ELSE 'REVIEW' END,
  'turun_titipan vs koreksi_COGS (harus ~sama utk unit serial 1:1)';

-- ===== GATE 6 : REFRESH IDEMPOTENT (hpp identik antar 2 refresh) =====
INSERT INTO _val_result
SELECT 'Gate6 Refresh Idempotent',
  CASE WHEN NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='_post1_tsales2_hpp') THEN 'PENDING'
       WHEN (SELECT COUNT(*) FROM _post1_tsales2_hpp p1, tsales2 b
             WHERE p1.bukti_id=b.bukti_id AND p1.urut=b.urut
               AND CAST(ISNULL(b.hpp,0) AS numeric(18,2)) <> p1.hpp)=0
       THEN 'PASS' ELSE 'FAIL' END,
  'beda hpp antar refresh#1 vs #2 (butuh _post1_tsales2_hpp)';

-- ===== HARDENING (blocking bila >0 utk dup/future; WARN utk orphan) =====
INSERT INTO _val_result
SELECT 'Harden Dup-Cost',
  CASE WHEN (SELECT COUNT(*) FROM (SELECT c2.stok_id,c2.evap FROM tsales1 c1,tsales2 c2
       WHERE c1.bukti_id=c2.bukti_id AND c1.tipe_trans='88' AND ISNULL(c2.evap,'')<>'' AND ISNULL(c2.hpp,0)>0
       GROUP BY c2.stok_id,c2.evap HAVING COUNT(DISTINCT CAST(c2.hpp AS numeric(18,2)))>1) d)=0
       THEN 'PASS' ELSE 'FAIL' END,
  '(stok,evap) dgn >1 HPP consout beda (MAX jadi arbitrer)';

INSERT INTO _val_result
SELECT 'Harden Future-Cost',
  CASE WHEN (SELECT COUNT(*) FROM tsales1 s1,tsales2 s2
       WHERE s1.bukti_id=s2.bukti_id AND s1.tipe_trans='22' AND ISNULL(s2.evap,'')<>'' AND ISNULL(s2.hpp,0)=0
         AND s1.tgl>=(SELECT p1 FROM _cfg) AND s1.tgl<(SELECT p2 FROM _cfg)
         AND NOT EXISTS(SELECT 1 FROM tsales1 c1,tsales2 c2 WHERE c1.bukti_id=c2.bukti_id AND c1.tipe_trans='88'
              AND c2.stok_id=s2.stok_id AND c2.evap=s2.evap AND ISNULL(c2.hpp,0)>0 AND c1.tgl<=s1.tgl)
         AND EXISTS(SELECT 1 FROM tsales1 c1,tsales2 c2 WHERE c1.bukti_id=c2.bukti_id AND c1.tipe_trans='88'
              AND c2.stok_id=s2.stok_id AND c2.evap=s2.evap AND ISNULL(c2.hpp,0)>0 AND c1.tgl>s1.tgl))=0
       THEN 'PASS' ELSE 'FAIL' END,
  'consout hanya ADA setelah tgl jual (fallback pakai cost masa depan)';

INSERT INTO _val_result
SELECT 'Harden Orphan',
  CASE WHEN (SELECT COUNT(*) FROM tsales1 s1,tsales2 s2
       WHERE s1.bukti_id=s2.bukti_id AND s1.tipe_trans='22' AND ISNULL(s2.evap,'')<>'' AND ISNULL(s2.hpp,0)=0 AND s2.qty>0
         AND s1.tgl>=(SELECT p1 FROM _cfg) AND s1.tgl<(SELECT p2 FROM _cfg)
         AND NOT EXISTS(SELECT 1 FROM tsales1 c1,tsales2 c2 WHERE c1.bukti_id=c2.bukti_id AND c1.tipe_trans='88'
              AND c2.stok_id=s2.stok_id AND c2.evap=s2.evap AND ISNULL(c2.hpp,0)>0))=0
       THEN 'PASS' ELSE 'WARN' END,
  'jual EVAP hpp=0 TANPA consout -> tetap understated (fallback tak menolong)';

-- ============================= LAPORAN =============================
SELECT '==================================' AS "EVAP PATCH VALIDATION RESULT" FROM SYS.DUMMY
UNION ALL SELECT gate || ' : ' || status || '   [' || ISNULL(detail,'') || ']' FROM _val_result;

-- ============================= KEPUTUSAN =============================
SELECT CASE
   WHEN (SELECT COUNT(*) FROM _val_result WHERE status IN ('FAIL','PENDING')) = 0
        AND (SELECT COUNT(*) FROM _val_result WHERE gate='Harden Orphan' AND status='WARN') = 0
     THEN 'READY FOR PRODUCTION'
   WHEN (SELECT COUNT(*) FROM _val_result WHERE status IN ('FAIL','PENDING')) = 0
     THEN 'READY (dgn catatan: WARN orphan harus di-triase manual)'
   ELSE 'NO-GO'
END AS "DECISION"
FROM SYS.DUMMY;
