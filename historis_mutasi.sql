select
v_mutasi.urut,
v_mutasi.flag,
v_mutasi.stok_id,
v_mutasi.produk_desc,
v_mutasi.tgl,
v_mutasi.order_client,
v_mutasi.bukti_reff,
v_mutasi.curr_id,
v_mutasi.kurs,
v_mutasi.ppn,
v_mutasi.qty,
case when v_mutasi.use_hpp_formula = 'Y' then isnull(v_hpp.hpp,0) else v_mutasi.hrg end as hrg,
case when v_mutasi.use_hpp_formula = 'Y' then 
   case when v_mutasi.flag = 'RET-JUAL' then abs(isnull(v_mutasi.qty,0)) * isnull(v_hpp.hpp,0) * isnull(v_mutasi.kurs,1)
      else abs(isnull(v_mutasi.qty,0)) * isnull(v_hpp.hpp,0)
   end
else v_mutasi.rp end as rp,
v_mutasi.evap,
v_mutasi.cond,
v_mutasi.chasis,
v_mutasi.engine
from
(
SELECT 3 as urut, 'JUAL' as flag,	tsales2.stok_id,im_produk.produk_desc,tsales1.tgl,
tsales1.order_client,tsales1.bukti_reff,tsales1.curr_id,tsales1.kurs,tsales1.ppn,
CASE WHEN TSALES1.TIPE_TRANS = '22' THEN TSALES2.QTY ELSE 0 END  as qty,
CASE WHEN TSALES1.TIPE_TRANS = '22' THEN TSALES2.hrg ELSE 0 END  as hrg,
CASE WHEN TSALES1.TIPE_TRANS = '22' THEN (ABS(isnull(TSALES2.kotor,0)) - isnull(tsales2.pot,0))  *  isnull(tsales1.kurs,1) ELSE 0 END  as rp,
isnull(tsales2.evap,'') evap,
isnull(tsales2.cond,'') cond,
isnull(tsales2.chasis,'') chasis,
isnull(tsales2.engine,'') engine,
'N' as use_hpp_formula
FROM   	TSALES1,   
TSALES2  ,im_produk
WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) and  
im_produk.produk_id = tsales2.stok_id and
(tsales1.tgl between :arg_tgl1 and :arg_tgl2) and
( TSALES1.ORDER_OKE = 'Y' ) and
tsales1.tipe_trans = '22' and
isnull(tsales2.hrg,0) <>0 and
isnull(tsales2.qty,0) <>0
UNION ALL

SELECT 3 as urut, 'Cons Out' as flag,	tsales2.stok_id,im_produk.produk_desc,tsales1.tgl,
tsales1.order_client,tsales1.bukti_reff,tsales1.curr_id,tsales1.kurs,tsales1.ppn,
tsales2.qty  as qty,
0  as hrg,
0  as rp,
isnull(tsales2.evap,'') as evap,
isnull(tsales2.cond,'') as cond,
isnull(tsales2.chasis,'') as chasis,
isnull(tsales2.engine,'') as engine,
'Y' as use_hpp_formula
FROM   	TSALES1,   
TSALES2  ,im_produk
WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) and  
im_produk.produk_id = tsales2.stok_id and
(tsales1.tgl between :arg_tgl1 and :arg_tgl2) and
( TSALES1.ORDER_OKE = 'Y' ) and
tsales1.tipe_trans = '88' and
isnull(tsales2.qty,0) <>0

UNION ALL

SELECT 4 as urut, 'RET-JUAL' as flag,	tsales2.stok_id,im_produk.produk_desc,tsales1.tgl,
tsales1.order_client,tsales1.bukti_reff,tsales1.curr_id,tsales1.kurs,tsales1.ppn,
CASE WHEN TSALES1.TIPE_TRANS = '32' THEN TSALES2.QTY ELSE 0 END  as qty,
0  as hrg,
0  as rp,
'' as evap,
'' as cond,
'' as chasis,
'' as engine,
'Y' as use_hpp_formula
FROM   	TSALES1,   
TSALES2  ,im_produk
WHERE 	( TSALES1.BUKTI_ID = TSALES2.BUKTI_ID ) and  
im_produk.produk_id = tsales2.stok_id and
(tsales1.tgl between :arg_tgl1 and :arg_tgl2) and
( TSALES1.ORDER_OKE = 'Y' ) and
tsales1.tipe_trans = '32' and
isnull(tsales2.qty,0) <>0

UNION ALL
 SELECT 	1 as urut,'BELI' as flag,TSTOK2.STOK_ID AS STOK_ID, im_produk.produk_desc,tstok1.tgl,tstok1.order_client,tstok1.bukti_reff,  
tstok1.curr_id,tstok1.kurs,
tstok1.ppn,
tstok2.qty,
tstok2.hrg,
CASE WHEN TSTOK1.TIPE_TRANS = '02' THEN ( TSTOK2.NETTO * isnull(tstok1.kurs,1) )  +  (CASE WHEN TSTOK1.TTL_PPN = 0 THEN 0 ELSE (ROUND(TSTOK2.NETTO*0.1,0) * isnull(tstok1.kurs,1) ) END ) - 
 ABS(isnull(TSTOK2.qty,0) * abs(isnull(tstok2.hrg,0)) * isnull(TSTOK1.KURS,1)) * (tstok2.pot/100) +
(CASE WHEN tstok1.PPN = 0 THEN 0 ELSE ABS(isnull(TSTOK2.qty,0) * abs(isnull(tstok2.hrg,0)) * isnull(TSTOK1.KURS,1)) * 0.1 END ) else 0 end as rp,
'' as evap,
'' as cond,
'' as chasis,
'' as engine,
'N' as use_hpp_formula
FROM  	TSTOK1,   
TSTOK2,im_produk,im_product_group
WHERE 	( TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID ) and  
tstok1.tipe_trans = '02' and
im_produk.produk_id = tstok2.stok_id and
im_produk.group_product = im_product_group.kode_group and
(tstok1.tgl  between :arg_tgl1 and :arg_tgl2) and
( ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' ) and
isnull(tstok2.hrg,0) <>0 and
isnull(tstok2.qty,0) <> 0
UNION ALL

 SELECT 	1 as urut,
case when tstok1.tipe_trans = '09' then 'ADJ(+)' else 'ADJ(-)' end as flag,
TSTOK2.STOK_ID AS STOK_ID, im_produk.produk_desc,tstok1.tgl,tstok1.order_client,tstok1.bukti_reff,  
tstok1.curr_id,tstok1.kurs,
tstok1.ppn,
tstok2.qty,
case when tstok1.tipe_trans = '09' then tstok2.hrg else tstok2.hpp end as hrg,
case when tstok1.tipe_trans = '09' then tstok2.netto else tstok2.netto_hpp end as rp,
'' as evap,
'' as cond,
'' as chasis,
'' as engine,
'N' as use_hpp_formula

FROM  	TSTOK1,   
TSTOK2,im_produk,im_product_group
WHERE 	( TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID ) and  
tstok1.tipe_trans in('09','19') and
im_produk.produk_id = tstok2.stok_id and
im_produk.group_product = im_product_group.kode_group and
(tstok1.tgl  between :arg_tgl1 and :arg_tgl2) and
( ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' ) and
isnull(tstok2.qty,0) <> 0

UNION ALL
 SELECT 	1 as urut,
'Cons In' as flag,
TSTOK2.STOK_ID AS STOK_ID, im_produk.produk_desc,tstok1.tgl,tstok1.order_client,tstok1.bukti_reff,  
tstok1.curr_id,tstok1.kurs,
tstok1.ppn,
tstok2.qty,
0 as hrg,
0 as rp,
case when isnull(tstok2.coa_id,'') = '' then
   substr(replace(tstok2.description,'EVAP :',''),0, (locate(replace(tstok2.description,'EVAP :',''),'COND',1) - 1)) else tstok2.coa_id end  as evap,
case when isnull(tstok2.produk_id,'') = '' then
   substr(replace(tstok2.description,'EVAP :',''),0, (locate(replace(tstok2.description,'EVAP :',''),'COND',1) - 1)) else tstok2.produk_id end  as cond,
'' as chasis,
'' as engine,
'Y' as use_hpp_formula
FROM  	TSTOK1,   
TSTOK2,im_produk,im_product_group
WHERE 	( TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID ) and  
tstok1.tipe_trans in('88') and
im_produk.produk_id = tstok2.stok_id and
im_produk.group_product = im_product_group.kode_group and
tstok1.tgl between :arg_tgl1 and :arg_tgl2 and
( ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' ) and
isnull(tstok2.qty,0) <> 0 
UNION ALL

 SELECT 	2 as urut, 'EKSPEDISI' as flag,TSTOK2.STOK_ID AS STOK_ID, im_produk.produk_desc,tstok1.tgl,tstok1.order_client,tstok1.bukti_reff,  
tstok1.curr_id,tstok1.kurs,
tstok1.ppn,
tstok2.qty,
tstok2.biaya_ekspedisi as hrg,
tstok2.qty * tstok2.biaya_ekspedisi as rp,
'' as evap,
'' as cond,
'' as chasis,
'' as engine,
'N' as use_hpp_formula
FROM  	TSTOK1,   
TSTOK2,im_produk,im_product_group
WHERE 	( TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID ) and  
tstok1.tipe_trans = '05' and
im_produk.produk_id = tstok2.stok_id and
im_produk.group_product = im_product_group.kode_group and
(tstok1.tgl  between :arg_tgl1 and :arg_tgl2) and
( ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' ) and
isnull(tstok2.hrg,0) <>0 and
isnull(tstok2.qty,0) <> 0
) v_mutasi,
(
SELECT A.PRODUK_ID AS STOK_ID,
CASE 
   WHEN ((A.AWAL + A.BELI + A.MUTASI_IN + A.RET_JUAL) - A.RET_BELI) <> 0 THEN
      ((A.AWAL_RP + A.BELI_RP + A.MUTASI_IN_RP + A.RET_JUAL_RP) - A.RET_BELI_RP) /
      ((A.AWAL + A.BELI + A.MUTASI_IN + A.RET_JUAL) - A.RET_BELI)
   ELSE 0
END AS HPP
FROM (
   SELECT IM_PRODUK.PRODUK_ID,
         ISNULL(AWAL.AWAL,0) AS AWAL,
         ISNULL(AWAL.AWAL_RP,0) AS AWAL_RP,
         ABS(ISNULL(STOK.BELI,0)) AS BELI,
         ISNULL(STOK_RP.BELI,0) + ISNULL(STOK_RP.EKSPEDISI,0) AS BELI_RP,
         ABS(ISNULL(STOK.MUTASI_IN,0)) AS MUTASI_IN,
         ABS(ISNULL(STOK_RP.MUTASI_IN,0)) AS MUTASI_IN_RP,
         ABS(ISNULL(RET_JUAL.RET_JUAL,0)) AS RET_JUAL,
         ABS(ISNULL(RET_JUAL.RET_JUAL_RP,0)) AS RET_JUAL_RP,
         ABS(ISNULL(STOK.RET_BELI,0)) AS RET_BELI,
         ABS(ISNULL(STOK_RP.RET_BELI,0)) AS RET_BELI_RP
   FROM IM_PRODUK,
       (
          SELECT SINV.STOK_ID AS STOK_ID,
               SUM(SINV.QTY) AS AWAL,
               SUM(SINV.NILAI) AS AWAL_RP
          FROM SINV
          WHERE MONTH(SINV.PERIODE) = MONTH(:arg_tgl1) and
               YEAR(SINV.PERIODE) = YEAR(:arg_tgl1) and
               SINV.STOK_ID = :arg_kode
          GROUP BY SINV.STOK_ID
       ) AWAL,
       (
          SELECT TSALES2.STOK_ID AS STOK_ID,
               SUM(CASE WHEN TSALES1.TIPE_TRANS IN ('32','26','36') THEN TSALES2.QTY ELSE 0 END) AS RET_JUAL,
               SUM(CASE WHEN TSALES1.TIPE_TRANS IN ('32','26','36') THEN ABS(TSALES2.NETTO * ISNULL(TSALES1.KURS,1)) ELSE 0 END) AS RET_JUAL_RP
          FROM TSALES1,
              TSALES2
          WHERE TSALES1.BUKTI_ID = TSALES2.BUKTI_ID and
               TSALES1.TGL BETWEEN :arg_tgl1 and :arg_tgl2 and
               TSALES1.ORDER_OKE = 'Y' and
               TSALES1.TIPE_TRANS IN ('32','26','36') and
               ISNULL(TSALES2.QTY,0) <> 0 and
               TSALES2.STOK_ID = :arg_kode
          GROUP BY TSALES2.STOK_ID
       ) RET_JUAL,
       (
          SELECT TSTOK2.STOK_ID AS STOK_ID,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '02' THEN TSTOK2.QTY ELSE 0 END) AS BELI,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '12' THEN TSTOK2.QTY ELSE 0 END) AS RET_BELI,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '09' THEN TSTOK2.QTY ELSE 0 END) AS MUTASI_IN
          FROM TSTOK1,
              TSTOK2
          WHERE TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID and
               TSTOK1.TGL BETWEEN :arg_tgl1 and :arg_tgl2 and
               ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' and
               ISNULL(TSTOK2.QTY,0) <> 0 and
               TSTOK2.STOK_ID = :arg_kode
          GROUP BY TSTOK2.STOK_ID
       ) STOK,
       (
          SELECT TSTOK2.STOK_ID AS STOK_ID,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '02' THEN (TSTOK2.NETTO * ISNULL(TSTOK1.KURS,1)) ELSE 0 END) AS BELI,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '12' THEN ABS(TSTOK2.NETTO_HPP) ELSE 0 END) AS RET_BELI,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '09' THEN TSTOK2.NETTO ELSE 0 END) AS MUTASI_IN,
               SUM(CASE WHEN TSTOK1.TIPE_TRANS = '05' THEN ABS(TSTOK2.BIAYA_EKSPEDISI) * ABS(ISNULL(TSTOK2.QTY,0)) ELSE 0 END) AS EKSPEDISI
          FROM TSTOK1,
              TSTOK2
          WHERE TSTOK1.BUKTI_ID = TSTOK2.BUKTI_ID and
               TSTOK1.TGL BETWEEN :arg_tgl1 and :arg_tgl2 and
               ISNULL(TSTOK1.ORDER_OKE,'N') = 'Y' and
               ISNULL(TSTOK2.QTY,0) <> 0 and
               TSTOK2.STOK_ID = :arg_kode
          GROUP BY TSTOK2.STOK_ID
       ) STOK_RP
   WHERE IM_PRODUK.STOK_ITEM = 'Y' and
        IM_PRODUK.PRODUK_ID = :arg_kode and
        IM_PRODUK.PRODUK_ID *= AWAL.STOK_ID and
        IM_PRODUK.PRODUK_ID *= RET_JUAL.STOK_ID and
        IM_PRODUK.PRODUK_ID *= STOK.STOK_ID and
        IM_PRODUK.PRODUK_ID *= STOK_RP.STOK_ID
) A
) v_hpp
where v_mutasi.stok_id *= v_hpp.stok_id and
v_mutasi.stok_id = :arg_kode