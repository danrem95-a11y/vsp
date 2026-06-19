-- Build FA depreciation journals into a STAGING table (mirrors gl_journal columns).
-- One voucher per month: 1 Dr 412-066 (total) + 1 Cr per category accum account.
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='gl_journal_fa_stage') THEN DROP TABLE gl_journal_fa_stage END IF;

CREATE TABLE gl_journal_fa_stage (
    voucher varchar(15), urut integer, site_id varchar(4), tgl timestamp,
    modul_id varchar(2), account_id varchar(15), debet decimal(30,6), kredit decimal(30,6),
    debet_kurs numeric(30,6), kredit_kurs numeric(30,6), curr_id varchar(5), rate_rp decimal(14,2),
    posting varchar(1), voucher_manual varchar(15), dk char(1), ket varchar(250)
);

-- credit lines (per category) + debit lines (total), unioned, then numbered per voucher
INSERT INTO gl_journal_fa_stage
  (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
SELECT voucher, ROW_NUMBER() OVER (PARTITION BY voucher ORDER BY sortkey, account_id) AS urut,
       '101', tgl, 'FA', account_id, debet, kredit, debet, kredit, 'IDR', 1, 'P', voucher, dk, ket
FROM (
   -- DEBIT: total expense to 412-066
   SELECT 'FA101'||CAST(YEAR(d.period) AS varchar)||RIGHT('0'||CAST(MONTH(d.period) AS varchar),2) AS voucher,
          d.period AS tgl, '412-066' AS account_id,
          CAST(SUM(d.depreciation_amount) AS decimal(30,6)) AS debet, CAST(0 AS decimal(30,6)) AS kredit,
          0 AS sortkey, 'D' AS dk,
          'Beban Penyusutan Aktiva Tetap '||CAST(MONTH(d.period) AS varchar)||'/'||CAST(YEAR(d.period) AS varchar) AS ket
   FROM FA_DEPRECIATION d
   WHERE d.site_id='101' AND d.period<='2026-06-30'
   GROUP BY d.period
   UNION ALL
   -- CREDIT: per category to accum account
   SELECT 'FA101'||CAST(YEAR(d.period) AS varchar)||RIGHT('0'||CAST(MONTH(d.period) AS varchar),2),
          d.period, c.accum_dep_account,
          0, CAST(SUM(d.depreciation_amount) AS decimal(30,6)),
          1, 'K',
          'Akum. Peny. '||c.category_name||' '||CAST(MONTH(d.period) AS varchar)||'/'||CAST(YEAR(d.period) AS varchar)
   FROM FA_DEPRECIATION d
   JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
   JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   WHERE d.site_id='101' AND d.period<='2026-06-30' AND c.accum_dep_account IS NOT NULL
   GROUP BY d.period, c.accum_dep_account, c.category_name
) x;
COMMIT;

-- validation: per-voucher balance
SELECT voucher,
       CAST(SUM(debet) AS decimal(18,2)) AS dr,
       CAST(SUM(kredit) AS decimal(18,2)) AS cr,
       CAST(SUM(debet)-SUM(kredit) AS decimal(18,2)) AS selisih,
       COUNT(*) AS lines
FROM gl_journal_fa_stage GROUP BY voucher ORDER BY voucher;
