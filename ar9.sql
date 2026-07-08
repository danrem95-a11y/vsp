SELECT t1.voucher_manual, MAX(t1.tgl) AS tgl, MAX(t2.bukti_id) AS contoh_faktur,
       CAST(SUM(ISNULL(t2.nilai_bayar_idr,0)) AS NUMERIC(18,2)) AS tbyr_amt,
       MAX(t1.kas_id) AS kas_id, MAX(ISNULL(t1.giro_id,'')) AS giro_id
FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher
WHERE t1.flag_bayar IN (1,2) AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL)
  AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30'
  AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id)
  AND NOT EXISTS (SELECT 1 FROM gl_journal gj WHERE gj.account_id='103-001' AND gj.modul_id='CI' AND gj.voucher_manual=t1.voucher_manual)
GROUP BY t1.voucher_manual
ORDER BY tbyr_amt DESC
