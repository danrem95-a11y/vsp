SELECT t.table_name, c.column_name FROM SYS.SYSCOLUMN c JOIN SYS.SYSTABLE t ON c.table_id=t.table_id WHERE t.table_name IN ('gl_acc','gl_balance') ORDER BY t.table_name, c.column_name;
