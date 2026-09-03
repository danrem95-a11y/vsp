-- ============================================================
-- INVARIANT CHECKER + DETECTORS (P3 hardening Refresh Modern) -- READ-ONLY
-- Jalankan tiap selesai refresh. Hasil KOSONG (atau hanya item yang sudah diketahui) = LULUS.
-- Semua query SUDAH DIVALIDASI di DB prod (vspnew) 2026-07-31.
--
-- KONVENSI PERIODE:
--   sinv.periode = tanggal AWAL bulan; saldo di baris itu = closing bulan sebelumnya.
--   Contoh: closing Juli 2026 => sinv.periode = '2026-08-01'.
--   GL closing bulan = gl_balance[opening tahun] + SUM(gl_journal movement s/d akhir bulan).
--
-- GANTI 3 KONSTANTA sesuai bulan yang dicek:
--   @sinv_next  = awal bulan BERIKUTNYA (closing bln dicek)  -> '2026-08-01'
--   @thn_open   = opening tahun berjalan                      -> '2026-01-01'
--   @eom        = akhir bulan yang dicek                      -> '2026-07-31'
-- ============================================================


-- ============================================================
-- INV-01 : SINV = GL per akun persediaan (opening tahun + movement)
--   Anomali = |selisih| > toleransi. Sub-rupiah (rounding) diabaikan.
--   Item BESAR yang sudah diketahui (pra seed-opening): 102-001 (phantom opening),
--   102-006, 102-201 (saldo awal MT), 102-102 -- lihat memory saldo-awal-2026-mismatch.
--   Setelah year-close/seed-opening (al_replace=1) dijalankan, item ini harus mengecil ke ~0.
-- ============================================================
select g.acc,
  cast(isnull(sv.sinv,0) as numeric(20,2))                          as sinv_nilai,
  cast(isnull(op.opn,0)+isnull(mv.mov,0) as numeric(20,2))          as gl_nilai,
  cast(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0)) as numeric(20,2)) as selisih
from (select distinct persediaan acc from im_product_group where isnull(persediaan,'')<>'') g
left join ( select gr.persediaan acc, sum(s.nilai) sinv
            from sinv s join im_produk pr on pr.produk_id=s.stok_id
                        join im_product_group gr on gr.kode_group=pr.group_product
            where s.periode = '2026-08-01'            /* @sinv_next */
            group by gr.persediaan ) sv on sv.acc=g.acc
left join ( select AccountCode acc, sum(AmountDebet)-sum(AmountCredit) opn
            from gl_balance where Period='2026-01-01'  /* @thn_open */
            group by AccountCode ) op on op.acc=g.acc
left join ( select account_id acc, sum(debet)-sum(kredit) mov
            from gl_journal
            where tgl between '2026-01-01' and '2026-07-31'  /* @thn_open .. @eom */
            group by account_id ) mv on mv.acc=g.acc
where abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) > 1
order by abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) desc;


-- ============================================================
-- STOCK_MINUS_DETECTED : pengganti oto-minus (al_minus=0).
--   Stok minus jadi TEMUAN, bukan ditambal diam-diam ke saldo Januari.
--   Kosong = tak ada stok minus pada closing bulan.
-- ============================================================
select 'STOCK_MINUS' det, gr.persediaan, sv.stok_id, pr.produk_desc,
       cast(sv.qty as numeric(18,2)) qty_minus, cast(sv.nilai as numeric(20,2)) nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id
             join im_product_group gr on gr.kode_group=pr.group_product
where sv.periode='2026-08-01'                 /* @sinv_next */ and sv.qty < 0
order by sv.qty asc;


-- ============================================================
-- B4-MONITOR : WIP-In '88' dengan COA_ID (serial) kosong padahal description berisi.
--   HARUS 0. Event scheduled "UPDATE HPP_TSTOK2" mengisi ini per jam (idempoten, isi blank saja).
--   Bila > 0 -> ada jalur yang membuat WIP-In tanpa serial; selidiki sumbernya (bukan matikan event).
-- ============================================================
select 'B4_BLANK_COA' det, A.bukti_id, B.stok_id, B.description
from tstok1 A join tstok2 B on A.bukti_id=B.bukti_id
where A.tipe_trans='88' and isnull(B.coa_id,'')='' and isnull(B.description,'')<>'';


-- ============================================================
-- INV-03 (INFORMASIONAL) : outstanding WIP-Out (belum ada WIP-In) vs saldo GL 102-020.
--   Selisih WAJAR ~ carry-forward 2020 + residu valuasi (lihat CLOSURE_102020.md). Bukan pass/fail
--   ketat; pantau tren. Naik tajam = ada WIP-Out baru tak ter-cover WIP-In.
-- ============================================================
select 'INV-03 WIP vs 102-020' inv,
  cast(( select sum(isnull(s2.hpp,0)*isnull(s2.qty,0))
         from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
         where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-07-31'  /* @eom */
         and not exists (select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
              where t1.tipe_trans='88' and t2.stok_id=s2.stok_id
                and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-07-31') /* @eom */
       ) as numeric(20,2)) outstanding_wipout,
  cast(( select isnull(sum(AmountDebet)-sum(AmountCredit),0) from gl_balance
         where AccountCode='102-020' and Period='2026-01-01'  /* @thn_open */ )
     + ( select isnull(sum(debet)-sum(kredit),0) from gl_journal
         where account_id='102-020' and tgl between '2026-01-01' and '2026-07-31' )  /* @thn_open .. @eom */
     as numeric(20,2)) gl_102020;


-- ============================================================
-- INV-04 CONSIGNMENT out=in : lihat DETEKTOR_residu_hpp_bulanan.sql (G4) -- pasangan
--   WIP-Out(evap) vs WIP-In(coa_id) per serial. Dipisah agar match lintas-bulan benar.
-- INV-05 AR=GL / AP=GL : jalankan allrecon.ps1 / allrecon_julext.ps1 (opname vs ledger).
--   AR 103-001 ; AP 226-xxx. Gap yang diketahui: DPB valas & cicilan CI 2025 (lihat memory).
-- ============================================================
