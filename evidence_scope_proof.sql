-- ============================================================================
-- EVIDENCE: SCOPE PROOF -- BUKTI UPDATE hanya menyentuh sinv[target_opening_period].
-- Dijalankan SETELAH recovery_mekA_opening.sql STEP 4 (butuh _sinv_ck_before, _sinv_target_before).
-- Semua "HARUS 0" wajib 0; jika tidak, paket TIDAK production-ready.
-- ============================================================================
IF VAREXISTS('target_opening_period')=1 THEN DROP VARIABLE target_opening_period END IF;
CREATE VARIABLE target_opening_period DATE; SET target_opening_period='2026-01-01';  -- samakan dg recovery

-- A. PER-PERIODE: tampilkan HANYA periode yang berubah (checksum seluruh 166 periode sinv sebelum vs sesudah).
--    HARUS: tepat 1 baris = target_opening_period. Baris lain apa pun = FAIL.
SELECT coalesce(a.periode,b.periode) periode, isnull(b.n,0) n_before, isnull(a.n,0) n_after,
  cast(isnull(a.sn,0)-isnull(b.sn,0) as numeric(24,2)) d_nilai,
  IF coalesce(a.periode,b.periode)=target_opening_period THEN 'TARGET (boleh berubah)' ELSE '*** FAIL: berubah di luar target ***' ENDIF status
FROM _sinv_ck_before b FULL OUTER JOIN
  (SELECT periode, count(*) n, sum(isnull(qty,0)) sq, sum(isnull(nilai,0)) sn FROM sinv GROUP BY periode) a ON a.periode=b.periode
WHERE isnull(a.n,0)<>isnull(b.n,0) OR isnull(a.sq,0)<>isnull(b.sq,0) OR isnull(a.sn,0)<>isnull(b.sn,0);

-- B. RINGKAS: periode berubah DI LUAR target (HARUS 0) + perubahan jumlah periode (HARUS 0)
SELECT
 (SELECT count(*) FROM _sinv_ck_before b FULL OUTER JOIN
    (SELECT periode,count(*) n,sum(isnull(qty,0)) sq,sum(isnull(nilai,0)) sn FROM sinv GROUP BY periode) a ON a.periode=b.periode
    WHERE coalesce(a.periode,b.periode)<>target_opening_period
      AND (isnull(a.n,0)<>isnull(b.n,0) OR isnull(a.sq,0)<>isnull(b.sq,0) OR isnull(a.sn,0)<>isnull(b.sn,0))
 ) periode_berubah_diluar_target_HARUS_0,
 ((SELECT count(distinct periode) FROM sinv) - (SELECT count(*) FROM _sinv_ck_before)) selisih_jumlah_periode_HARUS_0;

-- C. ROW-LEVEL periode target: per stok_id & site -> berubah vs tidak; hpp_avg berubah HARUS 0
SELECT
  sum(IF n.qty<>o.qty OR n.nilai<>o.nilai THEN 1 ELSE 0 ENDIF) row_berubah,
  sum(IF n.qty=o.qty AND n.nilai=o.nilai THEN 1 ELSE 0 ENDIF) row_tidak_berubah,
  count(*) total_row_target,
  sum(IF n.hpp_avg<>o.hpp_avg THEN 1 ELSE 0 ENDIF) row_HPP_AVG_berubah_HARUS_0
FROM _sinv_target_before o JOIN sinv n
  ON n.stok_id=o.stok_id AND n.site_id=o.site_id AND n.periode=o.periode;

-- D. INSERT/DELETE di target = 0 (jumlah baris target sama sebelum/sesudah)
SELECT (SELECT count(*) FROM sinv WHERE periode=target_opening_period) n_after_target,
       (SELECT count(*) FROM _sinv_target_before) n_before_target,
       (SELECT count(*) FROM sinv WHERE periode=target_opening_period)-(SELECT count(*) FROM _sinv_target_before) selisih_HARUS_0;

-- E. DETAIL granular per stok_id/site yang berubah di target (audit; nilai turun DESC)
SELECT gr.persediaan akun, o.stok_id, o.site_id,
  cast(o.qty as numeric(14,2)) qty_before, cast(n.qty as numeric(14,2)) qty_after,
  cast(o.nilai as numeric(20,2)) nilai_before, cast(n.nilai as numeric(20,2)) nilai_after,
  cast(o.hpp_avg as numeric(18,4)) hpp_before, cast(n.hpp_avg as numeric(18,4)) hpp_after
FROM _sinv_target_before o JOIN sinv n ON n.stok_id=o.stok_id AND n.site_id=o.site_id AND n.periode=o.periode
JOIN im_produk pr ON pr.produk_id=o.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE o.qty<>n.qty OR o.nilai<>n.nilai OR o.hpp_avg<>n.hpp_avg
ORDER BY abs(o.nilai-n.nilai) DESC;
