$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
# tables that have an account_id column
$cmd.CommandText="SELECT t.table_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_type='BASE' AND c.column_name='account_id' ORDER BY t.table_name"
$r=$cmd.ExecuteReader(); $t=@(); while($r.Read()){ $t+=$r[0] }; $r.Close()
"TABLES with account_id: " + ($t -join ", ")
# the COA master = the one where account_id is (near) unique and has a name col. Try each for 102-601 single row + show name-ish cols
foreach($tb in $t){
  try{ $cmd.CommandText="SELECT COUNT(*) FROM $tb"; $n=$cmd.ExecuteScalar()
       $cmd.CommandText="SELECT COUNT(*) FROM $tb WHERE account_id='102-601'"; $n6=$cmd.ExecuteScalar()
       "{0,-22} rows={1} has102601={2}" -f $tb,$n,$n6
  } catch { "{0,-22} ERR {1}" -f $tb,$_.Exception.Message }
}
$conn.Close()
