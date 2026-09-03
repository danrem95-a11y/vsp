/* ============================================================================
   RUNBOOK: BACKFILL TBYR 2025 - BINGSHAN (cicilan CI 2025 tak pernah ditulis ke TBYR)
   DB: vspnew (prod 103.233.89.43)
   Faktur 10105250700002 (200.B587), penjualan 7 Jul 2025 = 266.733.000.
   GL lunas (saldo 0): CI 95.737.500 (31 Okt 2025) + CI 170.995.500 (15 Apr 2026).
   TBYR cuma punya yg 2026 (170.995.500) -> Kartu Piutang 2025 gantung 95.737.500.
   Beda dari Metro: lokal TAK punya record 2025 ini (tak pernah ditulis, bukan
   terhapus) -> nilai di-REKONSTRUKSI dari GL voucher 200410125100303.

   AMAN (sama seperti Metro): INSERT TBYR saja; tak sentuh GL/SAF/closing.
   Record tgl 2025 -> di luar jendela opening 2026. SAF=170.995.500 (net) TETAP
   -> Opname Jan-Jun 2026 & Laporan Keuangan TIDAK berubah. Reversible.
   CATATAN: kolektor_id default K001 (kosmetik, tak pengaruh Opname/GL) - boleh
   disesuaikan ke kolektor Bingshan bila ada.
   ============================================================================ */

-- ===== 1. PRE-CHECK =====
select '10105250700002' faktur,
  (select cast(sum(debet)-sum(kredit) as numeric(18,2)) from gl_journal where posting='P' and account_id='103-001' and doc_reff='10105250700002') gl_saldo_hrs_0,     -- 0
  (select cast(isnull(sum(nilai_bayar_idr),0) as numeric(18,2)) from tbyr2 where bukti_id='10105250700002') tbyr_now,                                                   -- 170.995.500
  (select cast(saldo as numeric(18,2)) from SALDO_AWAL_FAKTUR where bukti_id='10105250700002') saf_hrs_tetap;                                                            -- 170.995.500
-- pastikan voucher backfill belum ada (harus 0):
select count(*) hrs_nol from tbyr1 where voucher='200410125100303';

-- ===== 2. BACKFILL (INSERT) =====
insert into tbyr1 (voucher,voucher_manual,tgl,flag_bayar,flag_vendor,vendor_id,kas_id,curr_id,kurs,site_id,kolektor_id,keterangan)
values ('200410125100303','200410125100303','2025-10-31',1,1,'200.B587',0,'IDR',1,'101','K001','RESTORE2025 CI UNIT ONLY 06.2507002');
insert into tbyr2 (voucher,urut,bukti_id,nilai_bayar,nilai_bayar_idr,acc_bayar,flag_order)
values ('200410125100303',1,'10105250700002',95737500,95737500,'103-001',1);
commit;

-- ===== 3. POST-CHECK =====
-- 3a. tbyr faktur kini harus = 266.733.000 (lunas):
select cast(sum(nilai_bayar_idr) as numeric(18,2)) tbyr_harus_266733000 from tbyr2 where bukti_id='10105250700002';
-- 3b. SAF harus TETAP 170.995.500 (2026 aman):
select cast(saldo as numeric(18,2)) saf_harus_tetap from SALDO_AWAL_FAKTUR where bukti_id='10105250700002';
-- 3c. RE-RUN Opname/Kartu Piutang: Des-2025 faktur ...002 turun 266.733.000 -> 170.995.500;
--     Opname Jan-Jun 2026 Bingshan TETAP sama.

-- ===== 4. ROLLBACK (bila perlu) =====
-- delete from tbyr2 where voucher='200410125100303';
-- delete from tbyr1 where voucher='200410125100303';
-- commit;
