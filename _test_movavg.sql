select sl.stok_id, sl.evap, cast(isnull(sl.hpp,0) as numeric(18,2)) old_hpp,
  cast(isnull(nullif((   SELECT
      CASE
         WHEN ((ISNULL(aw.awal,0) + ISNULL(beli.beli,0) + ISNULL(beli.mutasi_in,0) + ISNULL(rj.ret_jual,0)) - ISNULL(beli.ret_beli,0)) <> 0
         THEN ((ISNULL(aw.awal_rp,0) + ISNULL(beli_rp.beli,0) + ISNULL(beli_rp.mutasi_in,0) + ISNULL(beli_rp.ekspedisi,0) + ISNULL(rj.ret_jual_rp,0)) - ISNULL(beli_rp.ret_beli,0)) /
              ((ISNULL(aw.awal,0)    + ISNULL(beli.beli,0)    + ISNULL(beli.mutasi_in,0)    + ISNULL(rj.ret_jual,0))    - ISNULL(beli.ret_beli,0))
         ELSE 0
      END
   FROM im_produk p
   LEFT OUTER JOIN (
      SELECT stok_id, SUM(qty) AS awal, SUM(nilai) AS awal_rp
      FROM sinv
      WHERE periode = '2026-06-01'
        AND stok_id = sl.stok_id
      GROUP BY stok_id
   ) aw ON p.produk_id = aw.stok_id
   LEFT OUTER JOIN (
      SELECT t2.stok_id,
         SUM(CASE WHEN t1.tipe_trans = '02' THEN t2.qty ELSE 0 END) AS beli,
         SUM(CASE WHEN t1.tipe_trans = '12' THEN t2.qty ELSE 0 END) AS ret_beli,
         SUM(CASE WHEN t1.tipe_trans = '09' THEN t2.qty ELSE 0 END) AS mutasi_in
      FROM tstok1 t1, tstok2 t2
      WHERE t1.bukti_id = t2.bukti_id
        AND t1.tgl BETWEEN '2026-06-01' AND '2026-06-30'
        AND ISNULL(t1.order_oke,'N') = 'Y'
        AND ISNULL(t2.qty,0) <> 0
        AND t2.stok_id = sl.stok_id
      GROUP BY t2.stok_id
   ) beli ON p.produk_id = beli.stok_id
   LEFT OUTER JOIN (
      SELECT t2.stok_id,
         SUM(CASE WHEN t1.tipe_trans = '02' THEN (t2.netto * ISNULL(t1.kurs,1)) ELSE 0 END) AS beli,
         SUM(CASE WHEN t1.tipe_trans = '12' THEN ABS(t2.netto_hpp)               ELSE 0 END) AS ret_beli,
         SUM(CASE WHEN t1.tipe_trans = '09' THEN t2.netto                         ELSE 0 END) AS mutasi_in,
         SUM(CASE WHEN t1.tipe_trans = '05' THEN ABS(t2.biaya_ekspedisi) * ABS(ISNULL(t2.qty,0)) ELSE 0 END) AS ekspedisi
      FROM tstok1 t1, tstok2 t2
      WHERE t1.bukti_id = t2.bukti_id
        AND t1.tgl BETWEEN '2026-06-01' AND '2026-06-30'
        AND ISNULL(t1.order_oke,'N') = 'Y'
        AND ISNULL(t2.qty,0) <> 0
        AND t2.stok_id = sl.stok_id
      GROUP BY t2.stok_id
   ) beli_rp ON p.produk_id = beli_rp.stok_id
   LEFT OUTER JOIN (
      SELECT t2.stok_id,
         SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN t2.qty ELSE 0 END) AS ret_jual,
         SUM(CASE WHEN t1.tipe_trans IN ('32','26','36') THEN ABS(t2.netto * ISNULL(t1.kurs,1)) ELSE 0 END) AS ret_jual_rp
      FROM tsales1 t1, tsales2 t2
      WHERE t1.bukti_id = t2.bukti_id
        AND t1.tgl BETWEEN '2026-06-01' AND '2026-06-30'
        AND t1.order_oke = 'Y'
        AND t1.tipe_trans IN ('32','26','36')
        AND ISNULL(t2.qty,0) <> 0
        AND t2.stok_id = sl.stok_id
      GROUP BY t2.stok_id
   ) rj ON p.produk_id = rj.stok_id
   WHERE p.stok_item = 'Y' AND p.produk_id = sl.stok_id),0), isnull((select max(c2.hpp) from tsales1 c1, tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88' and c2.stok_id=sl.stok_id and c2.evap=sl.evap and isnull(sl.evap,'')<>'' and isnull(c2.hpp,0)>0),0)) as numeric(18,2)) new_hpp
from tsales1 s1, tsales2 sl
where s1.bukti_id=sl.bukti_id and s1.tgl>='2026-06-01' and s1.tgl<'2026-07-01'
  and s1.order_oke='Y' and s1.tipe_trans in ('22','32','26','36','88')