-- =====================================================================
-- DETEKTOR BULANAN: produk EVAP terjual dengan HPP=0 padahal ada WIP-out
--   (consout tsales88) ber-HPP untuk NOMOR SERI (evap) yang sama.
-- Gejala: di Mutasi "Nilai HPP Penjualan" tidak keluar & WIP-in bernilai 0,
--   karena unit keluar konsinyasi lintas-bulan -> moving-average sudah 0.
-- Dampak: COGS (Laba Rugi) understated, cost nyangkut di akun Titipan (102-020).
-- Cara pakai: ganti PERIODE di 2 tempat (awal & akhir bulan yang di-cek).
--   'hpp_seharusnya' = nilai yang benar (dari HPP WIP-out serial itu) -> dipakai
--   untuk koreksi di SUMBER (bukan diketik di Mutasi). Kalau 0 baris = aman.
-- =====================================================================
select s1.tgl                                as jual_tgl,
       s2.stok_id,
       p.produk_desc,
       s2.evap                               as serial,
       s1.tipe_trans,
       s1.bukti_id                           as jual_bukti,
       s1.order_client,
       cast(s2.qty as numeric(18,2))         as qty,
       cast(isnull(s2.hpp,0) as numeric(18,2)) as hpp_now,
       cast( (select max(x2.hpp)
                from tsales1 x1 join tsales2 x2 on x1.bukti_id = x2.bukti_id
               where x1.tipe_trans = '88'
                 and x2.stok_id = s2.stok_id
                 and x2.evap    = s2.evap
                 and isnull(x2.hpp,0) > 0
                 and x1.tgl < s1.tgl) as numeric(18,2)) as hpp_seharusnya
from   tsales1 s1
       join tsales2 s2   on s1.bukti_id = s2.bukti_id
       join im_produk p  on p.produk_id = s2.stok_id
where  s1.tipe_trans in ('22','88')
  and  s1.order_oke = 'Y'
  and  s1.tgl >= '2026-06-01'          -- << AWAL periode
  and  s1.tgl <  '2026-07-01'          -- << AKHIR periode (eksklusif)
  and  isnull(s2.hpp,0) = 0
  and  s2.qty > 0
  and  isnull(s2.evap,'') <> ''        -- hanya produk EVAP (ber-nomor seri)
  and  exists (select 1
                 from tsales1 x1 join tsales2 x2 on x1.bukti_id = x2.bukti_id
                where x1.tipe_trans = '88'
                  and x2.stok_id = s2.stok_id
                  and x2.evap    = s2.evap
                  and isnull(x2.hpp,0) > 0
                  and x1.tgl < s1.tgl)
order by s1.tgl, s2.stok_id;
