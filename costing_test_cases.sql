-- ============================================================
-- BAGIAN B — Costing ikut asal inventory. TEST CASE (READ-ONLY).
-- Aturan: jual dari WIP -> HPP = HPP WIP-Out (BEKU); jual dari stok normal -> HPP average.
-- Engine: n_cst_closing_stock.sru (C1 freeze WIP-Out, C2 avg NON-WIP evap='', C3 WIP sale=MAX '88').
-- ============================================================

-- ============ CASE 1: unit WIP-Out lalu dijual bulan berikut -> HPP = WIP-Out (BUKAN average) ============
-- Cari serial yang WIP-Out <= 2025-12-31 lalu dijual '22' di 2026, bandingkan:
--   hpp_wipout (beku saat WIP-Out) vs hpp_jual (saat faktur) vs avg bulan jual.
-- HARAPAN engine baru: hpp_jual = hpp_wipout (beku). FAIL bila hpp_jual = average bulan.
select o.evap serial, o.stok_id, o.tgl_wipout, j.tgl_jual,
  cast(o.hpp_wipout as numeric(18,2)) hpp_wipout_beku,
  cast(j.hpp_jual as numeric(18,2)) hpp_saat_jual,
  cast(j.hpp_jual - o.hpp_wipout as numeric(18,2)) selisih,
  case when abs(j.hpp_jual - o.hpp_wipout) <= 1 then 'PASS (beku)' else 'CEK (bukan WIP-Out HPP)' end verdict
from (select s2.evap, s2.stok_id, s1.tgl tgl_wipout, s2.hpp hpp_wipout
      from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
      where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2025-12-31') o
join (select s2.evap, s1.tgl tgl_jual, s2.hpp hpp_jual
      from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
      where s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and s1.tgl between '2026-01-01' and '2026-02-28') j
  on j.evap=o.evap
order by abs(j.hpp_jual - o.hpp_wipout) desc;

-- ============ CASE 2: unit stok NORMAL (non-WIP) dijual -> HPP = average bulan ============
-- Penjualan '22' TANPA evap (bukan dari WIP) di Feb 2026: HPP harus = hpp_avg sinv awal Feb per model.
select s2.stok_id, count(*) n_jual,
  cast(avg(s2.hpp) as numeric(18,2)) hpp_jual_rata,
  cast((select hpp_avg from sinv where stok_id=s2.stok_id and periode='2026-02-01') as numeric(18,2)) hpp_avg_awal_feb,
  case when abs(avg(s2.hpp) - isnull((select hpp_avg from sinv where stok_id=s2.stok_id and periode='2026-02-01'),0)) <= 1
       then 'PASS (average)' else 'CEK' end verdict
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans='22' and isnull(s2.evap,'')='' and s1.tgl between '2026-02-01' and '2026-02-28'
 and exists(select 1 from sinv where stok_id=s2.stok_id and periode='2026-02-01' and qty<>0)
group by s2.stok_id
having count(*) > 0
order by n_jual desc;

-- ============ VALIDASI FINAL: Stok + WIP + GL balance ============
-- Setelah BAGIAN A (WIP jadi stok): 102-020 sinv = ledger; TR/NR/TB + WIP vs ledger.
select acc, cast(sinv as numeric(20,2)) sinv, cast(ledger as numeric(20,2)) ledger, cast(sinv-ledger as numeric(20,2)) gap
from (
 select a.acc,
   isnull((select sum(s.nilai) from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan=a.acc and s.periode='2026-03-01'),0) sinv,
   isnull((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode=a.acc and Period='2026-01-01'),0)
   + isnull((select sum(debet-kredit) from gl_journal where account_id=a.acc and tgl between '2026-01-01' and '2026-02-28'),0) ledger
 from (select '102-001' acc union select '102-003' union select '102-006' union select '102-020') a
) x order by acc;
