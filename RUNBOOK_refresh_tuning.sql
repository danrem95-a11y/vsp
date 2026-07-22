-- ============================================================================
-- RUNBOOK: Tuning performa Refresh Transaksi Jurnal (SQL Anywhere 9)
-- DB vspnew, DSN=vsp dba/jakarta.  Berbasis inventaris index NYATA (bukan tebakan).
-- ZERO-RISK ke "hasil identik": index & statistics TIDAK mengubah hasil query,
-- hanya mempercepat. Reversible via DROP INDEX.
-- ----------------------------------------------------------------------------
-- TEMUAN (dari SYSINDEX / SYSIXCOL, 2026-07):
--   gl_journal (605.174 baris)  = TIDAK ADA INDEX  <-- bottleneck utama
--   ar_trans   (30.842)         = tak ada index order_client (dipakai rebuild AR per-baris)
--   ap_trans   (19.398)         = tak ada index order_client (dipakai rebuild AP per-baris)
--   tbyr1      (21.591)         = hanya (voucher); tak ada voucher_manual/tgl
--   tbyr2      (40.222)         = hanya (voucher,urut); tak ada bukti_id
--   sinv,tsales1/2,tstok1/2     = sudah terindeks memadai (SKIP)
-- ----------------------------------------------------------------------------
-- CARA JALAN: sebaiknya saat aplikasi TIDAK sedang refresh/posting (CREATE INDEX
--   butuh table-lock; app yang memegang SHARE lock bisa memblok). Jika terblok,
--   tutup sesi pemakai lalu ulang. Set timeout supaya tak menggantung:
SET OPTION PUBLIC.blocking_timeout = 10000;   -- 10 dtk, error (bukan hang) bila terkunci
-- (opsional balikkan ke 0 setelah selesai: SET OPTION PUBLIC.blocking_timeout = 0;)

-- ============================================================================
-- 1) INDEX gl_journal  (DAMPAK TERBESAR)
-- ============================================================================
-- voucher_manual: dipakai rebuild AR/AP, patch yatim, DP, f_transfer_* (paling sering)
CREATE INDEX idx_glj_vman    ON gl_journal (voucher_manual);
-- voucher: delete/clear (f_re_dp, clear jurnal memo, delete per voucher)
CREATE INDEX idx_glj_voucher ON gl_journal (voucher);
-- (site_id, tgl): retrieve dw_transfer_list + count/sum per periode (site= equality, tgl= range)
CREATE INDEX idx_glj_site_tgl ON gl_journal (site_id, tgl);
-- doc_reff: KRITIS - dipakai delete+update di f_transfer_po/ar/ap/hpp/nonitem/ekspedisi/adj (per-order)
--   (efektif penuh setelah rewrite isnull(doc_reff,'') -> doc_reff di f_transfer_*)
CREATE INDEX idx_glj_docreff ON gl_journal (doc_reff);
COMMIT;

-- ============================================================================
-- 2) INDEX order_client (rebuild AR/AP: SELECT per-baris)
-- ============================================================================
CREATE INDEX idx_ar_ordcl ON ar_trans (order_client);
CREATE INDEX idx_ap_ordcl ON ap_trans (order_client);
COMMIT;

-- ============================================================================
-- 3) INDEX tbyr (patch yatim + rebuild delete by bukti_id)
-- ============================================================================
CREATE INDEX idx_tbyr1_vman  ON tbyr1 (voucher_manual);
CREATE INDEX idx_tbyr1_tgl   ON tbyr1 (tgl, kas_id);
CREATE INDEX idx_tbyr2_bukti ON tbyr2 (bukti_id);
COMMIT;

-- ============================================================================
-- 4) STATISTICS (non-destruktif) — bantu optimizer pilih index baru
-- ============================================================================
CREATE STATISTICS gl_journal;
CREATE STATISTICS ar_trans;
CREATE STATISTICS ap_trans;
CREATE STATISTICS tbyr1;
CREATE STATISTICS tbyr2;

-- ============================================================================
-- VERIFIKASI: index terpasang
-- ============================================================================
SELECT t.table_name, ix.index_name, c.column_name, ic.sequence
FROM   SYSINDEX ix
JOIN   SYSTABLE t  ON t.table_id = ix.table_id
JOIN   SYSIXCOL ic ON ic.table_id = ix.table_id AND ic.index_id = ix.index_id
JOIN   SYSCOLUMN c ON c.table_id = ic.table_id AND c.column_id = ic.column_id
WHERE  ix.index_name LIKE 'idx_glj%' OR ix.index_name LIKE 'idx_ar_ord%'
   OR  ix.index_name LIKE 'idx_ap_ord%' OR ix.index_name LIKE 'idx_tbyr%'
ORDER  BY t.table_name, ix.index_name, ic.sequence;

-- ROLLBACK (bila perlu batalkan tuning):
--   DROP INDEX gl_journal.idx_glj_vman; DROP INDEX gl_journal.idx_glj_voucher;
--   DROP INDEX gl_journal.idx_glj_site_tgl;
--   DROP INDEX ar_trans.idx_ar_ordcl;  DROP INDEX ap_trans.idx_ap_ordcl;
--   DROP INDEX tbyr1.idx_tbyr1_vman; DROP INDEX tbyr1.idx_tbyr1_tgl; DROP INDEX tbyr2.idx_tbyr2_bukti;
-- ============================================================================
