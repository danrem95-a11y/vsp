SELECT 'MEMO_remaining' lbl, CAST(count(*) AS varchar(30)) val FROM gl_journal WHERE voucher IN ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018')
UNION ALL SELECT 'FA_vouchers', CAST(count(distinct voucher) AS varchar(30)) FROM gl_journal WHERE voucher LIKE 'FA1012026%';
SELECT voucher, CAST(sum(debet) AS numeric(18,2)) dr, CAST(sum(kredit) AS numeric(18,2)) kr, CAST(sum(debet)-sum(kredit) AS numeric(18,2)) bal FROM gl_journal WHERE voucher LIKE 'FA1012026%' GROUP BY voucher ORDER BY voucher;
