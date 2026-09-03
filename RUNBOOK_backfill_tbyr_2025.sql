/* ============================================================================
   RUNBOOK: RESTORE TBYR 2025 (record cicilan CI yg TERHAPUS di prod)
   DB: vspnew (prod 103.233.89.43)
   BUKTI: record ini MASIH ADA di DB lokal (belum kena hapus) dan disalin PERSIS
          di sini. Lokal membuktikan: dgn record ini -> Opname Des-2025 =94.355.300
          (terpotong), SAF & Opname 2026 TIDAK berubah (94.355.300 & 481.823.000).

   PRINSIP AMAN:
     - HANYA INSERT ke TBYR1/TBYR2. TIDAK sentuh GL / SALDO_AWAL_FAKTUR(SAF) /
       closing. Record bertanggal 2025 -> di luar jendela opening 2026 ->
       Opname Jan-Jun 2026 & Laporan Keuangan TIDAK berubah.
     - Reversible: rollback = DELETE by voucher (Bagian 4).

   SCOPE (CONFIRMED via lokal): HANYA Metro Motor faktur 10103251100061 = 250jt.
     - 25112004R117R : 200jt (28 Nov 2025)   <- persis nomor yg dilaporkan user AR
     - 25122004R009R :  50jt (03 Des 2025)   <- persis nomor yg dilaporkan user AR
   DIKELUARKAN (butuh review manual terpisah, lokal TIDAK mengonfirmasi):
     - BINGSHAN 10105250700002 (95.737.500) : di lokal faktur ini tbyr-nya 1 record
       Apr-2026 (170.995.500), TIDAK ada record 2025 -> kasus beda, jangan backfill.
     - SUTRISNO 101RK241100001 (4.498.830)  : modul SO, lawan 228-003 -> non-standar.
   ============================================================================ */

-- ===== BAGIAN 1: PRE-CHECK =====
select '10103251100061' faktur,
  (select cast(sum(debet)-sum(kredit) as numeric(18,2)) from gl_journal where posting='P' and account_id='103-001' and doc_reff='10103251100061') gl_saldo_hrs_0,
  (select cast(isnull(sum(nilai_bayar_idr),0) as numeric(18,2)) from tbyr2 where bukti_id='10103251100061') tbyr_now_kurang;
select count(*) hrs_nol from tbyr1 where voucher in ('25112004R117R','25122004R009R');
-- catat juga (untuk dibandingkan setelah backfill; HARUS tetap sama):
select cast(saldo as numeric(18,2)) saf_2026_hrs_tetap from SALDO_AWAL_FAKTUR where bukti_id='10103251100061';  -- 94.355.300

-- ===== BAGIAN 2: RESTORE (INSERT persis dari lokal) =====
insert into tbyr1 (voucher,voucher_manual,tgl,flag_bayar,flag_vendor,vendor_id,kas_id,curr_id,kurs,site_id,kolektor_id,keterangan)
values ('25112004R117R','25112004R117','2025-11-28',1,1,'200.M096',0,'IDR',1,'101','K001','RESTORE2025 CI UNIT KE-1 P331/11/25');
insert into tbyr2 (voucher,urut,bukti_id,nilai_bayar,nilai_bayar_idr,acc_bayar,flag_order)
values ('25112004R117R',1,'10103251100061',200000000,200000000,'103-001',1);

insert into tbyr1 (voucher,voucher_manual,tgl,flag_bayar,flag_vendor,vendor_id,kas_id,curr_id,kurs,site_id,kolektor_id,keterangan)
values ('25122004R009R','25122004R009','2025-12-03',1,1,'200.M096',0,'IDR',1,'101','K001','RESTORE2025 CI UNIT KE-1 P331/11/25');
insert into tbyr2 (voucher,urut,bukti_id,nilai_bayar,nilai_bayar_idr,acc_bayar,flag_order)
values ('25122004R009R',1,'10103251100061',50000000,50000000,'103-001',1);

commit;

-- ===== BAGIAN 3: POST-CHECK =====
-- 3a. tbyr faktur Metro kini harus = 344.355.300 (lunas penuh):
select cast(sum(nilai_bayar_idr) as numeric(18,2)) tbyr_harus_344355300 from tbyr2 where bukti_id='10103251100061';
-- 3b. SAF harus TETAP 94.355.300 (tak berubah -> 2026 aman):
select cast(saldo as numeric(18,2)) saf_harus_tetap from SALDO_AWAL_FAKTUR where bukti_id='10103251100061';
-- 3c. Lalu RE-RUN laporan Opname/Kartu Piutang: Des-2025 faktur ini terpotong (94jt),
--     dan Opname Jan-Jun 2026 Metro tetap sama (481.823.000).

-- ===== BAGIAN 4: ROLLBACK (bila perlu) =====
-- delete from tbyr2 where voucher in ('25112004R117R','25122004R009R');
-- delete from tbyr1 where voucher in ('25112004R117R','25122004R009R');
-- commit;
