SELECT y.klas, COUNT(*) AS n_voucher,
       CAST(SUM(y.tb_amt) AS NUMERIC(18,2)) AS tbyr,
       CAST(SUM(y.co_ytd) AS NUMERIC(18,2)) AS co_ytd,
       CAST(SUM(y.tb_amt - y.co_ytd) AS NUMERIC(18,2)) AS gap
FROM (
  SELECT x.vm, x.tb_amt, ISNULL(x.co_ytd,0) AS co_ytd, ISNULL(x.co_all,0) AS co_all,
    CASE WHEN ABS(x.tb_amt - ISNULL(x.co_ytd,0)) <= 1 THEN 'MATCH'
         WHEN ISNULL(x.co_all,0) = 0                  THEN 'NO_GL_CO'
         WHEN ISNULL(x.co_ytd,0) = 0 AND ISNULL(x.co_all,0) > 0 THEN 'PERIOD_SHIFT'
         ELSE 'AMOUNT_DIFF' END AS klas
  FROM (
    SELECT t1.voucher_manual AS vm,
           SUM(ISNULL(t2.nilai_bayar_idr,0)) AS tb_amt,
           (SELECT SUM(gj.debet) FROM gl_journal gj
            WHERE gj.account_id IN ('226-001','226-006') AND gj.modul_id='CO'
              AND gj.voucher_manual=t1.voucher_manual AND gj.tgl <= '2026-04-30') AS co_ytd,
           (SELECT SUM(gj.debet) FROM gl_journal gj
            WHERE gj.account_id IN ('226-001','226-006') AND gj.modul_id='CO'
              AND gj.voucher_manual=t1.voucher_manual) AS co_all
    FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher
    WHERE t1.flag_bayar IN (1,2)
      AND t1.tgl BETWEEN '2026-01-01' AND '2026-04-30'
      AND EXISTS (SELECT 1 FROM ap_trans p WHERE p.order_client=t2.bukti_id
                    AND EXISTS(SELECT 1 FROM gl_journal g3 WHERE g3.voucher=p.order_client AND g3.kredit>0 AND g3.account_id IN ('226-001','226-006')))
    GROUP BY t1.voucher_manual
  ) x
) y
GROUP BY y.klas
ORDER BY y.klas
