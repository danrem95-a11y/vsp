-- ============================================================================
-- VALIDASI RECOVERY -- guard prior-year FROZEN + opening=GL + coverage. Prasyarat: _guard (recovery STEP1).
-- LOLOS = A semua delta 0, B semua gap<=Rp1 (kecuali 102-201, catatan), coverage aman.
-- ============================================================================
IF VAREXISTS('target_opening_period')=1 THEN DROP VARIABLE target_opening_period END IF;
CREATE VARIABLE target_opening_period DATE; SET target_opening_period='2026-01-01';  -- samakan dg recovery
IF VAREXISTS('prior_snapshot')=1 THEN DROP VARIABLE prior_snapshot END IF;
IF VAREXISTS('closing_to')=1     THEN DROP VARIABLE closing_to     END IF;
IF VAREXISTS('move_from')=1      THEN DROP VARIABLE move_from      END IF;
IF VAREXISTS('move_to')=1        THEN DROP VARIABLE move_to        END IF;
CREATE VARIABLE prior_snapshot DATE; SET prior_snapshot = dateadd(month,-1,target_opening_period);
CREATE VARIABLE closing_to     DATE; SET closing_to     = dateadd(day,-1,target_opening_period);
CREATE VARIABLE move_from      DATE; SET move_from      = target_opening_period;
CREATE VARIABLE move_to        DATE; SET move_to        = dateadd(day,-1,dateadd(month,1,target_opening_period));

-- A. GUARD prior-year FROZEN + WIP/HPP -- delta HARUS 0
SELECT m.k metric, m.v baseline, m.cur sekarang, cast(m.cur-m.v as numeric(24,2)) delta,
   IF abs(m.cur-m.v)<=0.01 THEN 'OK frozen' ELSE '*** FAIL ***' ENDIF status
FROM ( SELECT g.k,g.v, CASE g.k
   WHEN 'prior_open_qty' THEN (SELECT cast(sum(isnull(qty,0))   as numeric(24,2)) FROM sinv WHERE periode=prior_snapshot)
   WHEN 'prior_open_nil' THEN (SELECT cast(sum(isnull(nilai,0)) as numeric(24,2)) FROM sinv WHERE periode=prior_snapshot)
   WHEN 'gl_prior'       THEN (SELECT cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(24,2)) FROM gl_journal WHERE tgl<=closing_to)
   WHEN 'move_tx'        THEN (SELECT cast(isnull(sum(isnull(qty,0)),0) as numeric(24,2)) FROM tsales2 s2 JOIN tsales1 s1 ON s1.bukti_id=s2.bukti_id WHERE s1.tgl BETWEEN move_from AND move_to)
   WHEN 'wip020'         THEN (SELECT cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(24,2)) FROM gl_journal WHERE account_id='102-020')
   WHEN 'hppwip'         THEN (SELECT cast(sum(isnull(hpp,0)*isnull(qty,0)) as numeric(24,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tipe_trans='88')
 END cur FROM _guard g ) m;

-- B. OPENING = GL per akun persediaan (derived-table; ORDER BY alias) -- gap HARUS <= Rp1
SELECT akun, cast(sinv_opening as numeric(20,2)) sinv_opening, cast(gl_opening as numeric(20,2)) gl_opening,
       cast(sinv_opening-gl_opening as numeric(20,2)) gap
FROM ( SELECT gr.persediaan akun, sum(isnull(sv.nilai,0)) sinv_opening,
         (SELECT sum(isnull(AmountDebet,0)-isnull(AmountCredit,0)) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period=target_opening_period) gl_opening
   FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
   WHERE sv.periode=target_opening_period AND gr.persediaan LIKE '102%'
   GROUP BY gr.persediaan ) t
ORDER BY abs(sinv_opening-gl_opening) DESC;
-- CATATAN: 102-201 (MT) diharapkan gap ~ -23,96 jt = isu saldo-awal GL MT TERPISAH (sinv=engine, GL lebih tinggi),
--          BUKAN phantom sinv; Mekanisme A tidak menyentuhnya. Akun 102 LAIN harus ~0.

-- C. COVERAGE: sinv[target] semua tercakup engine (HARUS 0), engine di luar sinv nilainya (HARUS 0)
SELECT 'sinv_not_in_engine' cek, count(*) n, cast(isnull(sum(isnull(sv.nilai,0)),0) as numeric(20,2)) nilai_HARUS_0
  FROM sinv sv WHERE sv.periode=target_opening_period AND NOT EXISTS(SELECT 1 FROM _engine_dec e WHERE e.stok_id=sv.stok_id)
UNION ALL
SELECT 'engine_not_in_sinv', count(*), cast(isnull(sum(isnull(e.nilai,0)),0) as numeric(20,2))
  FROM _engine_dec e WHERE NOT EXISTS(SELECT 1 FROM sinv sv WHERE sv.periode=target_opening_period AND sv.stok_id=e.stok_id);

-- D. IDEMPOTENCY checksum (simpan, ulangi recovery+recompute, bandingkan -> delta 0)
SELECT periode, cast(sum(isnull(qty,0)) as numeric(20,2)) sum_qty, cast(sum(isnull(nilai,0)) as numeric(24,2)) sum_nilai
FROM sinv WHERE periode IN (target_opening_period, dateadd(month,1,target_opening_period)) GROUP BY periode ORDER BY periode;
