-- ============================================================
-- EVIDENCE — Rekonsiliasi Stok vs Ledger + Trace WIP (READ-ONLY)
-- prod:2638. Closing Feb 2026: sinv '2026-03-01', GL = gl_balance[2026-01-01] + movement 2026.
-- ============================================================

-- 1) REKONSILIASI SEMUA 102-xxx (stok vs ledger) — gap>Rp1000 = belum cocok
select x.acc,
  cast(isnull(x.sinv,0) as numeric(20,2)) sinv_stok,
  cast(isnull(x.opn,0)+isnull(x.mov,0) as numeric(20,2)) ledger,
  cast(isnull(x.sinv,0)-(isnull(x.opn,0)+isnull(x.mov,0)) as numeric(20,2)) gap
from (
  select a.acc,
   (select sum(s.nilai) from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan=a.acc and s.periode='2026-03-01') sinv,
   (select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode=a.acc and Period='2026-01-01') opn,
   (select sum(debet-kredit) from gl_journal where account_id=a.acc and tgl between '2026-01-01' and '2026-02-28') mov
  from (select distinct account_id acc from gl_journal where account_id like '102-%'
        union select distinct AccountCode from gl_balance where AccountCode like '102-%' and Period='2026-01-01') a
) x
where abs(isnull(x.sinv,0)-(isnull(x.opn,0)+isnull(x.mov,0))) > 1000
order by abs(isnull(x.sinv,0)-(isnull(x.opn,0)+isnull(x.mov,0))) desc;

-- 2) TRACE WIP-Out '88' per serial (TR/NR/TB), status WIP-In & Jual, sampai 31-12-2025
select gr.persediaan akun, s2.stok_id, s2.evap serial, s1.tgl tgl_wipout,
  cast(abs(isnull(s2.hpp,0)*isnull(s2.qty,0)) as numeric(18,2)) nilai_wipout_hpp,
  case when isnull(s2.hpp,0)=0 then 'HPP=0(understated)' else 'ok' end catatan,
  (select count(*) from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2025-12-31') ada_wipin,
  (select count(*) from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id where x1.tipe_trans='22' and x2.evap=s2.evap and x1.tgl<='2025-12-31') ada_jual
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
 join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2025-12-31'
 and gr.persediaan in ('102-001','102-003','102-006')
 and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2025-12-31')
order by gr.persediaan, nilai_wipout_hpp desc;

-- 3) Saldo 102-020 (WIP) closing Feb + komposisi lawan-akun
select cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
          + (select sum(debet-kredit) from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-02-28') as numeric(20,2)) saldo_102020_feb;

-- 4) TOTAL: Σstok vs Σledger 102-xxx (bukti gap tak bisa ditutup transaksi berimbang)
select cast(sum(sinv) as numeric(20,2)) total_sinv, cast(sum(led) as numeric(20,2)) total_ledger,
       cast(sum(sinv)-sum(led) as numeric(20,2)) net_gap
from (
  select a.acc,
   isnull((select sum(s.nilai) from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan=a.acc and s.periode='2026-03-01'),0) sinv,
   isnull((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode=a.acc and Period='2026-01-01'),0)
   + isnull((select sum(debet-kredit) from gl_journal where account_id=a.acc and tgl between '2026-01-01' and '2026-02-28'),0) led
  from (select distinct account_id acc from gl_journal where account_id like '102-%'
        union select distinct AccountCode from gl_balance where AccountCode like '102-%' and Period='2026-01-01') a
) y;
