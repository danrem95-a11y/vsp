-- ============================================================================
-- validation_inventory_balance.sql -- VALIDASI FINAL (read-only) setelah fix engine + repair + refresh
-- LOLOS = A gap movement<=Rp1 semua akun, B HPP=0 costing=0, C WIP guard tetap, D idempotent.
-- ============================================================================
IF VAREXISTS('p_from')=1 THEN DROP VARIABLE p_from END IF;
IF VAREXISTS('p_next')=1 THEN DROP VARIABLE p_next END IF;
CREATE VARIABLE p_from DATE; SET p_from='2026-01-01';
CREATE VARIABLE p_next DATE; SET p_next='2026-03-01';   -- closing akhir (opening bln+1 terakhir)

-- A. MOVEMENT: GL movement = Stock movement (Δsinv) per akun 102 (target <= Rp1)
SELECT p.acc,
  cast(isnull(gj.v,0) as numeric(18,2)) gl_mov,
  cast(isnull(sc.v,0)-isnull(so.v,0) as numeric(18,2)) stock_mov,
  cast((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0) as numeric(18,2)) selisih,
  IF abs((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0))<=1 THEN 'OK' ELSE '*** SISA ***' ENDIF st
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE persediaan LIKE '102%') p
LEFT JOIN (SELECT account_id a, sum(isnull(debet,0)-isnull(kredit,0)) v FROM gl_journal WHERE tgl BETWEEN p_from AND dateadd(day,-1,p_next) GROUP BY account_id) gj ON gj.a=p.acc
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=p_from GROUP BY gr.persediaan) so ON so.a=p.acc
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=p_next GROUP BY gr.persediaan) sc ON sc.a=p.acc
WHERE isnull(gj.v,0)<>0 OR isnull(sc.v,0)<>0 OR isnull(so.v,0)<>0
ORDER BY abs((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0)) DESC;

-- A2. TOTAL absolut gap tersisa (target 0)
SELECT cast(sum(abs(g)) as numeric(20,2)) total_abs_gap, count(*) n_akun_sisa FROM (
 SELECT p.acc, (isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0) g
 FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE persediaan LIKE '102%') p
 LEFT JOIN (SELECT account_id a, sum(isnull(debet,0)-isnull(kredit,0)) v FROM gl_journal WHERE tgl BETWEEN p_from AND dateadd(day,-1,p_next) GROUP BY account_id) gj ON gj.a=p.acc
 LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=p_from GROUP BY gr.persediaan) so ON so.a=p.acc
 LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=p_next GROUP BY gr.persediaan) sc ON sc.a=p.acc
) t WHERE abs(g)>1;

-- B. COSTING: jual '22' HPP=0 pada item ber-cost-basis (harus 0 baris = tak ada COGS hilang)
SELECT count(*) jual_hpp0_bercost_HARUS_0
FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID
JOIN im_produk pr ON pr.produk_id=s2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE s1.TIPE_TRANS='22' AND isnull(s2.HPP,0)=0 AND s1.TGL BETWEEN p_from AND dateadd(day,-1,p_next)
  AND gr.persediaan LIKE '102%' AND gr.persediaan<>'102-020' AND isnull(s2.EVAP,'')=''
  AND EXISTS(SELECT 1 FROM sinv sv WHERE sv.stok_id=s2.STOK_ID AND sv.periode<=p_from AND isnull(sv.hpp_avg,0)>0);
-- B2. mutasi '19' bernilai 0 pada item ber-cost (harus 0)
SELECT count(*) mutasi19_nol_bercost_HARUS_0
FROM tstok2 t2 JOIN tstok1 t1 ON t1.BUKTI_ID=t2.BUKTI_ID
JOIN im_produk pr ON pr.produk_id=t2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE t1.TIPE_TRANS='19' AND isnull(t2.NETTO,0)=0 AND isnull(t2.QTY,0)<>0 AND t1.TGL BETWEEN p_from AND dateadd(day,-1,p_next)
  AND gr.persediaan LIKE '102%' AND gr.persediaan<>'102-020';

-- C. WIP GUARD: 102-020 GL & HPP-WIP '88' tetap (bandingkan ke baseline pra-fix)
SELECT 'wip020_GL' k, cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(20,2)) v FROM gl_journal WHERE account_id='102-020'
UNION ALL SELECT 'hpp_wip88', cast(sum(isnull(hpp,0)*isnull(qty,0)) as numeric(22,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.BUKTI_ID=s2.BUKTI_ID WHERE s1.TIPE_TRANS='88'
UNION ALL SELECT 'opening_102001', cast(sum(isnull(sv.nilai,0)) as numeric(20,2)) FROM sinv sv,im_produk pr,im_product_group gr WHERE pr.produk_id=sv.stok_id AND gr.kode_group=pr.group_product AND sv.periode='2026-01-01' AND gr.persediaan='102-001';

-- D. IDEMPOTENCY: checksum sinv closing (ulang refresh -> harus identik)
SELECT periode, cast(sum(isnull(qty,0)) as numeric(20,2)) sq, cast(sum(isnull(nilai,0)) as numeric(24,2)) sn
FROM sinv WHERE periode IN (p_from, p_next) GROUP BY periode ORDER BY periode;
