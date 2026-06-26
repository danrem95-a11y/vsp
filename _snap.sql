SELECT 'FA_CATEGORY' obj, CAST(count(*) AS varchar(12)) n FROM FA_CATEGORY WHERE site_id='101'
UNION ALL SELECT 'FA_ASSET', CAST(count(*) AS varchar(12)) FROM FA_ASSET WHERE site_id='101'
UNION ALL SELECT 'FA_DEPRECIATION', CAST(count(*) AS varchar(12)) FROM FA_DEPRECIATION WHERE site_id='101'
UNION ALL SELECT 'FA_PERIOD(posted)', CAST(count(*) AS varchar(12)) FROM FA_PERIOD WHERE site_id='101' AND status='P'
UNION ALL SELECT 'FA_GL_LINK', CAST(count(*) AS varchar(12)) FROM FA_GL_LINK WHERE site_id='101'
UNION ALL SELECT 'GL FA vouchers', CAST(count(distinct voucher) AS varchar(12)) FROM gl_journal WHERE voucher LIKE 'FA1012026%'
UNION ALL SELECT 'GL FA Dr total', CAST(CAST(sum(debet) AS numeric(18,0)) AS varchar(20)) FROM gl_journal WHERE voucher LIKE 'FA1012026%' AND account_id='412-066'
UNION ALL SELECT 'FA procs', CAST(count(*) AS varchar(12)) FROM SYS.SYSPROCEDURE WHERE proc_name LIKE 'sp_fa_%'
UNION ALL SELECT 'recon views', CAST(count(*) AS varchar(12)) FROM SYS.SYSTABLE WHERE table_name LIKE 'v_fa_recon%';
