select table_name,
  (select count(*) from syscolumn c where c.table_id=t.table_id) ncol
from systable t
where t.table_type='BASE'
  and ( upper(table_name) like '%MENU%' or upper(table_name) like '%AKSES%'
     or upper(table_name) like '%ACCESS%' or upper(table_name) like '%HAK%'
     or upper(table_name) like '%RIGHT%' or upper(table_name) like '%ROLE%'
     or upper(table_name) like '%PRIV%' or upper(table_name) like '%FORM%' )
order by table_name;
