-- ============================================================
-- BAGIAN 1 PREVIEW — Reklas WIP-Out outstanding -> stok WIP (102-020). READ-ONLY (tanpa eksekusi).
-- Tujuan: sinv 102-020 = ledger 102-020 (~1,59 M) sehingga WIP terlihat sebagai persediaan.
-- Reklas = pindah nilai antar-bucket stok; total stok TETAP; ledger TIDAK diubah; saldo tak dihapus.
-- ============================================================

-- P0. Target = saldo ledger 102-020 (yang harus jadi nilai stok WIP)
select cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
          + (select sum(debet-kredit) from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-02-28') as numeric(20,2)) target_nilai_wip_stok;

-- P1. Serial WIP-Out outstanding (calon isi stok WIP) per akun asal + model + nilai
select gr.persediaan akun_asal, s2.stok_id model, s2.evap serial, s1.tgl tgl_wipout,
  cast(abs(isnull(s2.hpp,0)*isnull(s2.qty,0)) as numeric(18,2)) nilai
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
 join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-02-28'
 and gr.persediaan in ('102-001','102-003','102-006')
 and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-02-28')
order by akun_asal, nilai desc;

-- P2. Ringkasan reklas per akun asal (berapa yang pindah ke 102-020)
select gr.persediaan akun_asal, count(distinct s2.evap) n_serial,
  cast(sum(abs(isnull(s2.hpp,0)*isnull(s2.qty,0))) as numeric(20,2)) nilai_pindah_ke_102020
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
 join im_produk pr on pr.produk_id=s2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-02-28'
 and gr.persediaan in ('102-001','102-003','102-006')
 and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-02-28')
group by gr.persediaan;

-- CATATAN: eksekusi (buat produk WIP group->102-020 + baris sinv 102-020 + kurangi sinv TR/TB senilai reklas)
--   disiapkan sebagai migration terpisah SETELAH preview P1/P2 dicocokkan & arah disetujui.
--   BAGIAN 1 hanya menutup ~1,59 M (WIP terjurnal); sisa 8,5 M = BAGIAN 2 (alignment opening ke GL).
