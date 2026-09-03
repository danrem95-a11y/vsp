-- ============================================================
-- BAGIAN A — WIP jadi lokasi/gudang stok (102-020). PREVIEW (READ-ONLY, no execute).
-- Reklas outstanding WIP-Out -> stok WIP, PRESERVE serial + HPP WIP-Out (BEKU).
-- Prinsip: TIDAK kurangi stok (nilai TR/TB sudah dikreditkan ke 102-020 di GL);
--          ini MENAMBAH sisi STOK 102-020 agar cocok dgn ledger 102-020 (1,8 M).
-- Serial tetap terlacak lewat transaksi '88' (evap) yang SUDAH ADA (tak diubah).
-- ============================================================

-- A0. Target = saldo ledger 102-020 (nilai stok WIP yang harus terbentuk)
select cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
          + (select sum(debet-kredit) from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-02-28') as numeric(20,2)) target_stok_wip;

-- A1. ISI stok WIP = outstanding WIP-Out per (akun asal, model), qty + nilai HPP BEKU
--     (calon baris sinv 102-020; serial detail di A2)
select gr.persediaan akun_asal, s2.stok_id model_asal,
  count(distinct s2.evap) qty_wip,
  cast(sum(abs(isnull(s2.hpp,0)*isnull(s2.qty,0))) as numeric(18,2)) nilai_wip_beku,
  cast(avg(abs(s2.hpp)) as numeric(18,2)) hpp_per_unit_beku
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
 join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-02-28'
 and gr.persediaan in ('102-001','102-003','102-006')
 and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-02-28')
 and not exists(select 1 from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id where x1.tipe_trans='22' and x2.evap=s2.evap and x1.tgl<='2026-02-28')
group by gr.persediaan, s2.stok_id order by nilai_wip_beku desc;

-- A2. SERIAL-level (audit trail WIP-Out -> WIP stok): serial, model, tgl WIP-Out, HPP beku, voucher
select gr.persediaan akun_asal, s2.evap serial, s2.stok_id model, s1.tgl tgl_wipout, s1.bukti_id voucher_wipout,
  cast(abs(isnull(s2.hpp,0)*isnull(s2.qty,0)) as numeric(18,2)) nilai_hpp_beku
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
 join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-02-28'
 and gr.persediaan in ('102-001','102-003','102-006')
 and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-02-28')
 and not exists(select 1 from tsales1 x1 join tsales2 x2 on x1.bukti_id=x2.bukti_id where x1.tipe_trans='22' and x2.evap=s2.evap and x1.tgl<='2026-02-28')
order by akun_asal, nilai_hpp_beku desc;

-- A3. IMPACT ROW COUNT & BEFORE/AFTER (preview angka)
--   BEFORE: sinv 102-020 = 0 ; ledger 102-020 = target (A0).
--   AFTER : sinv 102-020 = SUM(A1) ; harus = ledger 102-020 (selisih -> 0).
--   Reklas TIDAK mengubah gl_journal (ledger sudah mencatat WIP-Out). Total qty stok bertambah = qty WIP
--   (karena unit ini FISIK ada tapi belum tercatat sebagai stok WIP).
select 'BEFORE' fase, 0 sinv_wip_102020,
   cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
      + (select sum(debet-kredit) from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-02-28') as numeric(20,2)) ledger_102020;

-- ============================================================
-- CATATAN eksekusi (disiapkan setelah preview A1/A2 dicocokkan):
--   1. CREATE produk WIP: kode 'WIP.<akun>' (mis WIP.TR) group_product -> group ber-persediaan '102-020'.
--   2. INSERT sinv (periode berjalan, stok_id=WIP.*, qty=qty_wip, nilai=nilai_wip_beku, hpp_avg=hpp beku).
--   3. TIDAK insert/ubah gl_journal (ledger 102-020 sudah benar).
--   4. Serial map: view d_rpt_cons / laporan konsinyasi tetap baca evap dari '88' (tak berubah).
--   BACKUP: unload sinv + gl_journal sebelum eksekusi. VALIDATION: script bagian 5 dokumen.
-- ============================================================
