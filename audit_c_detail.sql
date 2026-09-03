-- ============================================================
-- BAGIAN C — Audit transaksi '02' (BTB) vs '05' (Ekspedisi). READ-ONLY.
-- prod:2638. Membuktikan double-count QTY penyebab gap TR 10,11 M.
-- ============================================================

-- 1) DETAIL '02'/'05' TR.038A & TR.039A (no tx, tgl, item, qty, harga, nilai, vendor, ref, user)
select t1.tipe_trans, t1.bukti_id, t1.tgl, t2.stok_id, t2.qty, t2.hrg, t2.netto,
       t1.vendor_id, t1.order_client, t1.bukti_reff, t1.user_id, t1.keterangan
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id in ('TR.038A','TR.039A') and t1.tipe_trans in ('02','05') and t1.tgl between '2025-01-01' and '2025-12-31'
order by t2.stok_id, t1.tgl, t1.tipe_trans;

-- 2) DETEKSI DUPLIKAT: pasangan '02' vs '05' dgn tgl & qty & model SAMA (indikasi unit sama dihitung 2x)
select a.tgl, a.stok_id, a.qty,
       a.bukti_id bukti_02, a.vendor_id vend_02, a.netto netto_02,
       b.bukti_id bukti_05, b.vendor_id vend_05, b.netto netto_05
from (select t1.bukti_id,t1.tgl,t2.stok_id,t2.qty,t1.vendor_id,t2.netto from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='02') a
join (select t1.bukti_id,t1.tgl,t2.stok_id,t2.qty,t1.vendor_id,t2.netto from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='05') b
  on a.tgl=b.tgl and a.stok_id=b.stok_id and a.qty=b.qty
where a.stok_id in ('TR.038A','TR.039A')
order by a.tgl;

-- 3) GL kedua transaksi (bukti '02' via order_client BTB, '05' via bukti)
select voucher, account_id, debet, kredit, modul_id, doc_reff, voucher_manual, tgl
from gl_journal
where doc_reff in ('10125120200032','101BTB251200032','10125120500001')
   or voucher_manual in ('101BTB251200032')
order by voucher, account_id;

-- 4) SCOPE: model TR/NR/TB dgn pola '02'+'05', qty & netto 2025 (potensi phantom sistemik)
select gr.persediaan akun, t2.stok_id,
  cast(sum(case when t1.tipe_trans='02' then t2.qty else 0 end) as numeric(12,2)) qty_02,
  cast(sum(case when t1.tipe_trans='05' then t2.qty else 0 end) as numeric(12,2)) qty_05
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
 join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where t1.tipe_trans in ('02','05') and t1.tgl between '2025-01-01' and '2025-12-31' and gr.persediaan in('102-001','102-003','102-006')
group by gr.persediaan, t2.stok_id
having sum(case when t1.tipe_trans='02' then t2.qty else 0 end) <> 0
order by qty_05 desc;

-- 5) VALIDASI (jalankan SETELAH koreksi di COPY-DB): sinv = ledger utk 4 akun
select acc, cast(sinv as numeric(20,2)) sinv, cast(ledger as numeric(20,2)) ledger, cast(sinv-ledger as numeric(20,2)) gap
from (select a.acc,
   isnull((select sum(s.nilai) from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan=a.acc and s.periode='2026-03-01'),0) sinv,
   isnull((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode=a.acc and Period='2026-01-01'),0)
   + isnull((select sum(debet-kredit) from gl_journal where account_id=a.acc and tgl between '2026-01-01' and '2026-02-28'),0) ledger
 from (select '102-001' acc union select '102-003' union select '102-006' union select '102-020') a) x
order by acc;
