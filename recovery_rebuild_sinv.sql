-- ============================================================
-- RECOVERY REBUILD SINV OPENING 2026 (audit-safe, regenerasi dari engine)
-- Root cause: sinv opening 2026 ditulis phantom > engine (bukan WIP, bukan transaksi).
-- Bukti: engine dw_refresh_stok closing Des-2025 = GL ke rupiah; sinv = outlier.
-- PRINSIP: BUKAN update angka manual, BUKAN adjustment saldo. Regenerasi SINV = engine.
--
-- !!! JALANKAN DI COPY-DB / LOCAL DULU. Verifikasi: select property('MachineName')
--     harus mesin test, BUKAN server prod. !!!
-- Urutan: STEP1 backup -> STEP2 materialize engine -> STEP3 PREVIEW (baca dulu,
--         approve) -> STEP4 BEFORE -> STEP5 REBUILD -> STEP6 AFTER+VALIDASI.
-- ============================================================

-- ============ STEP 1: BACKUP sinv opening 2026 ============
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_sinv_open2026_bak') THEN DROP TABLE _sinv_open2026_bak END IF;
SELECT * INTO _sinv_open2026_bak FROM sinv WHERE periode='2026-01-01';
-- backup 102-020 GL & sample HPP WIP untuk bukti "tidak berubah"
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_wip_guard_bak') THEN DROP TABLE _wip_guard_bak END IF;
SELECT '102020' k, cast(sum(debet-kredit) as numeric(20,2)) v INTO _wip_guard_bak FROM gl_journal WHERE account_id='102-020';
INSERT INTO _wip_guard_bak SELECT 'HPPWIP', cast(sum(hpp*qty) as numeric(20,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tipe_trans='88';
COMMIT;

-- ============ STEP 2: MATERIALISASI ENGINE CLOSING (dw_refresh_stok Des-2025) ============
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_engine_closing') THEN DROP TABLE _engine_closing END IF;
CREATE TABLE _engine_closing (stok_id varchar(20) PRIMARY KEY, akhir_qty numeric(18,2), persediaan varchar(12), hpp_avg numeric(18,2), engine_nilai numeric(20,2));
INSERT INTO _engine_closing (stok_id, akhir_qty)
  SELECT z.PRODUK_ID, z.AKHIR FROM ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2025-12-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2025-12-01') 
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
                AND A.TGL BETWEEN '2025-12-01' AND'2025-12-31'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2025-12-01')
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
    AND A.TGL BETWEEN '2025-12-01' AND'2025-12-31'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2025-12-01' AND'2025-12-31') AND
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
							(TSALES1.TGL BETWEEN '2025-12-01' AND'2025-12-31') AND
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
							(TSTOK1.TGL BETWEEN '2025-12-01' AND'2025-12-31') AND
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
							(TSTOK1.TGL BETWEEN '2025-12-01' AND'2025-12-31') AND
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
        AND A.TGL BETWEEN '2025-12-01' AND'2025-12-31'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2025-12-01')
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
        AND A.TGL BETWEEN '2025-12-01' AND'2025-12-31'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2025-12-01'
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
UPDATE _engine_closing SET persediaan=(SELECT gr.persediaan FROM im_produk pr JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE pr.produk_id=_engine_closing.stok_id);
UPDATE _engine_closing SET hpp_avg=isnull((SELECT hpp_avg FROM sinv WHERE stok_id=_engine_closing.stok_id AND periode='2026-01-01'),0);
UPDATE _engine_closing SET engine_nilai=round(akhir_qty*hpp_avg,2);
COMMIT;

-- ============ STEP 3: PREVIEW - SEMUA item terdampak (engine vs sinv, gap qty & value) ============
SELECT e.persediaan AS akun, e.stok_id,
  cast(sv.qty as numeric(14,2)) sinv_qty, cast(e.akhir_qty as numeric(14,2)) engine_qty, cast(sv.qty-e.akhir_qty as numeric(14,2)) gap_qty,
  cast(sv.nilai as numeric(20,2)) sinv_nilai, cast(e.engine_nilai as numeric(20,2)) engine_nilai, cast(sv.nilai-e.engine_nilai as numeric(20,2)) gap_nilai
FROM _engine_closing e JOIN sinv sv ON sv.stok_id=e.stok_id AND sv.periode='2026-01-01'
WHERE abs(sv.qty-e.akhir_qty) > 0.01 OR abs(sv.nilai-e.engine_nilai) > 1
ORDER BY abs(sv.nilai-e.engine_nilai) DESC;
-- (baris = item yang akan direbuild. Approve dulu sebelum STEP5.)

-- ============ STEP 4: BEFORE report (gap per akun) ============
SELECT gr.persediaan akun,
  cast(sum(s.nilai) as numeric(20,2)) sinv_before,
  cast(isnull((SELECT sum(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period='2026-01-01'),0) as numeric(20,2)) gl,
  cast(sum(s.nilai)-isnull((SELECT sum(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period='2026-01-01'),0) as numeric(20,2)) gap_before
FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE s.periode='2026-01-01' AND isnull(gr.persediaan,'')<>''
GROUP BY gr.persediaan ORDER BY abs(sum(s.nilai)-isnull((SELECT sum(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period='2026-01-01'),0)) DESC;

-- ============ STEP 5: REBUILD (regenerasi sinv = engine) -- EKSEKUSI setelah PREVIEW disetujui ============
-- (hpp_avg DIPERTAHANKAN; hanya qty & nilai=qty*hpp_avg diregenerasi dari engine)
UPDATE sinv SET qty=e.akhir_qty, nilai=e.engine_nilai
  FROM _engine_closing e WHERE sinv.stok_id=e.stok_id AND sinv.periode='2026-01-01';
COMMIT;

-- ============ STEP 6: AFTER + VALIDASI ============
-- 6A. SINV = engine (harus 0 baris)
SELECT e.stok_id, sv.qty sinv_qty, e.akhir_qty engine_qty FROM _engine_closing e JOIN sinv sv ON sv.stok_id=e.stok_id AND sv.periode='2026-01-01' WHERE abs(sv.qty-e.akhir_qty)>0.01;
-- 6B. SINV = GL per akun (gap <= Rp1..58 pembulatan = PASS; 102-201 pengecualian isu GL saldo-awal)
SELECT gr.persediaan akun,
  cast(sum(s.nilai) as numeric(20,2)) sinv_after,
  cast(isnull((SELECT sum(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period='2026-01-01'),0) as numeric(20,2)) gl,
  cast(sum(s.nilai)-isnull((SELECT sum(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period='2026-01-01'),0) as numeric(20,2)) gap_after
FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE s.periode='2026-01-01' AND isnull(gr.persediaan,'')<>''
GROUP BY gr.persediaan ORDER BY abs(sum(s.nilai)-isnull((SELECT sum(AmountDebet-AmountCredit) FROM gl_balance WHERE AccountCode=gr.persediaan AND Period='2026-01-01'),0)) DESC;
-- 6C. WIP 102-020 TETAP & HPP WIP TETAP (harus delta 0)
SELECT b.k, b.v AS sebelum,
  CASE b.k WHEN '102020' THEN (SELECT cast(sum(debet-kredit) as numeric(20,2)) FROM gl_journal WHERE account_id='102-020')
           ELSE (SELECT cast(sum(hpp*qty) as numeric(20,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tipe_trans='88') END AS sesudah
FROM _wip_guard_bak b;
-- (sebelum == sesudah => WIP 102-020 & HPP WIP tidak tersentuh)

-- ============ ROLLBACK (bila perlu) ============
-- UPDATE sinv SET qty=b.qty, nilai=b.nilai, hpp_avg=b.hpp_avg FROM _sinv_open2026_bak b
--   WHERE sinv.stok_id=b.stok_id AND sinv.periode='2026-01-01' AND sinv.site_id=b.site_id; COMMIT;

-- CATATAN: setelah opening 2026 benar, RE-REFRESH Jan & Feb (via aplikasi) agar opening
--          benar merambat ke sinv Feb/Mar. Lalu jalankan validation_post_closing.sql.