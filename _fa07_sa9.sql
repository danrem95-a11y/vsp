IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_generate_sl') THEN DROP PROCEDURE sp_fa_generate_sl END IF;
CREATE PROCEDURE sp_fa_generate_sl(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   DECLARE v_acc decimal(18,2);
   DECLARE v_straight decimal(18,2);
   DECLARE v_amt decimal(18,2);
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status IN ('P','C')) THEN
      RAISERROR 17001 'Periode sudah diposting/closed - pakai regenerate';
   END IF;
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period AND posting_status='D';
   FOR fl AS cur CURSOR FOR
      SELECT a.site_id AS s, a.asset_code AS code, a.book_value_beginning AS bvb,
             a.remaining_life_begin AS rl, a.accum_dep_beginning AS adb, a.acquisition_cost AS cost
      FROM FA_ASSET a JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
      WHERE a.site_id=p_site AND a.status='A' AND c.depreciable_yn='Y' AND a.remaining_life_begin>0
   DO
      SET v_acc = (SELECT COALESCE(SUM(depreciation_amount),0) FROM FA_DEPRECIATION
                   WHERE site_id=s AND asset_code=code AND period<p_period);
      SET v_straight = ROUND(bvb/rl,2);
      IF v_straight < (bvb - v_acc) THEN SET v_amt=v_straight; ELSE SET v_amt=bvb - v_acc; END IF;
      IF v_amt > 0 AND (bvb - v_acc) > 0 THEN
         INSERT INTO FA_DEPRECIATION (site_id,asset_code,period,depreciation_amount,accum_depreciation,book_value,posting_status)
         VALUES (s,code,p_period,v_amt,adb+v_acc+v_amt,cost-(adb+v_acc+v_amt),'D');
      END IF;
   END FOR;
END;

IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_post_period') THEN DROP PROCEDURE sp_fa_post_period END IF;
CREATE PROCEDURE sp_fa_post_period(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   DECLARE v_vou varchar(15);
   SET v_vou='FA'||p_site||CAST(YEAR(p_period) AS varchar(4))||RIGHT('0'||CAST(MONTH(p_period) AS varchar(2)),2);
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status='C') THEN
      RAISERROR 17002 'Periode closed - tidak bisa posting';
   END IF;
   DELETE FROM gl_journal WHERE site_id=p_site AND voucher=v_vou AND modul_id='FA';
   BEGIN
     DECLARE LOCAL TEMPORARY TABLE cred (acc varchar(15), amt decimal(18,2), catname varchar(50)) NOT TRANSACTIONAL;
     INSERT INTO cred SELECT c.accum_dep_account, ROUND(SUM(d.depreciation_amount),0), c.category_name
       FROM FA_DEPRECIATION d JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
       JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
       WHERE d.site_id=p_site AND d.period=p_period AND c.accum_dep_account IS NOT NULL
       GROUP BY c.accum_dep_account, c.category_name;
     IF (SELECT COALESCE(SUM(amt),0) FROM cred)=0 THEN RETURN END IF;
     INSERT INTO gl_journal (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
     SELECT v_vou,1,p_site,p_period,'FA','412-066',SUM(amt),0,SUM(amt),0,'IDR',1,'N',v_vou,'D',
            'Beban Penyusutan Aktiva Tetap '||CAST(MONTH(p_period) AS varchar(2))||'/'||CAST(YEAR(p_period) AS varchar(4)) FROM cred;
     INSERT INTO gl_journal (voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
     SELECT v_vou,1+(SELECT COUNT(*) FROM cred c2 WHERE c2.acc<=cr.acc),p_site,p_period,'FA',cr.acc,0,cr.amt,0,cr.amt,'IDR',1,'N',v_vou,'K','Akum. Peny. '||cr.catname FROM cred cr;
     UPDATE FA_DEPRECIATION SET posting_status='P', journal_no=v_vou WHERE site_id=p_site AND period=p_period;
     DELETE FROM FA_PERIOD WHERE site_id=p_site AND period=p_period;
     INSERT INTO FA_PERIOD (site_id,period,status,journal_no,total_depr,generate_date,generate_by,post_date,post_by)
     SELECT p_site,p_period,'P',v_vou,SUM(amt),CURRENT TIMESTAMP,CURRENT USER,CURRENT TIMESTAMP,CURRENT USER FROM cred;
   END;
   COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RESIGNAL;
END;

IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_regenerate_period') THEN DROP PROCEDURE sp_fa_regenerate_period END IF;
CREATE PROCEDURE sp_fa_regenerate_period(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   UPDATE FA_PERIOD SET status='O' WHERE site_id=p_site AND period=p_period AND status='P';
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period;
   CALL sp_fa_generate_sl(p_period,p_site);
   CALL sp_fa_post_period(p_period,p_site);
END;
