SELECT g.voucher, g.voucher_manual, g.tgl, g.account_id, g.kas_id,
  SUM(COALESCE(g.kredit,0)) AS kredit_bank,
  SUM(COALESCE(g.debet,0)) AS debet_bank
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.modul_id = 'CO'
  AND g.kas_id > 0
  AND NOT EXISTS (
    SELECT 1 FROM tbyr1 t1
    WHERE t1.voucher_manual = g.voucher_manual
  )
GROUP BY g.voucher, g.voucher_manual, g.tgl, g.account_id, g.kas_id
ORDER BY g.tgl, g.voucher_manual;
