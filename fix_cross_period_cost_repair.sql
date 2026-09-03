-- ============================================================================
-- fix_cross_period_cost_repair.sql -- REPAIR data historis rusak: jual '22' HPP=0
--   yang cost-basis-nya HANYA ada di periode SEBELUMNYA (engine monthly-isolated tak bisa isi).
-- Isi tsales2.HPP = moving-avg VALID terakhir (dari sinv, periode <= bulan jual, hpp_avg>0).
-- Ini LINTAS-PERIODE -> SENGAJA di SQL manual, BUKAN di engine (engine tetap per-bulan).
-- Engine step 4a sudah di-guard: HRG=0 -> pertahankan HPP -> hasil repair ini TIDAK ditimpa refresh.
-- LARANGAN: tidak sentuh WIP 102-020/'88', tidak buat jurnal, idempotent, ada preview+backup+rollback.
-- !!! COPY-DB DULU. Verifikasi property('MachineName') = mesin TEST. !!!
-- ============================================================================
IF VAREXISTS('p_from')=1 THEN DROP VARIABLE p_from END IF;
IF VAREXISTS('p_to')=1   THEN DROP VARIABLE p_to   END IF;
CREATE VARIABLE p_from DATE; SET p_from='2026-01-01';
CREATE VARIABLE p_to   DATE; SET p_to  ='2026-02-28';

-- kandidat + nilai repair (cost valid historis terakhir)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_xrepair') THEN DROP TABLE _xrepair END IF;
SELECT s2.BUKTI_ID, s2.URUT, s2.STOK_ID, gr.persediaan akun, s1.TGL, s1.USER_ID,
       cast(s2.QTY as numeric(14,2)) qty, cast(isnull(s2.HPP,0) as numeric(14,2)) hpp_lama,
       cast( (SELECT FIRST sv.hpp_avg FROM sinv sv
                WHERE sv.stok_id=s2.STOK_ID
                  AND sv.periode <= dateadd(month,datediff(month,'1900-01-01',s1.TGL),'1900-01-01')
                  AND isnull(sv.hpp_avg,0)>0 ORDER BY sv.periode DESC) as numeric(16,4)) hpp_baru
INTO _xrepair
FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID
JOIN im_produk pr ON pr.produk_id=s2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE s1.TIPE_TRANS='22' AND isnull(s2.HPP,0)=0 AND s1.TGL BETWEEN p_from AND p_to
  AND gr.persediaan LIKE '102%' AND gr.persediaan<>'102-020'
  AND isnull(s2.EVAP,'')='' ;
DELETE FROM _xrepair WHERE isnull(hpp_baru,0)<=0;   -- item tanpa cost historis (legacy) TIDAK disentuh
COMMIT;

-- STEP 0: BACKUP baris terdampak
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_tsales2_hpp_bak') THEN DROP TABLE _tsales2_hpp_bak END IF;
SELECT s2.* INTO _tsales2_hpp_bak FROM tsales2 s2 WHERE EXISTS(SELECT 1 FROM _xrepair r WHERE r.BUKTI_ID=s2.BUKTI_ID AND r.URUT=s2.URUT);
COMMIT;

-- STEP 1: PREVIEW (setujui dulu) -- item lintas-periode + cost historis + nilai koreksi
SELECT akun, STOK_ID, BUKTI_ID, TGL, USER_ID, qty, hpp_lama, cast(hpp_baru as numeric(16,2)) hpp_baru,
       cast(qty*hpp_baru as numeric(18,2)) nilai_koreksi FROM _xrepair ORDER BY akun, TGL;
SELECT akun, count(*) n, cast(sum(qty*hpp_baru) as numeric(20,2)) total_koreksi FROM _xrepair GROUP BY akun ORDER BY akun;

-- STEP 2: APPLY (buka komentar setelah PREVIEW OK) -- hanya sumber tsales2.HPP, hanya kandidat bercost
-- UPDATE tsales2 SET HPP=r.hpp_baru FROM _xrepair r WHERE tsales2.BUKTI_ID=r.BUKTI_ID AND tsales2.URUT=r.URUT; COMMIT;

-- STEP 3: REFRESH RESMI p_from..p_to (aplikasi) -> re-post COGS dari HPP repair; engine guard menjaga nilai.

-- STEP 4: VERIFY (validation_inventory_balance.sql): GL=stok, HPP=0 tersisa, WIP tetap, idempotent.
-- IDEMPOTENT: ulang script -> _xrepair 0 baris (HPP sudah terisi).

-- ROLLBACK: UPDATE tsales2 SET HPP=b.HPP FROM _tsales2_hpp_bak b WHERE tsales2.BUKTI_ID=b.BUKTI_ID AND tsales2.URUT=b.URUT; COMMIT;
