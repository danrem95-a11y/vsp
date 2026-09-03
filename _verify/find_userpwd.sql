select t.table_name, c.column_name
from systable t join syscolumn c on c.table_id=t.table_id
where t.table_type='BASE'
  and (upper(c.column_name) like '%PASS%' or upper(c.column_name) like '%PWD%'
       or upper(c.column_name) like '%SANDI%' or upper(c.column_name) like '%KATA%')
order by t.table_name, c.column_name
