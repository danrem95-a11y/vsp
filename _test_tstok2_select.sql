select  '102'+substr(jual.bukti_id,4) as bukti_id,jual.urut,jual.stok_id,
jual.qty,jual.qty * isnull(jual.hpp,0) as kotor,jual.qty * isnull(jual.hpp,0) as netto,
jual.qty as qty1,jual.sat_besar,jual.sat_sedang,jual.sat_kecil,
3 as flag_vendor, 'G001' as gudang_id, 'EVAP :'+jual.evap+' COND :'+jual.cond as description,
isnull(jual.hpp,0) as hpp,jual.qty * isnull(jual.hpp,0) as netto_hpp,isnull(jual.hpp,0) as hrg,jual.evap,jual.cond
from
(
select a.bukti_id,a.order_client,a.tgl,a.bukti_reff,a.keterangan,a.cust_id,
b.stok_id,c.produk_desc, case when isnull(b.qty,0) = 0 then 1 else b.qty end as qty,b.sat_besar,b.sat_sedang,b.sat_kecil,
b.evap,b.cond,isnull(b.hpp,0) as hpp
from tsales1 a, tsales2 b, im_produk c
where a.bukti_id = b.bukti_id and
a.tipe_trans = '88' and
b.stok_id = c.produk_id and
isnull(b.evap,'') <> ''
)cons,(
select a.bukti_id,a.order_client,a.tgl,a.bukti_reff,a.keterangan,a.cust_id,
b.urut,b.stok_id,c.produk_desc,case when isnull(b.qty,0) = 0 then 1 else b.qty end as qty,b.sat_besar,b.sat_sedang,b.sat_kecil,
b.evap,b.cond,(case when isnull(b.hpp,0)>0 then b.hpp else isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88' and c2.stok_id=b.stok_id and c2.evap=b.evap and isnull(c2.hpp,0)>0 and c1.tgl<=a.tgl),0) end) as hpp,isnull(b.hpp,0) as hrg
from tsales1 a, tsales2 b, im_produk c
where a.bukti_id = b.bukti_id and
a.tipe_trans = '22' and
b.stok_id = c.produk_id and
isnull(b.evap,'') <> '' and
/*b.urut <> 1 and*/
a.bukti_id = '10126062200169'
)jual
where 
cons.stok_id = jual.stok_id and
cons.evap = jual.evap and
cons.cond = jual.cond
