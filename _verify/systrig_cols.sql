select c.column_name
from syscolumn c join systable t on t.table_id=c.table_id
where t.table_name='SYSTRIGGER'
  and (c.column_name like '%name%' or c.column_name like '%trig%')
order by c.column_name;
