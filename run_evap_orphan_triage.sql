-- =====================================================================
-- run_evap_orphan_triage.sql        EVAP ORPHAN TRIAGE PACKAGE
-- ASA9 / SQL Anywhere 9.  READ-ONLY penuh (tanpa CTE, tanpa syntax MSSQL/PG).
-- TIDAK ADA UPDATE / DELETE / INSERT / CREATE.  Aman di prod maupun copy.
-- Orphan = jual EVAP (tipe 22) hpp=0 yg TIDAK punya consout (tipe 88) ber-hpp>0
--          untuk (stok_id + evap) yang SAMA.
-- >>> EDIT periode: ganti '2026-06-01' dan '2026-08-01' di tiap seksi bila perlu. <<<
-- =====================================================================

-- =====================================================================
-- 1. INVENTORY ORPHAN DETAIL
-- =====================================================================
select o.tgl_jual, o.bukti_id, o.stok_id, o.evap,
       cast(o.qty as numeric(18,2)) as qty,
       cast(o.hpp as numeric(18,2)) as hpp_sekarang,
       'ORPHAN - tanpa consout serial' as status
from (
   select s1.tgl tgl_jual, s1.bukti_id, s2.stok_id, isnull(s2.evap,'') evap,
          isnull(s2.qty,0) qty, isnull(s2.hpp,0) hpp
   from tsales1 s1, tsales2 s2
   where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22'
     and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
     and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
     and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
          and c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
) o
order by o.stok_id, o.tgl_jual;

-- =====================================================================
-- 2. SEARCH COST SOURCE  (prioritas A > C > B(model) > D(prior) )
-- =====================================================================
select o.bukti_id, o.stok_id, o.evap,
   case
     when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                  and c2.stok_id=o.stok_id and c2.evap=o.evap and isnull(c2.hpp,0)>0)
        then 'A_SERIAL_CONSOUT'
     when exists(select 1 from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
                  and t2.stok_id=o.stok_id and isnull(t2.netto,0)>0
                  and month(t1.tgl)=month(o.tgl_jual) and year(t1.tgl)=year(o.tgl_jual))
        then 'C_PURCHASE_SAMEMONTH'
     when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                  and c2.stok_id=o.stok_id and c2.evap<>o.evap and isnull(c2.hpp,0)>0)
        then 'B_MODEL_CONSOUT_OTHER_SERIAL'
     when exists(select 1 from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id
                  and d2.stok_id=o.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<o.tgl_jual)
        then 'D_PRIOR_SALE_HPP'
     else 'NONE'
   end as candidate_source,
   cast(isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
          and c1.tipe_trans='88' and c2.stok_id=o.stok_id and isnull(c2.hpp,0)>0),0) as numeric(18,2)) as candidate_hpp,
   case
     when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                  and c2.stok_id=o.stok_id and c2.evap=o.evap and isnull(c2.hpp,0)>0) then 'HIGH-serial'
     when exists(select 1 from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
                  and t2.stok_id=o.stok_id and isnull(t2.netto,0)>0
                  and month(t1.tgl)=month(o.tgl_jual) and year(t1.tgl)=year(o.tgl_jual)) then 'HIGH-purchase'
     else 'LOW-model (bukan cost serial ini)'
   end as confidence
from (
   select s1.tgl tgl_jual, s1.bukti_id, s2.stok_id, isnull(s2.evap,'') evap
   from tsales1 s1, tsales2 s2
   where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22'
     and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
     and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
     and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
          and c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
) o
order by o.stok_id, o.bukti_id;

-- =====================================================================
-- 3. KLASIFIKASI OTOMATIS  (per unit)
-- =====================================================================
select o.bukti_id, o.stok_id, o.evap,
   case
     when exists(select 1 from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
                  and t2.stok_id=o.stok_id and isnull(t2.netto,0)>0
                  and month(t1.tgl)=month(o.tgl_jual) and year(t1.tgl)=year(o.tgl_jual))
        then 'A_RECOVERABLE'
     when (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=o.evap) > 1
        then 'C_DUPLICATE_IDENTITY'
     when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                  and c2.stok_id=o.stok_id and c2.evap<>o.evap and isnull(c2.hpp,0)>0)
       or exists(select 1 from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id
                  and d2.stok_id=o.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<o.tgl_jual)
        then 'D_NEED_ACCOUNTING_DECISION'
     else 'B_DATA_MISSING'
   end as kelas
from (
   select s1.tgl tgl_jual, s1.bukti_id, s2.stok_id, isnull(s2.evap,'') evap
   from tsales1 s1, tsales2 s2
   where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22'
     and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
     and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
     and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
          and c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
) o
order by kelas, o.stok_id;

-- =====================================================================
-- 4. READ-ONLY  -> seluruh script hanya SELECT. Tidak ada UPDATE/DELETE/INSERT/CREATE.
-- =====================================================================

-- =====================================================================
-- 5. MANAGEMENT REPORT  (ringkasan kelas + rekomendasi)
-- =====================================================================
select x.kelas,
       count(*) as jumlah_unit,
       cast(sum(x.qty) as numeric(18,2)) as total_qty,
       cast(sum(x.qty*x.candidate_hpp) as numeric(18,2)) as potensi_cogs_jika_diterapkan,
       case x.kelas
         when 'A_RECOVERABLE'              then 'BOLEH auto (moving-avg pembelian sebulan menutup)'
         when 'D_NEED_ACCOUNTING_DECISION' then 'JURNAL MANUAL setelah Pak Wira setujui cost model (bukan auto)'
         when 'C_DUPLICATE_IDENTITY'       then 'INVESTIGASI serial dipakai lintas stok'
         when 'B_DATA_MISSING'             then 'DIBIARKAN 0 / keputusan akuntansi (tak ada bukti cost)'
       end as rekomendasi
from (
   select o.stok_id, o.qty,
     isnull((select max(c2.hpp) from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
            and c1.tipe_trans='88' and c2.stok_id=o.stok_id and isnull(c2.hpp,0)>0),0) as candidate_hpp,
     case
       when exists(select 1 from tstok1 t1,tstok2 t2 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
                    and t2.stok_id=o.stok_id and isnull(t2.netto,0)>0
                    and month(t1.tgl)=month(o.tgl_jual) and year(t1.tgl)=year(o.tgl_jual)) then 'A_RECOVERABLE'
       when (select count(distinct c2.stok_id) from tsales2 c2 where c2.evap=o.evap) > 1 then 'C_DUPLICATE_IDENTITY'
       when exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
                    and c2.stok_id=o.stok_id and c2.evap<>o.evap and isnull(c2.hpp,0)>0)
         or exists(select 1 from tsales1 d1,tsales2 d2 where d1.bukti_id=d2.bukti_id
                    and d2.stok_id=o.stok_id and isnull(d2.hpp,0)>0 and d1.tgl<o.tgl_jual) then 'D_NEED_ACCOUNTING_DECISION'
       else 'B_DATA_MISSING'
     end as kelas
   from (
      select s1.tgl tgl_jual, s1.bukti_id, s2.stok_id, isnull(s2.evap,'') evap, isnull(s2.qty,0) qty
      from tsales1 s1, tsales2 s2
      where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22'
        and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
        and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
        and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id
             and c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
   ) o
) x
group by x.kelas
order by x.kelas;
