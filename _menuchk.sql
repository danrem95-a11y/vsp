SELECT t.table_name, c.column_name FROM SYS.SYSCOLUMN c JOIN SYS.SYSTABLE t ON c.table_id=t.table_id
WHERE t.table_name IN ('sysleftmenu','sysgroupleftmenu') ORDER BY t.table_name, c.column_name;
