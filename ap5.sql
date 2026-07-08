SELECT t1.voucher_manual, MAX(t1.tgl) AS tgl, CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2)) AS tbyr_amt
FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher
WHERE t1.flag_bayar IN (1,2) AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30'
  AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id AND EXISTS(SELECT 1 FROM gl_journal g3 WHERE g3.voucher=p.order_client AND g3.kredit>0 AND g3.account_id IN ('226-001','226-006')))
  AND NOT EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.account_id IN ('226-001','226-006') AND gj.modul_id='CO' AND gj.voucher_manual=t1.voucher_manual)
GROUP BY t1.voucher_manual ORDER BY tbyr_amt DESC
