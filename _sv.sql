SELECT 'FA_COA_present' lbl, count(*) n FROM gl_acc WHERE AccountCode IN ('151-001','151-100','153-001','154-001','155-001','158-001','158-101','158-201','158-301');
SELECT voucher, count(*) baris, CAST(sum(debet) AS numeric(18,2)) dr FROM gl_journal WHERE voucher IN ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018') GROUP BY voucher;
SELECT 'FA_vouchers' lbl, count(*) n FROM gl_journal WHERE voucher LIKE 'FA1012026%';
SELECT periode FROM gl_setup;
SELECT AccountCode, CAST(AmountDebet-AmountCredit AS numeric(18,2)) saldo FROM gl_balance WHERE Period='2026-01-01' AND AccountCode IN ('151-100','158-001','155-001','158-301','153-001','154-001','151-001','158-101','158-201') ORDER BY AccountCode;
