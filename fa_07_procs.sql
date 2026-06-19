-- ============================================================
-- FA reusable engine: generate (straight-line), post, regenerate.
-- All posting touches ONLY modul_id='FA' (governance: explicit single source).
-- ============================================================

-- (1) Straight-line generate for one month into FA_DEPRECIATION (draft).
--     Basis: book_value_beginning / remaining_life_begin (handles audit re-lifing).
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_generate_sl')
   THEN DROP PROCEDURE sp_fa_generate_sl END IF;
CREATE PROCEDURE sp_fa_generate_sl(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status IN ('P','C')) THEN
      RAISERROR 17001 'Periode sudah diposting/closed - pakai regenerate';
   END IF;
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period AND posting_status='D';
   INSERT INTO FA_DEPRECIATION (site_id,asset_code,period,depreciation_amount,accum_depreciation,book_value,posting_status)
   SELECT a.site_id, a.asset_code, p_period,
          dep.amt,
          a.accum_dep_beginning + prior.acc + dep.amt,
          a.acquisition_cost - (a.accum_dep_beginning + prior.acc + dep.amt),
          'D'
   FROM FA_ASSET a
   JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   , LATERAL (SELECT COALESCE(SUM(d.depreciation_amount),0) AS acc
                FROM FA_DEPRECIATION d
               WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period<p_period) prior
   , LATERAL (SELECT CASE WHEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2)
                             < (a.book_value_beginning - prior.acc)
                        THEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2)
                        ELSE (a.book_value_beginning - prior.acc) END AS amt) dep
   WHERE a.site_id=p_site AND a.status='A' AND c.depreciable_yn='Y'
     AND a.remaining_life_begin>0
     AND (a.book_value_beginning - prior.acc) > 0
     AND dep.amt > 0;
END;

-- (2) Post/repost one month's FA_DEPRECIATION to gl_journal (modul FA), idempotent.
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_post_period')
   THEN DROP PROCEDURE sp_fa_post_period END IF;
CREATE PROCEDURE sp_fa_post_period(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   DECLARE v_vou varchar(15);
   SET v_vou = 'FA'||p_site||CAST(YEAR(p_period) AS varchar)||RIGHT('0'||CAST(MONTH(p_period) AS varchar),2);
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status='C') THEN
      RAISERROR 17002 'Periode closed - tidak bisa posting';
   END IF;
   -- idempotent: remove prior FA voucher for this period (FA only)
   DELETE FROM gl_journal WHERE site_id=p_site AND voucher=v_vou AND modul_id='FA';

   BEGIN
     DECLARE LOCAL TEMPORARY TABLE cred (voucher varchar(15), tgl timestamp, acc varchar(15),
                                         amt decimal(18,2), catname varchar(50)) NOT TRANSACTIONAL;
     INSERT INTO cred
     SELECT v_vou, p_period, c.accum_dep_account, ROUND(SUM(d.depreciation_amount),0), c.category_name
     FROM FA_DEPRECIATION d
     JOIN FA_ASSET a    ON a.site_id=d.site_id AND a.asset_code=d.asset_code
     JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
     WHERE d.site_id=p_site AND d.period=p_period AND c.accum_dep_account IS NOT NULL
     GROUP BY c.accum_dep_account, c.category_name;

     IF (SELECT COALESCE(SUM(amt),0) FROM cred) = 0 THEN RETURN; END IF;

     INSERT INTO gl_journal (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
     SELECT v_vou,1,p_site,p_period,'FA','412-066',SUM(amt),0,SUM(amt),0,'IDR',1,'N',v_vou,'D',
            'Beban Penyusutan Aktiva Tetap '||CAST(MONTH(p_period) AS varchar)||'/'||CAST(YEAR(p_period) AS varchar)
     FROM cred;
     INSERT INTO gl_journal (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
     SELECT v_vou,1+ROW_NUMBER() OVER (ORDER BY acc),p_site,p_period,'FA',acc,0,amt,0,amt,'IDR',1,'N',v_vou,'K','Akum. Peny. '||catname
     FROM cred;

     UPDATE FA_DEPRECIATION SET posting_status='P', journal_no=v_vou WHERE site_id=p_site AND period=p_period;
     DELETE FROM FA_PERIOD WHERE site_id=p_site AND period=p_period;
     INSERT INTO FA_PERIOD (site_id,period,status,journal_no,total_depr,generate_date,generate_by,post_date,post_by)
     SELECT p_site,p_period,'P',v_vou,SUM(amt),CURRENT TIMESTAMP,CURRENT USER,CURRENT TIMESTAMP,CURRENT USER FROM cred;
     INSERT INTO USER_LOG (USER_ID,ITEM_ID,ITEM_DESC,LOG_DATE,LOG_ACTION,LOG_DESC,LOG_REFF)
     VALUES (CURRENT USER,'FA','Posting penyusutan',CURRENT TIMESTAMP,'FA-POST',v_vou,v_vou);
   END;
   COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RESIGNAL;
END;

-- (3) Regenerate = recompute + repost one month (refuses if closed).
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_regenerate_period')
   THEN DROP PROCEDURE sp_fa_regenerate_period END IF;
CREATE PROCEDURE sp_fa_regenerate_period(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   UPDATE FA_PERIOD SET status='O' WHERE site_id=p_site AND period=p_period AND status='P';
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period;
   CALL sp_fa_generate_sl(p_period,p_site);
   CALL sp_fa_post_period(p_period,p_site);
END;

SELECT 'FA engine procedures created' AS status;
