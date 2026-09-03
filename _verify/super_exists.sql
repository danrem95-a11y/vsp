select USERID, USERNAME, ISACTIVE, ISGROUP, USERGROUP, department_id
from SYS_USER
where lower(USERID)='super' or lower(USERNAME)='super'
