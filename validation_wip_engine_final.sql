-- ============================================================================
-- validation_wip_engine_final.sql -- REKONSILIASI WAJIB Laporan Konsinyasi 2026 (READ-ONLY)
-- Jalankan SETELAH: (1) build+deploy n_cst_closing_stock.sru baru, (2) provision_wip_audit_tables.sql,
-- (3) re-refresh Jan-Jul 2026 (via w_refresh_transaksi_modern, akan otomatis panggil tier-3+gate).
-- ============================================================================
IF VAREXISTS('p_from')=1 THEN DROP VARIABLE p_from END IF;
IF VAREXISTS('p_to')=1   THEN DROP VARIABLE p_to   END IF;
CREATE VARIABLE p_from DATE; SET p_from='2026-01-01';
CREATE VARIABLE p_to   DATE; SET p_to  ='2026-07-31';

-- ============================================================================
-- POINT 1: Saldo akhir tahun sebelumnya = saldo awal tahun berjalan (102-020)
-- ============================================================================
SELECT
  cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2025-01-01')
       + (select sum(isnull(debet,0)-isnull(kredit,0)) from gl_journal where account_id='102-020' and tgl between '2025-01-01' and '2025-12-31')
       as numeric(20,2)) saldo_akhir_2025,
  cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01') as numeric(20,2)) saldo_awal_2026,
  case when abs(
    ((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2025-01-01')
       + (select sum(isnull(debet,0)-isnull(kredit,0)) from gl_journal where account_id='102-020' and tgl between '2025-01-01' and '2025-12-31'))
    - (select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
  )<=1 then 'PASS' else 'FAIL' end point1_status;

-- ============================================================================
-- POINT 2: WIP-Out & WIP-In -- Mutasi Stok (TR/NR/TB) = GL COA 102-020 (counterpart)
-- CHECK 1 (WIP-IN laporan=mutasi): dijamin STRUKTURAL -- Laporan Konsinyasi (dw_rpt_cons_outs.srd)
--   baca tstok2/tsales2 LANGSUNG (b.hpp/b.netto), tanpa kalkulasi independen -- dikonfirmasi baca SQL
--   report. Maka "laporan" = "mutasi" by construction (bukan 2 sumber, 1 field yg sama dibaca 2 tempat).
--   Query 2a/2b di bawah = mutasi vs GL (perbandingan yg SUBSTANTIF, laporan otomatis ikut).
-- ============================================================================
-- 2a. CHECK 1: WIP-IN mutasi vs GL (harus tetap PASS, formula tak diubah)
SELECT gr.persediaan akun,
  cast(sum(isnull(t2.NETTO,0)) as numeric(20,2)) wipin_mutasi,
  cast((select sum(isnull(g2.kredit,0)) from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl
          where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS' and g2.account_id=gr.persediaan and isnull(g2.kredit,0)>0
            and g1.tgl between :p_from and :p_to) as numeric(20,2)) wipin_gl,
  case when abs(sum(isnull(t2.NETTO,0)) - isnull((select sum(isnull(g2.kredit,0)) from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl
          where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS' and g2.account_id=gr.persediaan and isnull(g2.kredit,0)>0
            and g1.tgl between :p_from and :p_to),0)) <=1 then 'PASS' else 'FAIL' end status
FROM tstok1 t1 JOIN tstok2 t2 ON t1.bukti_id=t2.bukti_id JOIN im_produk pr ON pr.produk_id=t2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE t1.tipe_trans='88' AND t1.tgl BETWEEN :p_from AND :p_to AND gr.persediaan IN ('102-001','102-003','102-006')
GROUP BY gr.persediaan ORDER BY gr.persediaan;

-- 2b. CHECK 2: WIP-OUT mutasi vs GL (TARGET UTAMA FIX INI -- harus PASS setelah tier-3+gate live)
SELECT gr.persediaan akun,
  cast(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) as numeric(20,2)) wipout_mutasi,
  cast((select sum(isnull(g2.kredit,0)) from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl
          where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS' and g2.account_id=gr.persediaan and isnull(g2.kredit,0)>0
            and g1.tgl between :p_from and :p_to) as numeric(20,2)) wipout_gl,
  cast(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) - isnull((select sum(isnull(g2.kredit,0)) from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl
          where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS' and g2.account_id=gr.persediaan and isnull(g2.kredit,0)>0
            and g1.tgl between :p_from and :p_to),0) as numeric(20,2)) selisih,
  case when abs(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) - isnull((select sum(isnull(g2.kredit,0)) from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl
          where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS' and g2.account_id=gr.persediaan and isnull(g2.kredit,0)>0
            and g1.tgl between :p_from and :p_to),0)) <=1 then 'PASS' else 'FAIL' end status
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id JOIN im_produk pr ON pr.produk_id=s2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE s1.tipe_trans='88' AND s1.tgl BETWEEN :p_from AND :p_to AND gr.persediaan IN ('102-001','102-003','102-006')
GROUP BY gr.persediaan ORDER BY gr.persediaan;

-- 2c. Sisa jual '88' EVAP dgn HPP=0 (harus 0 baris -- kalau >0, ada orphan baru tanpa GL sama sekali)
SELECT count(*) sisa_88_hpp0_HARUS_0
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans='88' AND isnull(s2.evap,'')<>'' AND isnull(s2.HPP,0)=0 AND s1.tgl BETWEEN :p_from AND :p_to;

-- ============================================================================
-- POINT 3 / CHECK 3: Total Outstanding WIP (laporan) = GL COA 102-020
-- ============================================================================
SELECT
  cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
     + (select sum(isnull(t2.NETTO,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id join im_produk pr on pr.produk_id=s2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product
          where s1.tipe_trans='88' and gr.persediaan in ('102-001','102-003','102-006') and s1.tgl between :p_from and :p_to)
     - (select sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id join im_produk pr on pr.produk_id=s2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product
          where s1.tipe_trans='88' and gr.persediaan in ('102-001','102-003','102-006') and s1.tgl between :p_from and :p_to)
     as numeric(20,2)) outstanding_laporan,
  cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
     + (select sum(isnull(debet,0)-isnull(kredit,0)) from gl_journal where account_id='102-020' and tgl between :p_from and :p_to)
     as numeric(20,2)) gl_102020,
  case when abs(
    ( (select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
     + (select sum(isnull(t2.NETTO,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id join im_produk pr on pr.produk_id=s2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product
          where s1.tipe_trans='88' and gr.persediaan in ('102-001','102-003','102-006') and s1.tgl between :p_from and :p_to)
     - (select sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id join im_produk pr on pr.produk_id=s2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product
          where s1.tipe_trans='88' and gr.persediaan in ('102-001','102-003','102-006') and s1.tgl between :p_from and :p_to) )
    - ( (select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')
     + (select sum(isnull(debet,0)-isnull(kredit,0)) from gl_journal where account_id='102-020' and tgl between :p_from and :p_to) )
  )<=1 then 'PASS' else 'FAIL' end point3_status;

-- ============================================================================
-- GATE RESULT (ditulis otomatis oleh of_run tiap refresh) -- HARUS 0 baris MISMATCH
-- ============================================================================
SELECT * FROM wip_out_gate_result WHERE periode_from=:p_from AND periode_to<=:p_to AND status='MISMATCH' ORDER BY tgl_check DESC;

-- GATE DETAIL (format wajib: Account/Transaksi/Item/Mutasi/GL/Selisih) -- terisi HANYA bila ada MISMATCH
--   di atas; kosong = tidak ada transaksi bermasalah (kondisi normal setelah fix).
SELECT account_id "Account", bukti_id "Transaksi", item_id "Item",
       cast(mutasi as numeric(20,2)) "Mutasi", cast(gl as numeric(20,2)) "GL", cast(selisih as numeric(20,2)) "Selisih"
FROM wip_out_gate_detail WHERE periode_from=:p_from AND periode_to=:p_to ORDER BY abs(selisih) DESC;

-- ============================================================================
-- AUDIT TRAIL: baris yg diselamatkan tier-3 (GL fallback) -- bukti Rp90.282.153,36 sudah tertutup by design
-- ============================================================================
SELECT tgl_log, user_refresh, bukti_id, stok_id, evap, qty, hpp_lama, hpp_final, nilai_gl, selisih_sebelum, sumber
FROM wip_out_cost_log ORDER BY tgl_log DESC;
SELECT cast(sum(selisih_sebelum) as numeric(20,2)) total_selisih_tertutup_tier3 FROM wip_out_cost_log WHERE sumber='GL_FALLBACK_TIER3';
-- Target: total ini = 90.282.153,36 (untuk data Jan-Jul yg sudah ada saat dokumen ini dibuat) + kasus baru bila muncul.

-- ============================================================================
-- IDEMPOTENCY: ulangi refresh Jan-Jul -> wip_out_cost_log TIDAK bertambah baris baru (tier1/2 sudah freeze,
--   tier-3 hanya fire saat HPP=0; setelah terisi sekali, ISNULL(HPP,0)=0 tak lagi true -> guard alami).
-- ============================================================================
SELECT count(*) n_log_entries_saat_ini FROM wip_out_cost_log;
-- (jalankan lagi setelah re-refresh kedua kali; count harus SAMA -- tidak ada baris log baru)

-- ============================================================================
-- CONSISTENCY: of_get_wip_out_value() vs tsales2.HPP hasil bulk -- harus identik utk 2 kasus akar
-- (jalankan via PB/dbisql yg bisa panggil NVO; di sini bukti data-level saja -- lihat FIX doc bag. 6)
-- ============================================================================
SELECT s2.BUKTI_ID, s2.STOK_ID, s2.EVAP, cast(s2.HPP as numeric(18,4)) hpp_tersimpan_bulk
FROM tsales2 s2 WHERE s2.BUKTI_ID IN ('10126058800028','10126058800065') AND isnull(s2.EVAP,'')<>'';
