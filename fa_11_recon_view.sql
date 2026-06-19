-- ============================================================================
-- FA RECON LAYER — view & proc rekonsiliasi permanen (audit-style)
-- Mengikat 3 layer: L1 FA_ASSET (register) | L2 FA_DEPRECIATION (engine) | L3 gl_balance (GL)
-- Penghubung movement: FA_GL_LINK. Spec: FA_LAYER_GOVERNANCE.md
-- Additive & reversible (DROP VIEW / DROP PROCEDURE). Dibuat: 2026-06-20
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. v_fa_recon_asset — DETAIL per-aset dengan reason tag (audit view)
--    Cutoff = snapshot gl_balance terakhir (MAX Period).
-- ----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM sys.sysview WHERE viewname='v_fa_recon_asset') THEN DROP VIEW v_fa_recon_asset END IF;
CREATE VIEW v_fa_recon_asset AS
SELECT a.site_id, a.category_code, a.asset_code, a.asset_name, a.status,
       a.acquisition_date,
       a.acquisition_cost, a.accum_dep_beginning, a.book_value_beginning,
       a.asset_account, a.accum_dep_account,
       CAST(a.acquisition_cost-(a.accum_dep_beginning+a.book_value_beginning) AS numeric(20,2)) AS internal_diff,
       CASE
         WHEN a.accum_dep_account IS NULL                                              THEN 'NON_DEPRECIABLE'
         WHEN ABS(a.acquisition_cost-(a.accum_dep_beginning+a.book_value_beginning))>1 THEN 'INTERNAL_MISMATCH'
         WHEN a.acquisition_date >= (SELECT MAX(Period) FROM gl_balance)               THEN 'POST_CUTOFF'
         WHEN a.accum_dep_beginning >= a.acquisition_cost-1                            THEN 'FULLY_DEPRECIATED'
         WHEN a.accum_dep_beginning = 0 AND a.acquisition_cost>0                       THEN 'ZERO_ACCUM_REVIEW'
         ELSE 'ACTIVE'
       END AS recon_tag
FROM FA_ASSET a;

-- ----------------------------------------------------------------------------
-- 2. v_fa_recon_gl — ROLLUP per akun: register vs GL + residual terklasifikasi
--    delta            = register - GL
--    post_cutoff_amt  = bagian register dari aset perolehan setelah cutoff GL
--    residual_unexpl  = delta - post_cutoff  (≈0 cocok; <0 missing; >0 PAJE/policy)
-- ----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM sys.sysview WHERE viewname='v_fa_recon_gl') THEN DROP VIEW v_fa_recon_gl END IF;
CREATE VIEW v_fa_recon_gl AS
WITH cutoff(p) AS (SELECT MAX(Period) FROM gl_balance),
reg(site_id, acct, typ, reg_amt, post_cutoff_amt) AS (
   SELECT site_id, asset_account, 'ASSET', SUM(acquisition_cost),
          SUM(IF acquisition_date >= (SELECT p FROM cutoff) THEN acquisition_cost ELSE 0 ENDIF)
   FROM FA_ASSET GROUP BY site_id, asset_account
   UNION ALL
   SELECT site_id, accum_dep_account, 'ACCUM', SUM(accum_dep_beginning), 0
   FROM FA_ASSET WHERE accum_dep_account IS NOT NULL GROUP BY site_id, accum_dep_account
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
-- 3. sp_fa_recon(@period) — rollup pada periode gl_balance tertentu (parameter)
-- ----------------------------------------------------------------------------
IF EXISTS(SELECT 1 FROM sys.sysprocedure WHERE proc_name='sp_fa_recon') THEN DROP PROCEDURE sp_fa_recon END IF;
CREATE PROCEDURE sp_fa_recon(IN p_period date, IN p_site varchar(10))
BEGIN
  SELECT r.acct AS account_code, r.typ AS account_type,
         CAST(r.reg_amt AS numeric(20,2)) register_amt,
         CAST((IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                 ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) AS numeric(20,2)) gl_amt,
         CAST(r.reg_amt - (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                            ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) - r.post_cutoff_amt
              AS numeric(20,2)) residual_unexpl
  FROM (
     SELECT site_id, asset_account acct, 'ASSET' typ, SUM(acquisition_cost) reg_amt,
            SUM(IF acquisition_date >= p_period THEN acquisition_cost ELSE 0 ENDIF) post_cutoff_amt
     FROM FA_ASSET WHERE site_id=p_site GROUP BY site_id, asset_account
     UNION ALL
     SELECT site_id, accum_dep_account, 'ACCUM', SUM(accum_dep_beginning), 0
     FROM FA_ASSET WHERE site_id=p_site AND accum_dep_account IS NOT NULL GROUP BY site_id, accum_dep_account
  ) r
  LEFT JOIN gl_balance b ON b.site_id=r.site_id AND b.AccountCode=r.acct AND b.Period=p_period
  ORDER BY r.typ, r.acct;
END;
