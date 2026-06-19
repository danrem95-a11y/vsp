OUTPUT TO 'C:\BTV\debug\fa_disco01_tables_out.txt' FORMAT TEXT;
SELECT table_name, count(*) AS ncols
FROM SYS.SYSTABLE t
  JOIN SYS.SYSCOLUMN c ON c.table_id = t.table_id
WHERE t.table_type = 'BASE'
  AND t.creator = (SELECT user_id FROM SYS.SYSUSERPERM WHERE user_name = 'DBA')
GROUP BY table_name
ORDER BY table_name;
