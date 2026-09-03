-- ============================================================================
-- validation_costing.sql -- VALIDASI setelah fix_costing_2026.sql + REFRESH RESMI (read-only)
-- LOLOS = A gap<=Rp1 (akun terfix), B WIP tetap, C opening tetap, D idempotent.
-- ============================================================================
IF VAREXISTS('p_from')=1 THEN DROP VARIABLE p_from END IF;
IF VAREXISTS('p_next')=1 THEN DROP VARIABLE p_next END IF;
CREATE VARIABLE p_from DATE; SET p_from='2026-01-01';         -- awal periode
CREATE VARIABLE p_next DATE; SET p_next='2026-03-01';         -- closing akhir (opening bulan+1 terakhir)

-- A. GL movement = Stock movement per akun persediaan (target <= Rp1)
SELECT p.acc,
  cast(isnull(gj.v,0) as numeric(18,2)) gl_mov,
  cast(isnull(sc.v,0)-isnull(so.v,0) as numeric(18,2)) stock_mov,
  cast((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0) as numeric(18,2)) selisih,
  IF abs((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0))<=1 THEN 'OK (<=Rp1)' ELSE '*** SISA ***' ENDIF status
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE persediaan LIKE '102%') p
LEFT JOIN (SELECT account_id a, sum(isnull(debet,0)-isnull(kredit,0)) v FROM gl_journal WHERE tgl BETWEEN p_from AND dateadd(day,-1,p_next) GROUP BY account_id) gj ON gj.a=p.acc
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=p_from GROUP BY gr.persediaan) so ON so.a=p.acc
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=p_next GROUP BY gr.persediaan) sc ON sc.a=p.acc
WHERE isnull(gj.v,0)<>0 OR isnull(sc.v,0)<>0 OR isnull(so.v,0)<>0
ORDER BY abs((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0)) DESC;

-- B. WIP 102-020 & HPP-WIP TETAP (bandingkan ke nilai baseline yang dicatat sebelum fix)
SELECT 'wip020_GL' k, cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(20,2)) v FROM gl_journal WHERE account_id='102-020'
UNION ALL
SELECT 'hpp_wip_88', cast(sum(isnull(hpp,0)*isnull(qty,0)) as numeric(20,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.BUKTI_ID=s2.BUKTI_ID WHERE s1.TIPE_TRANS='88';
-- (fix TIDAK menyentuh '88'/102-020; nilai ini harus = baseline pra-fix)

-- C. OPENING 2026 TETAP (sinv[2026-01-01] tak berubah oleh fix costing)
SELECT gr.persediaan akun, cast(sum(isnull(sv.nilai,0)) as numeric(20,2)) opening_2026
FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE sv.periode=p_from AND gr.persediaan LIKE '102%' GROUP BY gr.persediaan ORDER BY gr.persediaan;
-- (harus identik dengan opening hasil recovery Mekanisme A)

-- D. IDEMPOTENCY: ulang fix (HPP sudah terisi -> 0 kandidat) + refresh -> checksum sinv identik
SELECT count(*) sisa_kandidat_HARUS_0 FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID
  JOIN im_produk pr ON pr.produk_id=s2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE s1.TIPE_TRANS='22' AND isnull(s2.HPP,0)=0 AND s1.TGL BETWEEN p_from AND dateadd(day,-1,p_next)
  AND gr.persediaan<>'102-020'
  AND EXISTS(SELECT 1 FROM sinv sv WHERE sv.stok_id=s2.STOK_ID AND sv.periode=p_from AND isnull(sv.hpp_avg,0)>0);
