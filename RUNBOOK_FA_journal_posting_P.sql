-- =====================================================================
-- Jurnal penyusutan FA saat GENERATE -> posting='P' (langsung terposting, bukan draft 'N').
-- Tetap: setiap generate DELETE dulu voucher FA lalu INSERT (jurnal FA selalu bersih).
-- Hanya mengubah flag posting 'N'->'P' di sp_fa_post_period; logika lain sama persis.
-- Jalankan di dbisql (aplikasi ditutup).
-- =====================================================================

IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_post_period')
   THEN DROP PROCEDURE sp_fa_post_period END IF;
CREATE PROCEDURE sp_fa_post_period(IN p_period timestamp, IN p_site varchar(4))
BEGIN
  DECLARE v_vou varchar(15);
  SET v_vou='FA' || p_site || CAST(YEAR(p_period) AS varchar(4)) || RIGHT('0' || CAST(MONTH(p_period) AS varchar(2)),2);
  IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status='C') THEN
    RAISERROR 17002 'Periode closed - tidak bisa posting';
  END IF;
  -- DELETE dulu: jurnal FA voucher ini dibersihkan sebelum insert ulang (anti-dobel)
  DELETE FROM gl_journal WHERE site_id=p_site AND voucher=v_vou AND modul_id='FA';
  BEGIN
    DECLARE LOCAL TEMPORARY TABLE cred(acc varchar(15) NULL, amt decimal(18,2) NULL, catname varchar(50) NULL) NOT TRANSACTIONAL;
    INSERT INTO cred SELECT c.accum_dep_account, ROUND(SUM(d.depreciation_amount),0), c.category_name
      FROM FA_DEPRECIATION AS d JOIN FA_ASSET AS a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
      JOIN FA_CATEGORY AS c ON c.site_id=a.site_id AND c.category_code=a.category_code
      WHERE d.site_id=p_site AND d.period=p_period AND c.accum_dep_account IS NOT NULL
      GROUP BY c.accum_dep_account, c.category_name;
    IF (SELECT COALESCE(SUM(amt),0) FROM cred)=0 THEN RETURN END IF;
    -- Dr Beban Penyusutan 412-066  (posting='P')
    INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
      SELECT v_vou,1,p_site,p_period,'FA','412-066',SUM(amt),0,SUM(amt),0,'IDR',1,'P',v_vou,'D',
             'Beban Penyusutan Aktiva Tetap ' || CAST(MONTH(p_period) AS varchar(2)) || '/' || CAST(YEAR(p_period) AS varchar(4)) FROM cred;
    -- Cr Akum. Penyusutan 158-xxx per golongan  (posting='P')
    INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
      SELECT v_vou,1+(SELECT COUNT(*) FROM cred AS c2 WHERE c2.acc<=cr.acc),p_site,p_period,'FA',cr.acc,0,cr.amt,0,cr.amt,'IDR',1,'P',v_vou,'K',
             'Akum. Peny. ' || cr.catname FROM cred AS cr;
    UPDATE FA_DEPRECIATION SET posting_status='P', journal_no=v_vou WHERE site_id=p_site AND period=p_period;
    DELETE FROM FA_PERIOD WHERE site_id=p_site AND period=p_period;
    INSERT INTO FA_PERIOD(site_id,period,status,journal_no,total_depr,generate_date,generate_by,post_date,post_by)
      SELECT p_site,p_period,'P',v_vou,SUM(amt),CURRENT TIMESTAMP,CURRENT USER,CURRENT TIMESTAMP,CURRENT USER FROM cred;
  END;
  COMMIT WORK;
EXCEPTION WHEN OTHERS THEN ROLLBACK WORK; RESIGNAL;
END;

-- Posting jurnal FA penyusutan yg SUDAH terbentuk (Jan-Jul 2026) dari 'N' -> 'P'
UPDATE gl_journal SET posting='P'
 WHERE site_id='101' AND modul_id='FA' AND voucher LIKE 'FA101202%' AND posting='N';
COMMIT;

-- =========================== VERIFIKASI =============================
-- Semua jurnal penyusutan FA harus posting='P':
SELECT voucher, posting, COUNT(*) n, SUM(debet) dr, SUM(kredit) kr
  FROM gl_journal WHERE site_id='101' AND modul_id='FA' AND voucher LIKE 'FA101202%'
 GROUP BY voucher, posting ORDER BY voucher;
-- Harapan: semua posting='P', Dr=Kr per voucher.

-- CATATAN: jurnal DISPOSAL (sp_fa_dispose, voucher DSP...) juga masih posting='N'.
--   Kalau ingin ikut auto-post 'P', ubah 'N'->'P' di sp_fa_dispose juga (beritahu bila perlu).
