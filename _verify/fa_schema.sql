select c.column_name, c.nulls, c."default"
from syscolumn c join systable t on t.table_id=c.table_id
where t.table_name='FA_ASSET'
order by c.column_id
