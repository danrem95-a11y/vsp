select USERID, USERNAME, ISACTIVE, ISGROUP, USERGROUP, USERPWD,
       case when USERPWD='w1r4s' then 'COCOK w1r4s' else 'BEDA' end as cek_w1r4s
from SYS_USER
where lower(USERID)='super' or lower(USERNAME)='super'
