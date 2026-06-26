SELECT 'FA_ASSET' o, CAST(count(*) AS varchar(12)) n FROM FA_ASSET WHERE site_id='101'
UNION ALL SELECT 'FA_DEPRECIATION posted', CAST(count(*) AS varchar(12)) FROM FA_DEPRECIATION WHERE site_id='101' AND posting_status='P'
UNION ALL SELECT 'GL FA vouchers', CAST(count(distinct voucher) AS varchar(12)) FROM gl_journal WHERE voucher LIKE 'FA1012026%'
UNION ALL SELECT 'FA_GL_LINK', CAST(count(*) AS varchar(12)) FROM FA_GL_LINK
UNION ALL SELECT 'FA procs', CAST(count(*) AS varchar(12)) FROM SYS.SYSPROCEDURE WHERE proc_name LIKE 'sp_fa_%'
UNION ALL SELECT 'recon views', CAST(count(*) AS varchar(12)) FROM SYS.SYSTABLE WHERE table_name LIKE 'v_fa_recon%'
UNION ALL SELECT 'menu items', CAST(count(*) AS varchar(12)) FROM sysleftmenu WHERE groupid='62';
