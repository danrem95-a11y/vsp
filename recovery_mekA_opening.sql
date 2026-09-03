-- ============================================================================
-- RECOVERY MEKANISME A -- KOREKSI SNAPSHOT OPENING (perbaikan DATA TURUNAN, NOL transaksi)
-- PARAMETERIZED: satu-satunya yang perlu diubah = target_opening_period (anchor).
--   closing_from/closing_to/prior_snapshot/move_from/move_to DIDERIVASI otomatis. NOL hardcode tahun.
-- Prinsip: prior-year (closing) FROZEN. Tidak re-close, tidak buat transaksi/mutasi/jurnal.
-- Menyentuh HANYA snapshot sinv[target_opening_period] (kolom QTY & NILAI). HPP_AVG TIDAK diubah.
-- !!! COPY-DB DULU: pastikan select property('MachineName') = mesin TEST, bukan prod. !!!
-- ============================================================================

-- ==== PARAMETER (ubah HANYA baris SET target_opening_period ini) ====
IF VAREXISTS('target_opening_period')=1 THEN DROP VARIABLE target_opening_period END IF;
CREATE VARIABLE target_opening_period DATE;
SET target_opening_period = '2026-01-01';   -- <== anchor: awal-bulan opening yang dikoreksi

-- ==== DERIVED (jangan diubah manual) ====
IF VAREXISTS('closing_from')=1   THEN DROP VARIABLE closing_from   END IF;
IF VAREXISTS('closing_to')=1     THEN DROP VARIABLE closing_to     END IF;
IF VAREXISTS('prior_snapshot')=1 THEN DROP VARIABLE prior_snapshot END IF;
IF VAREXISTS('move_from')=1      THEN DROP VARIABLE move_from      END IF;
IF VAREXISTS('move_to')=1        THEN DROP VARIABLE move_to        END IF;
CREATE VARIABLE closing_from   DATE; SET closing_from   = dateadd(month,-1,target_opening_period);      -- awal bulan prior (=snapshot beku)
CREATE VARIABLE closing_to     DATE; SET closing_to     = dateadd(day,-1,target_opening_period);        -- akhir bulan prior
CREATE VARIABLE prior_snapshot DATE; SET prior_snapshot = closing_from;                                 -- sinv prior (READ-ONLY, frozen)
CREATE VARIABLE move_from      DATE; SET move_from      = target_opening_period;                        -- awal bulan opening (mutasi)
CREATE VARIABLE move_to        DATE; SET move_to        = dateadd(day,-1,dateadd(month,1,target_opening_period)); -- akhir bulan opening
SELECT target_opening_period, closing_from, closing_to, prior_snapshot, move_from, move_to;

-- STEP 1: BACKUP + BEFORE-IMAGE (untuk bukti scope) + baseline guard
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_mekA_bak') THEN DROP TABLE _mekA_bak END IF;
SELECT * INTO _mekA_bak FROM sinv WHERE periode IN (target_opening_period, dateadd(month,1,target_opening_period), dateadd(month,2,target_opening_period));
-- before-image PENUH periode target (row-level diff)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_sinv_target_before') THEN DROP TABLE _sinv_target_before END IF;
SELECT * INTO _sinv_target_before FROM sinv WHERE periode=target_opening_period;
-- checksum per-periode SELURUH sinv (bukti hanya target yg berubah)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_sinv_ck_before') THEN DROP TABLE _sinv_ck_before END IF;
SELECT periode, count(*) n, cast(sum(isnull(qty,0)) as numeric(24,4)) sq, cast(sum(isnull(nilai,0)) as numeric(24,2)) sn
  INTO _sinv_ck_before FROM sinv GROUP BY periode;
-- baseline guard prior-year + WIP/HPP (NULL-safe: isnull cegah warning 109 & kehilangan baris ber-NULL)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_guard') THEN DROP TABLE _guard END IF;
SELECT 'prior_open_qty' k, cast(sum(isnull(qty,0))   as numeric(24,2)) v INTO _guard FROM sinv WHERE periode=prior_snapshot;
INSERT INTO _guard SELECT 'prior_open_nil', cast(sum(isnull(nilai,0)) as numeric(24,2)) FROM sinv WHERE periode=prior_snapshot;
INSERT INTO _guard SELECT 'gl_prior', cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(24,2)) FROM gl_journal WHERE tgl<=closing_to;
INSERT INTO _guard SELECT 'move_tx', cast((SELECT isnull(sum(isnull(qty,0)),0) FROM tsales2 s2 JOIN tsales1 s1 ON s1.bukti_id=s2.bukti_id WHERE s1.tgl BETWEEN move_from AND move_to) as numeric(24,2));
INSERT INTO _guard SELECT 'wip020', cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(24,2)) FROM gl_journal WHERE account_id='102-020';
INSERT INTO _guard SELECT 'hppwip', cast(sum(isnull(hpp,0)*isnull(qty,0)) as numeric(24,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tipe_trans='88';
COMMIT;

-- STEP 2: MATERIALISASI engine closing prior (READ-ONLY; TIDAK menulis ke prior)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_engine_dec') THEN DROP TABLE _engine_dec END IF;
CREATE TABLE _engine_dec (stok_id varchar(20) PRIMARY KEY, akhir numeric(18,2), nilai numeric(20,2));
INSERT INTO _engine_dec(stok_id,akhir) SELECT z.PRODUK_ID, z.AKHIR FROM ( SELECT 
 A.GROUP_PRODUCT,B.NAMA_GROUP,B.HPP,B.PERSEDIAAN,B.PENJUALAN,A.PRODUK_ID,A.PRODUK_DESC,
A.AWAL,A.AWAL_RP,
A.MUTASI_IN,A.BELI,A.BELI_RP,A.RET_BELI,A.RET_BELI_RP,A.EKSPEDISI,A.EKSPEDISI_RP,A.MUTASI_OUT,
A.JUAL,A.JUAL_RP,A.JUAL_REAL,
A.JUAL_BY_EVAP,
A.JUAL_BY_EVAP_RP,
A.RET_JUAL,A.RET_JUAL_RP,
A.MUTASI_IN_RP,A.MUTASI_OUT_RP,
A.CONSIN , A.CONSIN_RP,A.CONSIN_BY_EVAP,A.CONSIN_BY_EVAP_RP,
A.CONSOUT,A.CONSOUT_RP,
A.AKHIR,
a.produk_id+' '+a.produk_desc as is_find
 FROM (
SELECT IM_PRODUK.GROUP_PRODUCT,IM_PRODUK.PRODUK_ID,
			IM_PRODUK.PRODUK_DESC,
	ISNULL(AWAL.AWAL,0) AS AWAL,
    ISNULL(AWAL.AWAL_RP,0) AS AWAL_RP,
ISNULL(CONSIN.QTY,0) CONSIN,
ISNULL(CONSIN.NILAI,0) CONSIN_RP,
ISNULL(CONSIN_BY_EVAP.QTY,0) CONSIN_BY_EVAP,
ISNULL(CONSIN_BY_EVAP.NILAI,0) CONSIN_BY_EVAP_RP,
ISNULL(CONSOUT.CONSOUT,0) CONSOUT,
ISNULL(CONSOUT.CONSOUT_RP,0) CONSOUT_RP,
ISNULL(JUAL.QTY,0) AS JUAL,  
            ISNULL(JUAL.JUAL_RP,0) + ISNULL(JUAL_BY_EVAP.JUAL_RP2,0) AS JUAL_RP, 
            ISNULL(JUAL.NILAI,0) AS JUAL_REAL, 
ISNULL(JUAL_BY_EVAP.QTY,0) AS JUAL_BY_EVAP,
ISNULL(JUAL_BY_EVAP.NILAI,0) AS JUAL_BY_EVAP_RP,
 			ABS(ISNULL(RET_JUAL.RET_JUAL,0)) AS RET_JUAL,   
            ABS(ISNULL(RET_JUAL.RET_JUAL_RP,0)) AS RET_JUAL_RP,
			ABS(ISNULL(STOK.BELI,0)) AS BELI,
            ISNULL(STOK_RP.BELI,0) + ISNULL(STOK_RP.EKSPEDISI,0) AS BELI_RP,
--ISNULL(STOK_RP.BELI,0)AS BELI_RP,
            ABS(ISNULL(STOK_RP.RET_BELI,0.00)) AS RET_BELI_RP,
			ABS(ISNULL(STOK.RET_BELI,0)) AS RET_BELI,
			ABS(ISNULL(STOK.MUTASI_IN,0)) AS MUTASI_IN,
            ABS(ISNULL(STOK_RP.MUTASI_IN,0)) AS MUTASI_IN_RP,
			ABS(ISNULL(STOK.MUTASI_OUT,0))  AS MUTASI_OUT,
            ABS(ISNULL(STOK_RP.MUTASI_OUT,0)) AS MUTASI_OUT_RP,
            ISNULL(STOK_RP.EKSPEDISI,0)AS EKSPEDISI_RP,
            ISNULL(STOK.EKSPEDISI,0) AS EKSPEDISI,
			(ABS(ISNULL(AWAL.AWAL,0)) - ABS(ISNULL(JUAL.QTY,0)) - ABS(ISNULL(JUAL_BY_EVAP.QTY,0)) + ABS(ISNULL(RET_JUAL.RET_JUAL,0))  
			+ ABS(ISNULL(STOK.BELI,0)) - ABS(ISNULL(STOK.RET_BELI,0)) - ABS(ISNULL(CONSOUT.CONSOUT,0)) + ABS(ISNULL(CONSIN.QTY,0)) +
            ABS(ISNULL(CONSIN_BY_EVAP.QTY,0)) + ABS(ISNULL(STOK.MUTASI_IN,0)) -  ABS(ISNULL(STOK.MUTASI_OUT,0)) ) AS AKHIR

  	FROM IM_PRODUK,
			(  SELECT 	(SINV.STOK_ID) AS KEY1,   
							SUM(SINV.QTY) AS AWAL,
					         SUM(SINV.NILAI) AS AWAL_RP,
							AVG(SINV.HPP_AVG) AS HPP_AVG
				FROM     SINV 
			WHERE    	( SINV.PERIODE =  (closing_from) ) 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE =  (closing_from) ) 
			   GROUP BY SINV.STOK_ID   
			) AWAL_RP,

			( SELECT A.STOK_ID,SUM(A.QTY) AS QTY,SUM(A.NILAI) as NILAI,SUM(A.JUAL_RP) JUAL_RP
            FROM
                (
                SELECT B.STOK_ID,B.QTY,B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1,B.QTY * ISNULL(B.HPP,0) as NILAI,
                B.NETTO * ISNULL(A.KURS,1) as JUAL_RP
                FROM TSALES1 A,TSALES2 B
                WHERE A.BUKTI_ID = B.BUKTI_ID
                AND A.TIPE_TRANS = '22'
                AND ISNULL(B.EVAP,'') = ''
                AND A.TGL BETWEEN  (closing_from)  AND (closing_to) 
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL <  (closing_from) )
                )A
                 GROUP BY A.STOK_ID
			) JUAL,
(
        SELECT A.STOK_ID,SUM(A.QTY) AS QTY,SUM(A.QTY * ISNULL(A.HPP,0)) AS NILAI,SUM(A.JUAL_RP2) JUAL_RP2
FROM
    (
    SELECT B.STOK_ID,B.QTY,ISNULL(B.HPP,0) AS HPP,B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1,
	ISNULL(B.NETTO,0) * ISNULL(A.KURS,1) AS JUAL_RP2
    FROM TSALES1 A,TSALES2 B
    WHERE A.BUKTI_ID = B.BUKTI_ID
    AND A.TIPE_TRANS = '22'
    AND ISNULL(B.EVAP,'') <> ''
    AND ISNULL(B.QTY,0) <> 0
    AND A.TGL BETWEEN  (closing_from)  AND (closing_to) 
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN  (closing_from)  AND (closing_to) ) AND
							( TSALES1.ORDER_OKE = 'Y' ) AND
							ISNULL(TSALES2.QTY,0) <>0
			   GROUP BY (TSALES2.STOK_ID)
			) CONSOUT,


( SELECT 	(TSALES2.STOK_ID) AS KEY1,							
							SUM(CASE WHEN TSALES1.TIPE_TRANS IN ('32','26','36') THEN TSALES2.QTY ELSE 0 END ) AS RET_JUAL,	
							SUM(CASE WHEN TSALES1.TIPE_TRANS IN ('32','26','36') THEN ABS(( TSALES2.NETTO)    * ISNULL(TSALES1.KURS,1)) ELSE 0 END )  AS RET_JUAL_RP						
							
				FROM   	TSALES1,   
							TSALES2  ,MCUST
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							TSALES1.CUST_ID = MCUST.CUST_ID AND
							(TSALES1.TGL BETWEEN  (closing_from)  AND (closing_to) ) AND
							ISNULL(TSALES2.QTY,0) <>0 AND
							ISNULL(TSALES2.HRG,0) <> 0 AND
							TSALES1.tipe_trans in('32','26','36')
			   GROUP BY (TSALES2.STOK_ID)
			) RET_JUAL,
	

			( SELECT 	(TSTOK2.STOK_ID) AS KEY1,   
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '02' THEN TSTOK2.QTY ELSE 0 END ) AS BELI,
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '12' THEN TSTOK2.QTY ELSE 0 END ) AS RET_BELI,
	                        SUM( CASE WHEN TSTOK1.TIPE_TRANS = '88' THEN TSTOK2.QTY ELSE 0 END ) AS CONSIN,
	                        SUM( CASE WHEN TSTOK1.TIPE_TRANS = '05'  THEN TSTOK2.QTY ELSE 0 END ) AS EKSPEDISI,
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '09'  THEN TSTOK2.QTY ELSE 0 END ) AS MUTASI_IN,
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '19'  THEN TSTOK2.QTY ELSE 0 END ) AS MUTASI_OUT
				FROM  	TSTOK1,   
							TSTOK2,IM_PRODUK,IM_PRODUCT_GROUP
				 WHERE 	( TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID ) AND  
IM_PRODUK.PRODUK_ID = TSTOK2.STOK_ID AND
IM_PRODUK.GROUP_PRODUCT = IM_PRODUCT_GROUP.KODE_GROUP AND
							(TSTOK1.TGL BETWEEN  (closing_from)  AND (closing_to) ) AND
                              ( TSTOK1.ORDER_OKE = 'Y' ) AND
							ISNULL(TSTOK2.QTY,0) <> 0
			   GROUP BY (TSTOK2.STOK_ID)
			 ) STOK,

			( SELECT 	TSTOK2.STOK_ID AS STOK_ID,   
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '02' THEN ( TSTOK2.NETTO * ISNULL(TSTOK1.KURS,1) )   ELSE 0 END) AS BELI,
SUM( CASE WHEN TSTOK1.TIPE_TRANS = '88' THEN (TSTOK2.NETTO * ISNULL(TSTOK1.KURS,1))    ELSE 0 END) AS CONSIN,
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '12' THEN ABS(TSTOK2.NETTO_HPP) ELSE 0 END ) AS RET_BELI,
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '09' THEN (TSTOK2.NETTO) ELSE 0 END ) AS MUTASI_IN,
							SUM( CASE WHEN TSTOK1.TIPE_TRANS = '19' THEN ABS(TSTOK2.NETTO_HPP) ELSE 0 END ) AS MUTASI_OUT,
                            SUM( CASE WHEN TSTOK1.TIPE_TRANS = '05' THEN ABS(TSTOK2.BIAYA_EKSPEDISI)*ABS(ISNULL(TSTOK2.QTY,0)) ELSE 0 END ) AS EKSPEDISI

				FROM  	TSTOK1,   
							TSTOK2,IM_PRODUK,IM_PRODUCT_GROUP
				 WHERE 	( TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID ) AND  
IM_PRODUK.PRODUK_ID = TSTOK2.STOK_ID AND
IM_PRODUK.GROUP_PRODUCT = IM_PRODUCT_GROUP.KODE_GROUP AND
							(TSTOK1.TGL BETWEEN  (closing_from)  AND (closing_to) ) AND
							( ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' ) AND
							ISNULL(TSTOK2.QTY,0) <> 0
			   GROUP BY TSTOK2.STOK_ID
			 ) STOK_RP,
(
        SELECT A.STOK_ID,SUM(A.QTY) AS QTY,SUM(A.QTY * ISNULL(A.NETTO,0)) AS NILAI
    FROM
        (
        SELECT B.STOK_ID,B.QTY,B.STOK_ID+ISNULL(B.COA_ID,'') AS KEY1,B.NETTO
        FROM TSTOK1 A,TSTOK2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL BETWEEN  (closing_from)  AND (closing_to) 
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL <  (closing_from) )
            )A
        GROUP BY A.STOK_ID
)CONSIN,
(
SELECT A.STOK_ID,SUM(A.QTY) AS QTY,SUM(A.QTY * ISNULL(A.NETTO,0)) AS NILAI
    FROM
        (
        SELECT B.STOK_ID,B.QTY,ISNULL(B.NETTO,0) AS NETTO,B.STOK_ID+ISNULL(B.COA_ID,'') AS KEY1
        FROM TSTOK1 A,TSTOK2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL BETWEEN  (closing_from)  AND (closing_to) 
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL <  (closing_from) 
        )B
        WHERE A.KEY1 = B.KEY1
        GROUP BY A.STOK_ID
        )CONSIN_BY_EVAP

WHERE	IM_PRODUK.STOK_ITEM = 'Y' AND
			(IM_PRODUK.PRODUK_ID *= AWAL.KEY1) AND
			(IM_PRODUK.PRODUK_ID *= JUAL.STOK_ID) AND
            (IM_PRODUK.PRODUK_ID *= JUAL_BY_EVAP.STOK_ID) AND
			(IM_PRODUK.PRODUK_ID *= CONSOUT.KEY1) AND
			(IM_PRODUK.PRODUK_ID *= RET_JUAL.KEY1) AND
			(IM_PRODUK.PRODUK_ID *= STOK.KEY1) AND
			(IM_PRODUK.PRODUK_ID *= AWAL_RP.STOK_ID) AND
         	(IM_PRODUK.PRODUK_ID *= STOK_RP.STOK_ID) AND
            (IM_PRODUK.PRODUK_ID *= CONSIN_BY_EVAP.STOK_ID) AND
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)             
ORDER BY IM_PRODUK.PRODUK_ID ASC
) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z WHERE z.PRODUK_ID IS NOT NULL;
UPDATE _engine_dec SET nilai=round(isnull(akhir,0)*isnull((SELECT hpp_avg FROM sinv WHERE stok_id=_engine_dec.stok_id AND periode=target_opening_period),0),2);
COMMIT;

-- STEP 3: PREVIEW item terdampak -- BACA & SETUJUI dulu
SELECT gr.persediaan akun, e.stok_id,
  cast(sv.qty as numeric(14,2)) qty_lama, cast(e.akhir as numeric(14,2)) qty_baru,
  cast(sv.nilai as numeric(20,2)) nilai_lama, cast(e.nilai as numeric(20,2)) nilai_baru,
  cast(sv.nilai-e.nilai as numeric(20,2)) phantom
FROM _engine_dec e JOIN sinv sv ON sv.stok_id=e.stok_id AND sv.periode=target_opening_period
JOIN im_produk pr ON pr.produk_id=e.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE abs(sv.nilai-e.nilai)>1 ORDER BY abs(sv.nilai-e.nilai) DESC;

-- STEP 3b: GUARD COVERAGE (harus keduanya 0/aman sebelum UPDATE)
SELECT 'sinv_not_in_engine(HARUS 0)' cek, count(*) n, cast(isnull(sum(isnull(sv.nilai,0)),0) as numeric(20,2)) nilai
  FROM sinv sv WHERE sv.periode=target_opening_period AND NOT EXISTS(SELECT 1 FROM _engine_dec e WHERE e.stok_id=sv.stok_id)
UNION ALL
SELECT 'engine_not_in_sinv(nilai HARUS 0)', count(*), cast(isnull(sum(isnull(e.nilai,0)),0) as numeric(20,2))
  FROM _engine_dec e WHERE NOT EXISTS(SELECT 1 FROM sinv sv WHERE sv.periode=target_opening_period AND sv.stok_id=e.stok_id);

-- STEP 4: KOREKSI SNAPSHOT OPENING -- SATU-SATUNYA penulisan ke tabel bisnis.
--   Scope terkunci: WHERE periode=target_opening_period. Set QTY & NILAI saja. HPP_AVG TIDAK disentuh.
UPDATE sinv SET qty=e.akhir, nilai=e.nilai FROM _engine_dec e
  WHERE sinv.stok_id=e.stok_id AND sinv.periode=target_opening_period;
COMMIT;
-- >>> LALU: evidence_scope_proof.sql (bukti hanya target berubah) + validation_guard2025.sql + evidence_4way_recon.sql
-- >>> LALU: recompute move-bulan berikut via Refresh normal (of_run ab_sinv_only) -- lihat RUNBOOK.

-- ROLLBACK:
-- UPDATE sinv SET qty=b.qty, nilai=b.nilai, hpp_avg=b.hpp_avg FROM _mekA_bak b
--   WHERE sinv.stok_id=b.stok_id AND sinv.periode=b.periode AND sinv.site_id=b.site_id; COMMIT;