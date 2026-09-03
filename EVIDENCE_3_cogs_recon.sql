-- =====================================================================
-- EVIDENCE #3  COGS RECONCILIATION   (ASA9)
-- Jalankan SETELAH EVIDENCE_2 (butuh _cmp_hpp) di DB COPY, pasca refresh.
-- Membuktikan: kenaikan jurnal COGS (modul 'HP') = SUM(qty x delta_hpp)
-- pada baris penjualan (tipe 22) yg dikoreksi.  Selisih harus <= pembulatan.
-- Catatan: modul 'HP' = COGS penjualan; tipe 88 (consout) -> titipan (EVIDENCE_4).
-- =====================================================================
SELECT
  po.bln,
  CAST(exp.delta_hpp_sales AS numeric(18,2))                          AS delta_hpp_sales,
  CAST(po.hp_post - ISNULL(pr.hp_pre,0) AS numeric(18,2))             AS delta_gl402,
  CAST((po.hp_post - ISNULL(pr.hp_pre,0)) - ISNULL(exp.delta_hpp_sales,0) AS numeric(18,2)) AS selisih
FROM
  -- COGS (modul HP) LIVE per bulan
  (SELECT MONTH(tgl) AS bln, SUM(debet) AS hp_post
     FROM gl_journal
     WHERE posting='P' AND modul_id='HP'
       AND tgl >= (SELECT p1 FROM _cfg) AND tgl < (SELECT p2 FROM _cfg)
     GROUP BY MONTH(tgl)) po
  LEFT OUTER JOIN
  -- COGS (modul HP) BASELINE per bulan
  (SELECT bln, SUM(tot_debet) AS hp_pre
     FROM _pre_gl402 WHERE modul_id='HP' GROUP BY bln) pr ON pr.bln = po.bln
  LEFT OUTER JOIN
  -- ekspektasi kenaikan COGS = SUM(qty x delta_hpp) baris jual (tipe 22) yg SAFE
  (SELECT MONTH(tgl) AS bln, SUM(qty*delta_hpp) AS delta_hpp_sales
     FROM _cmp_hpp
     WHERE tipe_trans='22' AND evap <> '' AND fallback_cost > 0 AND hpp_post = fallback_cost
     GROUP BY MONTH(tgl)) exp ON exp.bln = po.bln
ORDER BY po.bln;

-- Ambang: |selisih| <= 5 (pembulatan). Baris dgn selisih di luar ambang = ALARM.
SELECT 'ALARM_COGS_SELISIH' AS flag, bln, selisih FROM (
  SELECT po.bln,
    CAST((po.hp_post - ISNULL(pr.hp_pre,0)) - ISNULL(exp.delta_hpp_sales,0) AS numeric(18,2)) AS selisih
  FROM
   (SELECT MONTH(tgl) bln, SUM(debet) hp_post FROM gl_journal
      WHERE posting='P' AND modul_id='HP' AND tgl>=(SELECT p1 FROM _cfg) AND tgl<(SELECT p2 FROM _cfg)
      GROUP BY MONTH(tgl)) po
   LEFT OUTER JOIN (SELECT bln, SUM(tot_debet) hp_pre FROM _pre_gl402 WHERE modul_id='HP' GROUP BY bln) pr ON pr.bln=po.bln
   LEFT OUTER JOIN (SELECT MONTH(tgl) bln, SUM(qty*delta_hpp) delta_hpp_sales FROM _cmp_hpp
      WHERE tipe_trans='22' AND evap<>'' AND fallback_cost>0 AND hpp_post=fallback_cost GROUP BY MONTH(tgl)) exp ON exp.bln=po.bln
) x WHERE ABS(selisih) > 5;
