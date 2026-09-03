-- ============================================================================
-- EVIDENCE: REKONSILIASI 4-ARAH untuk OPENING = engine | GL | sinv | laporan-mutasi
--   engine    = _engine_dec  (dw_refresh_stok closing prior: dari transaksi + sinv prior)  [INDEPENDEN]
--   GL        = gl_balance[target]  (dari posting jurnal)                                    [INDEPENDEN]
--   sinv      = sinv[target]  (snapshot tersimpan -- yang divalidasi)
--   lap_mutasi= AWAL yang DITAMPILKAN laporan dw_stok_gl_mutasi utk bulan target
--               (pakai subquery AWAL ASLI report: SUM(sinv) per periode target) -> membuktikan
--               laporan akan MENAMPILKAN nilai terkoreksi (report baca sinv => lap_mutasi=sinv by design)
-- Prasyarat: _engine_dec (recovery STEP2) + sudah UPDATE (STEP4).
-- ============================================================================
IF VAREXISTS('target_opening_period')=1 THEN DROP VARIABLE target_opening_period END IF;
CREATE VARIABLE target_opening_period DATE; SET target_opening_period='2026-01-01';  -- samakan dg recovery
IF VAREXISTS('prior_snapshot')=1 THEN DROP VARIABLE prior_snapshot END IF;
CREATE VARIABLE prior_snapshot DATE; SET prior_snapshot = dateadd(month,-1,target_opening_period);

-- 4A. PER AKUN 102 (diagregasi per persediaan; 1 akun bisa banyak kode_group): engine vs GL vs sinv vs lap_mutasi
SELECT p.persediaan akun,
  cast(isnull(en.v,0) as numeric(20,2)) engine, cast(isnull(g.v,0) as numeric(20,2)) gl,
  cast(isnull(sv.v,0) as numeric(20,2)) sinv, cast(isnull(lm.v,0) as numeric(20,2)) lap_mutasi,
  cast(isnull(en.v,0)-isnull(g.v,0) as numeric(18,2)) d_eng_gl,
  cast(isnull(sv.v,0)-isnull(en.v,0) as numeric(18,2)) d_sinv_eng,
  cast(isnull(lm.v,0)-isnull(sv.v,0) as numeric(18,2)) d_lap_sinv
FROM (SELECT DISTINCT persediaan FROM im_product_group WHERE persediaan LIKE '102%') p
LEFT JOIN (SELECT gr.persediaan acc, sum(isnull(e.nilai,0)) v FROM _engine_dec e JOIN im_produk pr ON pr.produk_id=e.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product GROUP BY gr.persediaan) en ON en.acc=p.persediaan
LEFT JOIN (SELECT AccountCode acc, sum(isnull(AmountDebet,0)-isnull(AmountCredit,0)) v FROM gl_balance WHERE Period=target_opening_period GROUP BY AccountCode) g ON g.acc=p.persediaan
LEFT JOIN (SELECT gr.persediaan acc, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode=target_opening_period GROUP BY gr.persediaan) sv ON sv.acc=p.persediaan
LEFT JOIN (SELECT gr.persediaan acc, sum(isnull(aw.AWAL_RP,0)) v FROM
     (SELECT SINV.STOK_ID K, sum(isnull(SINV.NILAI,0)) AWAL_RP FROM SINV
        WHERE SINV.PERIODE >= dateadd(month,datediff(month,'1900-01-01',target_opening_period),'1900-01-01')
          AND SINV.PERIODE <  dateadd(month,datediff(month,'1900-01-01',target_opening_period)+1,'1900-01-01')
        GROUP BY SINV.STOK_ID) aw
     JOIN im_produk pr ON pr.produk_id=aw.K JOIN im_product_group gr ON gr.kode_group=pr.group_product GROUP BY gr.persediaan) lm ON lm.acc=p.persediaan
WHERE isnull(en.v,0)<>0 OR isnull(g.v,0)<>0 OR isnull(sv.v,0)<>0
ORDER BY abs(isnull(sv.v,0)-isnull(g.v,0)) DESC;

-- 4B. DRILL per stok_id akun 102-001: engine vs sinv (setelah koreksi HARUS ~0)
SELECT e.stok_id,
  cast(e.akhir as numeric(14,2)) engine_qty, cast(sv.qty as numeric(14,2)) sinv_qty,
  cast(e.nilai as numeric(20,2)) engine_nil, cast(sv.nilai as numeric(20,2)) sinv_nil,
  cast(sv.nilai-e.nilai as numeric(20,2)) selisih
FROM _engine_dec e JOIN sinv sv ON sv.stok_id=e.stok_id AND sv.periode=target_opening_period
JOIN im_produk pr ON pr.produk_id=e.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE gr.persediaan='102-001' AND abs(sv.nilai-e.nilai)>1
ORDER BY abs(sv.nilai-e.nilai) DESC;

-- 4C. STABILITAS laporan mutasi PRIOR (Desember): AWAL baca sinv[prior_snapshot] -- tak disentuh recovery
SELECT 'lap_mutasi_prior_AWAL (sinv[prior])' info,
       cast(sum(isnull(nilai,0)) as numeric(20,2)) nilai_sekarang,
       (SELECT v FROM _guard WHERE k='prior_open_nil') baseline_sebelum_recovery,
       cast(sum(nilai)-(SELECT v FROM _guard WHERE k='prior_open_nil') as numeric(20,2)) delta_HARUS_0
FROM sinv WHERE periode=prior_snapshot;
