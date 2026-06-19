select top 5 column_name, data_type, width 
from sys.syscolumn 
where table_name = 'tbyr1'
order by column_id
