SELECT c.column_name FROM SYS.SYSCOLUMN c JOIN SYS.SYSTABLE t ON c.table_id=t.table_id WHERE t.table_name='gl_journal' ORDER BY c.column_name;
