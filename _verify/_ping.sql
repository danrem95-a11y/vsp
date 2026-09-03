select db_name() as dbname, current timestamp as now,
 (select count(*) from sinv where periode='2026-02-01') as sinv_jan_rows,
 (select count(*) from sinv where periode='2026-03-01') as sinv_feb_rows
