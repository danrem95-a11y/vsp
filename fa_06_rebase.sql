-- Atomic rebase: delete 4 manual GJ MEMO (Jan-Apr) + post FA101202601..06 (modul FA),
-- whole-rupiah category amounts, posting='N' (matches replaced unposted entries), Dr=Cr guaranteed.
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_rebase_jan_jun')
   THEN DROP PROCEDURE sp_fa_rebase_jan_jun END IF;

CREATE PROCEDURE sp_fa_rebase_jan_jun()
BEGIN
   DECLARE LOCAL TEMPORARY TABLE cred (voucher varchar(15), tgl timestamp, acc varchar(15),
                                       amt decimal(18,2), catname varchar(50)) NOT TRANSACTIONAL;

   -- rounded category credits per month
   INSERT INTO cred
   SELECT 'FA101'||CAST(YEAR(d.period) AS varchar)||RIGHT('0'||CAST(MONTH(d.period) AS varchar),2),
          d.period, c.accum_dep_account,
          ROUND(SUM(d.depreciation_amount),0), c.category_name
   FROM FA_DEPRECIATION d
   JOIN FA_ASSET a    ON a.site_id=d.site_id AND a.asset_code=d.asset_code
   JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   WHERE d.site_id='101' AND d.period<='2026-06-30' AND c.accum_dep_account IS NOT NULL
   GROUP BY d.period, c.accum_dep_account, c.category_name;

   -- remove the 4 manual depreciation memos (Jan-Apr)
   DELETE FROM gl_journal WHERE voucher IN
     ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018');

   -- debit line (urut 1): total expense to 412-066
   INSERT INTO gl_journal
     (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,
      curr_id,rate_rp,posting,voucher_manual,dk,ket)
   SELECT voucher,1,'101',tgl,'FA','412-066',SUM(amt),0,SUM(amt),0,
          'IDR',1,'N',voucher,'D',
          'Beban Penyusutan Aktiva Tetap '||CAST(MONTH(tgl) AS varchar)||'/'||CAST(YEAR(tgl) AS varchar)
   FROM cred GROUP BY voucher,tgl;

   -- credit lines (urut 2..n): per category accum account
   INSERT INTO gl_journal
     (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,
      curr_id,rate_rp,posting,voucher_manual,dk,ket)
   SELECT voucher, 1+ROW_NUMBER() OVER (PARTITION BY voucher ORDER BY acc),
          '101',tgl,'FA',acc,0,amt,0,amt,'IDR',1,'N',voucher,'K',
          'Akum. Peny. '||catname
   FROM cred;

   -- mark sub-ledger posted + period control
   UPDATE FA_DEPRECIATION
      SET posting_status='P',
          journal_no='FA101'||CAST(YEAR(period) AS varchar)||RIGHT('0'||CAST(MONTH(period) AS varchar),2)
    WHERE site_id='101' AND period<='2026-06-30';

   DELETE FROM FA_PERIOD WHERE site_id='101' AND period<='2026-06-30';
   INSERT INTO FA_PERIOD (site_id,period,status,journal_no,total_depr,generate_date,generate_by,post_date,post_by)
   SELECT '101',tgl,'P','FA101'||CAST(YEAR(tgl) AS varchar)||RIGHT('0'||CAST(MONTH(tgl) AS varchar),2),
          SUM(amt),CURRENT TIMESTAMP,CURRENT USER,CURRENT TIMESTAMP,CURRENT USER
   FROM cred GROUP BY tgl;

   INSERT INTO USER_LOG (USER_ID,ITEM_ID,ITEM_DESC,LOG_DATE,LOG_ACTION,LOG_DESC,LOG_REFF)
   VALUES (CURRENT USER,'FA','Rebase penyusutan Jan-Jun 2026 ke modul FA',CURRENT TIMESTAMP,
           'FA-REBASE','del 4 MEMO + post FA101202601..06','FA101202601-06');

   COMMIT;
EXCEPTION WHEN OTHERS THEN
   ROLLBACK;
   RESIGNAL;
END;
