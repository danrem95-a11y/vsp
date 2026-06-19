-- ============================================================================
-- FA RECON LAYER — view & proc rekonsiliasi permanen (audit-style)
-- Mengikat 3 layer: L1 FA_ASSET (register) | L2 FA_DEPRECIATION (engine) | L3 gl_balance (GL)
-- Penghubung movement: FA_GL_LINK. Spec: FA_LAYER_GOVERNANCE.md
-- Additive & reversible (DROP VIEW / DROP PROCEDURE). Dibuat: 2026-06-20
--
-- SUMBER AKUN GL: FA_CATEGORY (asset_account / accum_dep_account), BUKAN FA_ASSET.
--   FA_ASSET.asset_account & accum_dep_account kosong total (0/279) — pemetaan akun
--   tinggal di FA_CATEGORY per kategori (BGN/KDR/PBK/PKT/TNH). Pola ini konsisten dengan
--   sp_fa_build_gl_link di fa_09_gl_link.sql yang juga JOIN ke FA_CATEGORY.
--
-- CUTOFF POLICY: source-of-truth = gl_balance Period '2026-01-01' (opening FY2026 = saldo
--   31/12/2025). DIKUNCI eksplisit, BUKAN MAX(Period) — gl_balance menyimpan snapshot opening
--   tahunan (1-Jan tiap tahun), jadi MAX akan bergeser ke 2027-01-01 setelah closing FY2026
--   dan membandingkan register ke opening tahun yang salah. Lihat FA_LAYER_GOVERNANCE.md §cutoff.
--   Ganti satu konstanta di bawah (atau argumen sp_fa_recon) saat pindah FY.
--
-- CATALOG: SQL Anywhere — view di SYS.SYSTABLE (table_type='VIEW'), proc di SYS.SYSPROCEDURE.
--   (Versi lama memakai sys.sysview/sys.sysprocedure yang TIDAK ADA → seluruh skrip gagal
--    di IF EXISTS pertama dan objek tidak pernah ter-create.)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. v_fa_recon_asset — DETAIL per-aset dengan reason tag (audit view / Output B)
--    Akun GL diambil dari FA_CATEGORY. Cutoff dikunci ke '2026-01-01'.
-- ----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='v_fa_recon_asset' AND table_type='VIEW') THEN
   DROP VIEW v_fa_recon_asset;
END IF;
CREATE VIEW v_fa_recon_asset AS
SELECT a.site_id, a.category_code, a.asset_code, a.asset_name, a.status,
       a.acquisition_date,
       a.acquisition_cost, a.accum_dep_beginning, a.book_value_beginning,
       c.asset_account, c.accum_dep_account,
       CAST(a.acquisition_cost-(a.accum_dep_beginning+a.book_value_beginning) AS numeric(20,2)) AS internal_diff,
       CASE
         WHEN c.accum_dep_account IS NULL                                              THEN 'NON_DEPRECIABLE'
         WHEN ABS(a.acquisition_cost-(a.accum_dep_beginning+a.book_value_beginning))>1 THEN 'INTERNAL_MISMATCH'
         WHEN a.acquisition_date >= '2026-01-01'                                       THEN 'POST_CUTOFF'
         WHEN a.accum_dep_beginning >= a.acquisition_cost-1                            THEN 'FULLY_DEPRECIATED'
         WHEN a.accum_dep_beginning = 0 AND a.acquisition_cost>0                       THEN 'ZERO_ACCUM_REVIEW'
         ELSE 'ACTIVE'
       END AS recon_tag
FROM FA_ASSET a
JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code;

-- ----------------------------------------------------------------------------
-- 2. v_fa_recon_gl — ROLLUP per akun: register vs GL + residual terklasifikasi (Output A)
--    delta            = register - GL
--    post_cutoff_amt  = bagian register dari aset perolehan setelah cutoff GL
--    residual_unexpl  = delta - post_cutoff  (≈0 cocok; <0 missing; >0 PAJE/policy)
--    Akun GL dari FA_CATEGORY. Cutoff dikunci ke '2026-01-01' lewat CTE cutoff(p).
-- ----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='v_fa_recon_gl' AND table_type='VIEW') THEN
   DROP VIEW v_fa_recon_gl;
END IF;
CREATE VIEW v_fa_recon_gl AS
WITH cutoff(p) AS (SELECT CAST('2026-01-01' AS date)),
reg(site_id, acct, typ, reg_amt, post_cutoff_amt) AS (
   SELECT a.site_id, c.asset_account, 'ASSET', SUM(a.acquisition_cost),
          SUM(IF a.acquisition_date >= (SELECT p FROM cutoff) THEN a.acquisition_cost ELSE 0 ENDIF)
   FROM FA_ASSET a JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   GROUP BY a.site_id, c.asset_account
   UNION ALL
   SELECT a.site_id, c.accum_dep_account, 'ACCUM', SUM(a.accum_dep_beginning), 0
   FROM FA_ASSET a JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   WHERE c.accum_dep_account IS NOT NULL
   GROUP BY a.site_id, c.accum_dep_account
)
SELECT r.site_id, r.acct AS account_code, r.typ AS account_type,
       CAST(r.reg_amt AS numeric(20,2)) AS register_amt,
       CAST( (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) AS numeric(20,2)) AS gl_amt,
       CAST( r.reg_amt - (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                            ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) AS numeric(20,2)) AS delta,
       CAST(r.post_cutoff_amt AS numeric(20,2)) AS post_cutoff_amt,
       CAST( (r.reg_amt - (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                            ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF)) - r.post_cutoff_amt
            AS numeric(20,2)) AS residual_unexpl,
       (SELECT p FROM cutoff) AS gl_period
FROM reg r
LEFT JOIN gl_balance b ON b.site_id=r.site_id AND b.AccountCode=r.acct AND b.Period=(SELECT p FROM cutoff);

-- ----------------------------------------------------------------------------
-- 3. sp_fa_recon(@cutoff,@site) — rollup pada periode gl_balance tertentu (parameter)
--    p_cutoff default '2026-01-01'; ganti argumen saat pindah FY (tak perlu ubah kode).
--    Akun GL dari FA_CATEGORY.
-- ----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_recon') THEN
   DROP PROCEDURE sp_fa_recon;
END IF;
CREATE PROCEDURE sp_fa_recon(IN p_cutoff date DEFAULT '2026-01-01', IN p_site varchar(10) DEFAULT '101')
BEGIN
  SELECT r.acct AS account_code, r.typ AS account_type,
         CAST(r.reg_amt AS numeric(20,2)) register_amt,
         CAST((IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                 ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) AS numeric(20,2)) gl_amt,
         CAST(r.reg_amt - (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                            ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) - r.post_cutoff_amt
              AS numeric(20,2)) residual_unexpl
  FROM (
     SELECT a.site_id, c.asset_account acct, 'ASSET' typ, SUM(a.acquisition_cost) reg_amt,
            SUM(IF a.acquisition_date >= p_cutoff THEN a.acquisition_cost ELSE 0 ENDIF) post_cutoff_amt
     FROM FA_ASSET a JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
     WHERE a.site_id=p_site GROUP BY a.site_id, c.asset_account
     UNION ALL
     SELECT a.site_id, c.accum_dep_account, 'ACCUM', SUM(a.accum_dep_beginning), 0
     FROM FA_ASSET a JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
     WHERE a.site_id=p_site AND c.accum_dep_account IS NOT NULL GROUP BY a.site_id, c.accum_dep_account
  ) r
  LEFT JOIN gl_balance b ON b.site_id=r.site_id AND b.AccountCode=r.acct AND b.Period=p_cutoff
  ORDER BY r.typ, r.acct;
END;
