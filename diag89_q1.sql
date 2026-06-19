-- Q1: Bank by account_id and modul_id
SELECT g.account_id, g.modul_id,
       COUNT(*) AS rows,
       SUM(g.debet) AS tot_dbt, SUM(g.kredit) AS tot_krd,
       SUM(g.debet-g.kredit) AS net
FROM gl_journal g
WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'
  AND g.kas_id > 0
GROUP BY g.account_id, g.modul_id
ORDER BY g.account_id, g.modul_id;
