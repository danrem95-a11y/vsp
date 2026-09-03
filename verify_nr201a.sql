-- =====================================================================
-- verify_nr201a.sql   READ-ONLY. Jalankan SETELAH refresh+close (copy/prod).
-- Semua harus sesuai kolom "HARAPAN". NR.201A serial 645BDEAC002.
-- =====================================================================

-- 1) HPP Penjualan (tsales2.hpp) baris jual -> HARAPAN: 38.500.000 (bukan 0)
select 'HPP jual tsales2' cek, cast(isnull(hpp,0) as numeric(18,2)) nilai, '38.500.000' harapan
from tsales2 where bukti_id='10126062200169' and stok_id='NR.201A';

-- 2) COGS di GL (modul HP, akun 402-008) utk order ini -> HARAPAN: debet 38.500.000
select 'COGS GL 402-008 (HP)' cek,
   cast(isnull(sum(debet),0) as numeric(18,2)) debet, '38.500.000' harapan
from gl_journal where posting='P' and modul_id='HP' and account_id='402-008'
  and doc_reff='10106260600001';

-- 3) WIP-In (consin tstok2) -> HARAPAN: netto=hpp=38.500.000
select 'WIP-In tstok2' cek, cast(isnull(netto,0) as numeric(18,2)) netto,
   cast(isnull(hpp,0) as numeric(18,2)) hpp, '38.500.000' harapan
from tstok2 where bukti_id='10226062200169' and stok_id='NR.201A';

-- 4) Saldo akhir stok NR.201A -> HARAPAN: qty=0 DAN nilai=0 (phantom hilang)
select 'Saldo akhir SINV NR.201A' cek, periode,
   cast(isnull(qty,0) as numeric(18,2)) qty, cast(isnull(nilai,0) as numeric(18,2)) nilai, 'qty=0 & nilai=0' harapan
from sinv where stok_id='NR.201A' and periode in ('2026-07-01','2026-08-01') order by periode;

-- 5) Titipan 102-020 ter-relieve utk unit ini (consin Cr 102-020) -> HARAPAN: ada kredit 38.500.000
select 'Titipan 102-020 relieve (AS)' cek,
   cast(isnull(sum(kredit),0) as numeric(18,2)) kredit, '38.500.000' harapan
from gl_journal where posting='P' and account_id='102-020' and modul_id='AS'
  and doc_reff in (select order_client from tstok1 where bukti_id='10226062200169');

-- 6) Rekon akun TR (102-001): Ledger akhir Juni vs Stok akhir Juni -> HARAPAN: selisih <= pembulatan
select '102-001 Ledger vs Stok Jun' cek,
  cast(( (select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001')
       + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='102-001' and tgl>='2026-01-01' and tgl<'2026-07-01') )
       as numeric(18,2)) ledger_akhir,
  cast((select isnull(sum(sv.nilai),0) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id
        join im_product_group gr on gr.kode_group=pr.group_product
        where gr.persediaan='102-001' and sv.periode='2026-07-01') as numeric(18,2)) stok_akhir;
