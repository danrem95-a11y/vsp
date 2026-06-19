SELECT 'tbyr1_ap' AS src, t1.kas_id,
  COUNT(DISTINCT t1.voucher) AS vouchers,
  SUM(COALESCE(t2.nilai_bayar_idr,0)) AS total_bayar
FROM tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher=t1.voucher
WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND t1.flag_bayar = 2
GROUP BY t1.kas_id
UNION ALL
SELECT 'gl_CO_kredit', g.kas_id,
  COUNT(DISTINCT g.voucher_manual) AS vouchers,
  SUM(COALESCE(g.kredit,0)) AS total_kredit
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.modul_id = 'CO' AND g.kas_id > 0 AND g.kredit > 0
GROUP BY g.kas_id
ORDER BY kas_id, src;
