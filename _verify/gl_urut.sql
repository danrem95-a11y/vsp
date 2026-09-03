select c.column_name, c.domain_id, d.domain_name
from syscolumn c join systable t on t.table_id=c.table_id
  left join sysdomain d on d.domain_id=c.domain_id
where t.table_name='gl_journal' and c.column_name in ('voucher','urut','ket','account_id','debet','tgl','site_id')
order by c.column_id;
