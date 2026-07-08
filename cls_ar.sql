SELECT y.klas, COUNT(*) AS n_voucher,
       CAST(SUM(y.tb_amt) AS NUMERIC(18,2)) AS tbyr,
       CAST(SUM(y.ci_ytd) AS NUMERIC(18,2)) AS ci_ytd,
       CAST(SUM(y.tb_amt - y.ci_ytd) AS NUMERIC(18,2)) AS gap
FROM (
  SELECT x.vm, x.tb_amt, ISNULL(x.ci_ytd,0) AS ci_ytd, ISNULL(x.ci_all,0) AS ci_all,
    CASE WHEN ABS(x.tb_amt - ISNULL(x.ci_ytd,0)) <= 1 THEN 'MATCH'
         WHEN ISNULL(x.ci_all,0) = 0                  THEN 'NO_GL_CI'
         WHEN ISNULL(x.ci_ytd,0) = 0 AND ISNULL(x.ci_all,0) > 0 THEN 'PERIOD_SHIFT'
         ELSE 'AMOUNT_DIFF' END AS klas
  FROM (
    SELECT t1.voucher_manual AS vm,
           SUM(ISNULL(t2.nilai_bayar_idr,0)) AS tb_amt,
           (SELECT SUM(gj.kredit) FROM gl_journal gj
            WHERE gj.account_id='103-001' AND gj.modul_id='CI'
              AND gj.voucher_manual=t1.voucher_manual
              AND gj.tgl <= '2026-04-30') AS ci_ytd,
           (SELECT SUM(gj.kredit) FROM gl_journal gj
            WHERE gj.account_id='103-001' AND gj.modul_id='CI'
              AND gj.voucher_manual=t1.voucher_manual) AS ci_all
    FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher
    WHERE t1.flag_bayar IN (1,2) AND (t1.flag_vendor=1 OR t1.flag_vendor IS NULL)
      AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30'
      AND EXISTS (SELECT 1 FROM ar_trans a WHERE a.order_client=t2.bukti_id)
    GROUP BY t1.voucher_manual
  ) x
) y
GROUP BY y.klas
ORDER BY y.klas
