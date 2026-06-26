CREATE VIEW v_fa_recon_asset AS
SELECT a.site_id, a.category_code, a.asset_code, a.asset_name, a.status,
       a.acquisition_date, a.acquisition_cost, a.accum_dep_beginning, a.book_value_beginning,
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

CREATE VIEW v_fa_recon_gl AS
SELECT r.site_id, r.acct AS account_code, r.typ AS account_type,
       CAST(r.reg_amt AS numeric(20,2)) AS register_amt,
       CAST(IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                             ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF AS numeric(20,2)) AS gl_amt,
       CAST(r.reg_amt - (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                          ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) AS numeric(20,2)) AS delta,
       CAST(r.post_cutoff_amt AS numeric(20,2)) AS post_cutoff_amt,
       CAST(r.reg_amt - (IF r.typ='ASSET' THEN COALESCE(b.AmountDebet,0)-COALESCE(b.AmountCredit,0)
                                          ELSE COALESCE(b.AmountCredit,0)-COALESCE(b.AmountDebet,0) ENDIF) - r.post_cutoff_amt AS numeric(20,2)) AS residual_unexpl
FROM (
   SELECT site_id, asset_account acct, 'ASSET' typ, SUM(acquisition_cost) reg_amt,
          SUM(IF acquisition_date >= (SELECT MAX(Period) FROM gl_balance) THEN acquisition_cost ELSE 0 ENDIF) post_cutoff_amt
   FROM FA_ASSET GROUP BY site_id, asset_account
   UNION ALL
   SELECT site_id, accum_dep_account, 'ACCUM', SUM(accum_dep_beginning), 0
   FROM FA_ASSET WHERE accum_dep_account IS NOT NULL GROUP BY site_id, accum_dep_account
) r
LEFT JOIN gl_balance b ON b.site_id=r.site_id AND b.AccountCode=r.acct AND b.Period=(SELECT MAX(Period) FROM gl_balance);
