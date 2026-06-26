SELECT 'FA_COA_count' lbl, CAST(count(*) AS varchar(50)) val FROM gl_acc WHERE AccountCode IN ('151-001','151-100','153-001','154-001','155-001','158-001','158-101','158-201','158-301')
UNION ALL SELECT 'FA_vouchers_existing', CAST(count(*) AS varchar(50)) FROM gl_journal WHERE voucher LIKE 'FA1012026%'
UNION ALL SELECT 'gl_setup_period', CAST(periode AS varchar(50)) FROM gl_setup
UNION ALL SELECT 'MEMO:'||voucher, CAST(count(*) AS varchar(50)) FROM gl_journal WHERE voucher IN ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018') GROUP BY voucher;
