-- ============================================================================
-- VALIDASI SALDO ANTAR BULAN (Part C hardening fix costing engine)
-- CHECK: saldo_akhir(bulan N, dihitung ULANG via rumus resmi dw_refresh_stok.srd)
--        vs saldo_awal(bulan N+1, TERSIMPAN di SINV) -- harus selisih = 0
-- Cakupan: SEMUA akun persediaan (Spare Parts, WIP TR/NR/TB, dan lainnya), semua stok_id.
-- Read-only murni. Jalankan di dbisql SETELAH refresh selesai.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BAGIAN 1 A: RINGKASAN PER AKUN -- Januari 2026 -> Saldo Awal Februari
-- ---------------------------------------------------------------------------
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='2026-02-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan_bulan_berikut,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-02-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2026-01-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2026-01-01') 
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
                AND A.TGL BETWEEN '2026-01-01' AND'2026-01-31'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2026-01-01')
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
    AND A.TGL BETWEEN '2026-01-01' AND'2026-01-31'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2026-01-01' AND'2026-01-31') AND
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
							(TSALES1.TGL BETWEEN '2026-01-01' AND'2026-01-31') AND
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
							(TSTOK1.TGL BETWEEN '2026-01-01' AND'2026-01-31') AND
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
							(TSTOK1.TGL BETWEEN '2026-01-01' AND'2026-01-31') AND
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
        AND A.TGL BETWEEN '2026-01-01' AND'2026-01-31'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2026-01-01')
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
        AND A.TGL BETWEEN '2026-01-01' AND'2026-01-31'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2026-01-01'
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
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-02-01' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN;
-- Kosong (0 baris) = BALANCE 100% utk periode ini. Kalau ada baris keluar, lanjut ke BAGIAN 1B utk transaksi penyebab.

-- ---------------------------------------------------------------------------
-- BAGIAN 1B: DRILL-DOWN TRANSAKSI PENYEBAB (kalau BAGIAN 1A ada baris)
-- Kandidat: baris keluar (jual22 EVAP='' / mutasi19 / adjustment lain) qty<>0 & HPP final=0
-- padahal cost basis (saldo awal / pembelian bulan ini) tersedia -- Januari 2026 -> Saldo Awal Februari
-- ---------------------------------------------------------------------------
select '22-JUAL' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai, isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
  from ( select s1.bukti_id, s1.tipe_trans, s2.stok_id, s2.qty, isnull(s2.hpp,0) hpp
           from tsales1 s1, tsales2 s2
          where s1.bukti_id=s2.bukti_id and s1.tgl between '2026-01-01' and '2026-01-31'
            and isnull(s2.evap,'')='' and isnull(s2.qty,0)<>0 and isnull(s2.hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-01-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-01-01' and '2026-01-31' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0)
union all
select '19-MUTKELUAR' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0), isnull(o.onil,0), isnull(b.bqty,0), isnull(b.bnil,0)
  from ( select t1.bukti_id, t1.tipe_trans, t2.stok_id, t2.qty, isnull(t2.hpp,0) hpp
           from tstok1 t1, tstok2 t2
          where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-01-01' and '2026-01-31'
            and isnull(t2.qty,0)<>0 and isnull(t2.netto_hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-01-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-01-01' and '2026-01-31' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0);

-- ---------------------------------------------------------------------------
-- BAGIAN 2 A: RINGKASAN PER AKUN -- Februari 2026 -> Saldo Awal Maret
-- ---------------------------------------------------------------------------
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='2026-03-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan_bulan_berikut,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-03-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2026-02-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2026-02-01') 
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
                AND A.TGL BETWEEN '2026-02-01' AND'2026-02-28'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2026-02-01')
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
    AND A.TGL BETWEEN '2026-02-01' AND'2026-02-28'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2026-02-01' AND'2026-02-28') AND
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
							(TSALES1.TGL BETWEEN '2026-02-01' AND'2026-02-28') AND
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
							(TSTOK1.TGL BETWEEN '2026-02-01' AND'2026-02-28') AND
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
							(TSTOK1.TGL BETWEEN '2026-02-01' AND'2026-02-28') AND
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
        AND A.TGL BETWEEN '2026-02-01' AND'2026-02-28'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2026-02-01')
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
        AND A.TGL BETWEEN '2026-02-01' AND'2026-02-28'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2026-02-01'
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
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-03-01' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN;
-- Kosong (0 baris) = BALANCE 100% utk periode ini. Kalau ada baris keluar, lanjut ke BAGIAN 2B utk transaksi penyebab.

-- ---------------------------------------------------------------------------
-- BAGIAN 2B: DRILL-DOWN TRANSAKSI PENYEBAB (kalau BAGIAN 2A ada baris)
-- Kandidat: baris keluar (jual22 EVAP='' / mutasi19 / adjustment lain) qty<>0 & HPP final=0
-- padahal cost basis (saldo awal / pembelian bulan ini) tersedia -- Februari 2026 -> Saldo Awal Maret
-- ---------------------------------------------------------------------------
select '22-JUAL' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai, isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
  from ( select s1.bukti_id, s1.tipe_trans, s2.stok_id, s2.qty, isnull(s2.hpp,0) hpp
           from tsales1 s1, tsales2 s2
          where s1.bukti_id=s2.bukti_id and s1.tgl between '2026-02-01' and '2026-02-28'
            and isnull(s2.evap,'')='' and isnull(s2.qty,0)<>0 and isnull(s2.hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-02-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-02-01' and '2026-02-28' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0)
union all
select '19-MUTKELUAR' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0), isnull(o.onil,0), isnull(b.bqty,0), isnull(b.bnil,0)
  from ( select t1.bukti_id, t1.tipe_trans, t2.stok_id, t2.qty, isnull(t2.hpp,0) hpp
           from tstok1 t1, tstok2 t2
          where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-02-01' and '2026-02-28'
            and isnull(t2.qty,0)<>0 and isnull(t2.netto_hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-02-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-02-01' and '2026-02-28' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0);

-- ---------------------------------------------------------------------------
-- BAGIAN 3 A: RINGKASAN PER AKUN -- Maret 2026 -> Saldo Awal April
-- ---------------------------------------------------------------------------
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='2026-04-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan_bulan_berikut,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-04-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2026-03-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2026-03-01') 
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
                AND A.TGL BETWEEN '2026-03-01' AND'2026-03-31'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2026-03-01')
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
    AND A.TGL BETWEEN '2026-03-01' AND'2026-03-31'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2026-03-01' AND'2026-03-31') AND
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
							(TSALES1.TGL BETWEEN '2026-03-01' AND'2026-03-31') AND
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
							(TSTOK1.TGL BETWEEN '2026-03-01' AND'2026-03-31') AND
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
							(TSTOK1.TGL BETWEEN '2026-03-01' AND'2026-03-31') AND
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
        AND A.TGL BETWEEN '2026-03-01' AND'2026-03-31'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2026-03-01')
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
        AND A.TGL BETWEEN '2026-03-01' AND'2026-03-31'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2026-03-01'
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
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-04-01' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN;
-- Kosong (0 baris) = BALANCE 100% utk periode ini. Kalau ada baris keluar, lanjut ke BAGIAN 3B utk transaksi penyebab.

-- ---------------------------------------------------------------------------
-- BAGIAN 3B: DRILL-DOWN TRANSAKSI PENYEBAB (kalau BAGIAN 3A ada baris)
-- Kandidat: baris keluar (jual22 EVAP='' / mutasi19 / adjustment lain) qty<>0 & HPP final=0
-- padahal cost basis (saldo awal / pembelian bulan ini) tersedia -- Maret 2026 -> Saldo Awal April
-- ---------------------------------------------------------------------------
select '22-JUAL' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai, isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
  from ( select s1.bukti_id, s1.tipe_trans, s2.stok_id, s2.qty, isnull(s2.hpp,0) hpp
           from tsales1 s1, tsales2 s2
          where s1.bukti_id=s2.bukti_id and s1.tgl between '2026-03-01' and '2026-03-31'
            and isnull(s2.evap,'')='' and isnull(s2.qty,0)<>0 and isnull(s2.hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-03-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-03-01' and '2026-03-31' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0)
union all
select '19-MUTKELUAR' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0), isnull(o.onil,0), isnull(b.bqty,0), isnull(b.bnil,0)
  from ( select t1.bukti_id, t1.tipe_trans, t2.stok_id, t2.qty, isnull(t2.hpp,0) hpp
           from tstok1 t1, tstok2 t2
          where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-03-01' and '2026-03-31'
            and isnull(t2.qty,0)<>0 and isnull(t2.netto_hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-03-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-03-01' and '2026-03-31' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0);

-- ---------------------------------------------------------------------------
-- BAGIAN 4 A: RINGKASAN PER AKUN -- April 2026 -> Saldo Awal Mei
-- ---------------------------------------------------------------------------
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='2026-05-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan_bulan_berikut,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-05-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2026-04-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2026-04-01') 
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
                AND A.TGL BETWEEN '2026-04-01' AND'2026-04-30'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2026-04-01')
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
    AND A.TGL BETWEEN '2026-04-01' AND'2026-04-30'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2026-04-01' AND'2026-04-30') AND
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
							(TSALES1.TGL BETWEEN '2026-04-01' AND'2026-04-30') AND
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
							(TSTOK1.TGL BETWEEN '2026-04-01' AND'2026-04-30') AND
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
							(TSTOK1.TGL BETWEEN '2026-04-01' AND'2026-04-30') AND
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
        AND A.TGL BETWEEN '2026-04-01' AND'2026-04-30'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2026-04-01')
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
        AND A.TGL BETWEEN '2026-04-01' AND'2026-04-30'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2026-04-01'
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
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-05-01' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN;
-- Kosong (0 baris) = BALANCE 100% utk periode ini. Kalau ada baris keluar, lanjut ke BAGIAN 4B utk transaksi penyebab.

-- ---------------------------------------------------------------------------
-- BAGIAN 4B: DRILL-DOWN TRANSAKSI PENYEBAB (kalau BAGIAN 4A ada baris)
-- Kandidat: baris keluar (jual22 EVAP='' / mutasi19 / adjustment lain) qty<>0 & HPP final=0
-- padahal cost basis (saldo awal / pembelian bulan ini) tersedia -- April 2026 -> Saldo Awal Mei
-- ---------------------------------------------------------------------------
select '22-JUAL' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai, isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
  from ( select s1.bukti_id, s1.tipe_trans, s2.stok_id, s2.qty, isnull(s2.hpp,0) hpp
           from tsales1 s1, tsales2 s2
          where s1.bukti_id=s2.bukti_id and s1.tgl between '2026-04-01' and '2026-04-30'
            and isnull(s2.evap,'')='' and isnull(s2.qty,0)<>0 and isnull(s2.hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-04-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-04-01' and '2026-04-30' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0)
union all
select '19-MUTKELUAR' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0), isnull(o.onil,0), isnull(b.bqty,0), isnull(b.bnil,0)
  from ( select t1.bukti_id, t1.tipe_trans, t2.stok_id, t2.qty, isnull(t2.hpp,0) hpp
           from tstok1 t1, tstok2 t2
          where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-04-01' and '2026-04-30'
            and isnull(t2.qty,0)<>0 and isnull(t2.netto_hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-04-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-04-01' and '2026-04-30' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0);

-- ---------------------------------------------------------------------------
-- BAGIAN 5 A: RINGKASAN PER AKUN -- Mei 2026 -> Saldo Awal Juni
-- ---------------------------------------------------------------------------
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='2026-06-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan_bulan_berikut,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-06-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2026-05-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2026-05-01') 
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
                AND A.TGL BETWEEN '2026-05-01' AND'2026-05-31'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2026-05-01')
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
    AND A.TGL BETWEEN '2026-05-01' AND'2026-05-31'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2026-05-01' AND'2026-05-31') AND
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
							(TSALES1.TGL BETWEEN '2026-05-01' AND'2026-05-31') AND
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
							(TSTOK1.TGL BETWEEN '2026-05-01' AND'2026-05-31') AND
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
							(TSTOK1.TGL BETWEEN '2026-05-01' AND'2026-05-31') AND
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
        AND A.TGL BETWEEN '2026-05-01' AND'2026-05-31'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2026-05-01')
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
        AND A.TGL BETWEEN '2026-05-01' AND'2026-05-31'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2026-05-01'
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
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-06-01' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN;
-- Kosong (0 baris) = BALANCE 100% utk periode ini. Kalau ada baris keluar, lanjut ke BAGIAN 5B utk transaksi penyebab.

-- ---------------------------------------------------------------------------
-- BAGIAN 5B: DRILL-DOWN TRANSAKSI PENYEBAB (kalau BAGIAN 5A ada baris)
-- Kandidat: baris keluar (jual22 EVAP='' / mutasi19 / adjustment lain) qty<>0 & HPP final=0
-- padahal cost basis (saldo awal / pembelian bulan ini) tersedia -- Mei 2026 -> Saldo Awal Juni
-- ---------------------------------------------------------------------------
select '22-JUAL' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai, isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
  from ( select s1.bukti_id, s1.tipe_trans, s2.stok_id, s2.qty, isnull(s2.hpp,0) hpp
           from tsales1 s1, tsales2 s2
          where s1.bukti_id=s2.bukti_id and s1.tgl between '2026-05-01' and '2026-05-31'
            and isnull(s2.evap,'')='' and isnull(s2.qty,0)<>0 and isnull(s2.hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-05-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-05-01' and '2026-05-31' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0)
union all
select '19-MUTKELUAR' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0), isnull(o.onil,0), isnull(b.bqty,0), isnull(b.bnil,0)
  from ( select t1.bukti_id, t1.tipe_trans, t2.stok_id, t2.qty, isnull(t2.hpp,0) hpp
           from tstok1 t1, tstok2 t2
          where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-05-01' and '2026-05-31'
            and isnull(t2.qty,0)<>0 and isnull(t2.netto_hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-05-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-05-01' and '2026-05-31' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0);

-- ---------------------------------------------------------------------------
-- BAGIAN 6 A: RINGKASAN PER AKUN -- Juni 2026 -> Saldo Awal Juli
-- ---------------------------------------------------------------------------
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='2026-07-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan_bulan_berikut,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-07-01' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( SELECT 
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
			WHERE    	( SINV.PERIODE = '2026-06-01') 
			   GROUP BY (SINV.STOK_ID)   
			) AWAL,
	
			(  SELECT 	SINV.STOK_ID AS STOK_ID,   
							SUM(SINV.NILAI) AS AWAL
				FROM     SINV  
			WHERE    	( SINV.PERIODE = '2026-06-01') 
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
                AND A.TGL BETWEEN '2026-06-01' AND'2026-06-30'
                AND ISNULL(B.qty,0) <> 0
                AND A.ORDER_OKE = 'Y'
                AND B.STOK_ID+ISNULL(B.EVAP,'') NOT IN
                    (
                        SELECT B.STOK_ID+ISNULL(B.EVAP,'') 
                        FROM TSALES1 A,TSALES2 B
                        WHERE A.BUKTI_ID = B.BUKTI_ID
                        AND A.TIPE_TRANS = '88'
                        AND A.TGL < '2026-06-01')
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
    AND A.TGL BETWEEN '2026-06-01' AND'2026-06-30'
    )A
    GROUP BY A.STOK_ID
 )JUAL_BY_EVAP,   

( SELECT 	(TSALES2.STOK_ID) AS KEY1,   
	SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN TSALES2.QTY ELSE 0 END ) AS CONSOUT,
		SUM(CASE WHEN TSALES1.TIPE_TRANS = '88' THEN ( TSALES2.HPP * TSALES2.QTY)  ELSE 0 END )  AS CONSOUT_RP					
				FROM   	TSALES1,   
							TSALES2
			  WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) AND  
							(TSALES1.TGL BETWEEN '2026-06-01' AND'2026-06-30') AND
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
							(TSALES1.TGL BETWEEN '2026-06-01' AND'2026-06-30') AND
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
							(TSTOK1.TGL BETWEEN '2026-06-01' AND'2026-06-30') AND
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
							(TSTOK1.TGL BETWEEN '2026-06-01' AND'2026-06-30') AND
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
        AND A.TGL BETWEEN '2026-06-01' AND'2026-06-30'
        AND B.STOK_ID + ISNULL(B.COA_ID,'') NOT IN
            (
            SELECT B.STOK_ID+ISNULL(B.EVAP,'')
            FROM TSALES1 A,TSALES2 B
            WHERE A.BUKTI_ID = B.BUKTI_ID
            AND A.TIPE_TRANS = '88'
            AND A.TGL < '2026-06-01')
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
        AND A.TGL BETWEEN '2026-06-01' AND'2026-06-30'
        )A,
        (
        SELECT B.STOK_ID+ISNULL(B.EVAP,'') AS KEY1
        FROM TSALES1 A,TSALES2 B
        WHERE A.BUKTI_ID = B.BUKTI_ID
        AND A.TIPE_TRANS = '88'
        AND ISNULL(B.QTY,0) <> 0
        AND A.TGL < '2026-06-01'
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
            (IM_PRODUK.PRODUK_ID *= CONSIN.STOK_ID)) A,IM_PRODUCT_GROUP B 
WHERE A.GROUP_PRODUCT = B.KODE_GROUP 
 ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='2026-07-01' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN;
-- Kosong (0 baris) = BALANCE 100% utk periode ini. Kalau ada baris keluar, lanjut ke BAGIAN 6B utk transaksi penyebab.

-- ---------------------------------------------------------------------------
-- BAGIAN 6B: DRILL-DOWN TRANSAKSI PENYEBAB (kalau BAGIAN 6A ada baris)
-- Kandidat: baris keluar (jual22 EVAP='' / mutasi19 / adjustment lain) qty<>0 & HPP final=0
-- padahal cost basis (saldo awal / pembelian bulan ini) tersedia -- Juni 2026 -> Saldo Awal Juli
-- ---------------------------------------------------------------------------
select '22-JUAL' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai, isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
  from ( select s1.bukti_id, s1.tipe_trans, s2.stok_id, s2.qty, isnull(s2.hpp,0) hpp
           from tsales1 s1, tsales2 s2
          where s1.bukti_id=s2.bukti_id and s1.tgl between '2026-06-01' and '2026-06-30'
            and isnull(s2.evap,'')='' and isnull(s2.qty,0)<>0 and isnull(s2.hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-06-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-06-01' and '2026-06-30' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0)
union all
select '19-MUTKELUAR' sumber, z.bukti_id, z.stok_id, z.tipe_trans, z.qty, z.hpp,
       isnull(o.oqty,0), isnull(o.onil,0), isnull(b.bqty,0), isnull(b.bnil,0)
  from ( select t1.bukti_id, t1.tipe_trans, t2.stok_id, t2.qty, isnull(t2.hpp,0) hpp
           from tstok1 t1, tstok2 t2
          where t1.bukti_id=t2.bukti_id and t1.tipe_trans='19' and t1.tgl between '2026-06-01' and '2026-06-30'
            and isnull(t2.qty,0)<>0 and isnull(t2.netto_hpp,0)=0 ) z
  left join ( select stok_id,sum(isnull(qty,0)) oqty,sum(isnull(nilai,0)) onil from sinv where periode='2026-06-01' group by stok_id ) o on o.stok_id=z.stok_id
  left join ( select t2.stok_id sid,sum(isnull(t2.qty,0)) bqty,sum(isnull(t2.netto,0)*isnull(t1.kurs,1)) bnil
                from tstok1 t1, tstok2 t2
               where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
                 and t1.tgl between '2026-06-01' and '2026-06-30' group by t2.stok_id ) b on b.sid=z.stok_id
 where (isnull(o.oqty,0)<>0 or isnull(o.onil,0)<>0 or isnull(b.bqty,0)<>0 or isnull(b.bnil,0)<>0);

