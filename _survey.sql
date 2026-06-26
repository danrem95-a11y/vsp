SELECT db_name() dbname, property('ProductVersion') ver;
SELECT 'FA tables' lbl, table_name FROM systable WHERE table_name LIKE 'FA[_]%' OR table_name LIKE 'fa[_]%' ORDER BY table_name;
