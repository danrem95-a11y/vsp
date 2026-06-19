SELECT t1.voucher, t1.voucher_manual, t1.tgl, t1.kas_id,
  SUM(COALESCE(t2.nilai_bayar_idr,0)) AS total_bayar
FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher
WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.flag_bayar = 2
  AND NOT EXISTS (
    SELECT 1 FROM gl_journal g
    WHERE g.voucher_manual = t1.voucher_manual
      AND g.modul_id = 'CO'
  )
GROUP BY t1.voucher, t1.voucher_manual, t1.tgl, t1.kas_id
ORDER BY t1.tgl;
