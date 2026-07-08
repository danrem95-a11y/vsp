SELECT d.voucher, d.voucher_manual, d.cust_id, d.account_id, d.tgl,
       CAST(SUM(d.debet) AS NUMERIC(18,2)) AS debet, CAST(SUM(d.kredit) AS NUMERIC(18,2)) AS kredit, COUNT(*) n
FROM tdp d
WHERE (d.voucher_manual LIKE '%DPR%' OR d.voucher_manual LIKE '%DPB%' OR d.voucher LIKE '%DPR%' OR d.voucher LIKE '%DPB%')
  AND d.tgl BETWEEN '2026-01-01' AND '2026-04-30'
GROUP BY d.voucher, d.voucher_manual, d.cust_id, d.account_id, d.tgl
ORDER BY d.tgl
