SELECT 'MEMO_remaining (harus 0)' lbl, CAST(count(*) AS varchar(30)) val FROM gl_journal WHERE voucher IN ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018')
UNION ALL SELECT 'FA JanApr Dr (harus 224.183.901)', CAST(CAST(sum(debet) AS numeric(18,0)) AS varchar(30)) FROM gl_journal WHERE voucher IN ('FA101202601','FA101202602','FA101202603','FA101202604') AND account_id='412-066'
UNION ALL SELECT 'FA MeiJun Dr (beban baru)', CAST(CAST(sum(debet) AS numeric(18,0)) AS varchar(30)) FROM gl_journal WHERE voucher IN ('FA101202605','FA101202606') AND account_id='412-066'
UNION ALL SELECT 'FA JanJun total Dr', CAST(CAST(sum(debet) AS numeric(18,0)) AS varchar(30)) FROM gl_journal WHERE voucher LIKE 'FA1012026%' AND account_id='412-066'
UNION ALL SELECT 'FA_DEPRECIATION posted', CAST(count(*) AS varchar(30)) FROM FA_DEPRECIATION WHERE site_id='101' AND posting_status='P';
