-- =====================================================================
-- EVIDENCE #4  INVENTORY & TITIPAN RECONCILIATION   (ASA9)
-- Jalankan pasca refresh+close di DB COPY.
-- A. Produk EVAP yg terjual TAPI saldo akhir masih ber-NILAI (phantom) -> target 0.
-- B. Akun Titipan 102-020 sebelum vs sesudah -> penurunan sesuai consin ter-relieve.
-- =====================================================================

-- ---------- A. PHANTOM SALDO AKHIR EVAP (qty=0 tapi nilai<>0) ----------
--   Sebelum fix (part-1 saja) muncul phantom; sesudah fix penuh harus 0.
SELECT 'A. EVAP PHANTOM (qty=0 & nilai<>0)' AS cek,
       (SELECT COUNT(*) FROM _pre_sinv_evap WHERE qty=0 AND nilai<>0)               AS n_pre,
       (SELECT CAST(ISNULL(SUM(nilai),0) AS numeric(18,2)) FROM _pre_sinv_evap WHERE qty=0 AND nilai<>0) AS nilai_pre,
       (SELECT COUNT(*) FROM sinv s WHERE s.stok_id IN (SELECT stok_id FROM _evap_stok)
          AND s.periode>=(SELECT close1 FROM _cfg) AND s.periode<=(SELECT close2 FROM _cfg)
          AND ISNULL(s.qty,0)=0 AND ISNULL(s.nilai,0)<>0)                            AS n_post,
       (SELECT CAST(ISNULL(SUM(s.nilai),0) AS numeric(18,2)) FROM sinv s WHERE s.stok_id IN (SELECT stok_id FROM _evap_stok)
          AND s.periode>=(SELECT close1 FROM _cfg) AND s.periode<=(SELECT close2 FROM _cfg)
          AND ISNULL(s.qty,0)=0 AND ISNULL(s.nilai,0)<>0)                            AS nilai_post
FROM SYS.DUMMY;

-- ---- daftar phantom yg tersisa pasca-fix (harus KOSONG) ----
SELECT s.periode, s.stok_id, CAST(s.qty AS numeric(18,2)) qty, CAST(s.nilai AS numeric(18,2)) nilai
FROM sinv s
WHERE s.stok_id IN (SELECT stok_id FROM _evap_stok)
  AND s.periode>=(SELECT close1 FROM _cfg) AND s.periode<=(SELECT close2 FROM _cfg)
  AND ISNULL(s.qty,0)=0 AND ISNULL(s.nilai,0)<>0
ORDER BY s.periode, s.stok_id;

-- ---------- B. TITIPAN 102-020 : sebelum vs sesudah ----------
--   Consin yg ter-relieve (Cr 102-020) menurunkan saldo titipan.
SELECT 'B. TITIPAN 102-020' AS cek,
       (SELECT CAST(opening+ytd_mutasi AS numeric(18,2)) FROM _pre_titipan_102020) AS saldo_pre,
       CAST((SELECT opening FROM _pre_titipan_102020)
          + (SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal
             WHERE posting='P' AND account_id=(SELECT titipan_acc FROM _cfg) AND tgl<(SELECT p2 FROM _cfg))
          AS numeric(18,2)) AS saldo_post,
       CAST(((SELECT opening FROM _pre_titipan_102020)
          + (SELECT ISNULL(SUM(debet-kredit),0) FROM gl_journal
             WHERE posting='P' AND account_id=(SELECT titipan_acc FROM _cfg) AND tgl<(SELECT p2 FROM _cfg)))
          - (SELECT opening+ytd_mutasi FROM _pre_titipan_102020) AS numeric(18,2)) AS delta_titipan
FROM SYS.DUMMY;

-- ---- ekspektasi: delta_titipan (turun) ~ -SUM(delta_cogs sisi consin ter-relieve) ----
--   Nilai consin yg kini ter-relieve = kredit 102-020 dari consin (modul AS) baris yg dikoreksi.
SELECT 'B2. Consin relieve (Cr 102-020, modul AS) LIVE vs BASELINE' AS cek,
       (SELECT ISNULL(SUM(tot_kredit),0) FROM _pre_gl402 WHERE account_id=(SELECT titipan_acc FROM _cfg) AND modul_id='AS') AS cr_pre,
       (SELECT CAST(ISNULL(SUM(kredit),0) AS numeric(18,2)) FROM gl_journal
          WHERE posting='P' AND account_id=(SELECT titipan_acc FROM _cfg) AND modul_id='AS'
            AND tgl>=(SELECT p1 FROM _cfg) AND tgl<(SELECT p2 FROM _cfg)) AS cr_post
FROM SYS.DUMMY;
