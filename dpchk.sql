SELECT gj.voucher_manual, gj.account_id, ga.AccountDes, gj.modul_id,
       CAST(SUM(gj.debet) AS NUMERIC(18,2)) AS debet, CAST(SUM(gj.kredit) AS NUMERIC(18,2)) AS kredit, COUNT(*) n
FROM gl_journal gj
LEFT JOIN gl_acc ga ON ga.AccountCode = gj.account_id
WHERE gj.voucher_manual IN ('2605DPR002','2603DPR002','2602DPR003','2601DPR001','2602DPR002')
  AND gj.posting='P'
GROUP BY gj.voucher_manual, gj.account_id, ga.AccountDes, gj.modul_id
ORDER BY gj.voucher_manual, gj.account_id
