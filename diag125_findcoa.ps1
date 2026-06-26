$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
$cmd.CommandText="SELECT table_name FROM systable WHERE table_type='BASE' AND (table_name LIKE '%account%' OR table_name LIKE '%perkiraan%' OR table_name LIKE '%coa%' OR table_name LIKE '%rekening%' OR table_name LIKE '%chart%') ORDER BY table_name"
$r=$cmd.ExecuteReader(); $t=@(); while($r.Read()){ $t+=$r[0] }; $r.Close()
"CANDIDATE TABLES: " + ($t -join ", ")
foreach($tb in $t){
  try{ $cmd.CommandText="SELECT FIRST * FROM $tb WHERE account_id='102-601'"; $r=$cmd.ExecuteReader()
    if($r.Read()){ ""; "--- $tb berisi 102-601 ---"; for($i=0;$i -lt $r.FieldCount;$i++){ "  {0} = {1}" -f $r.GetName($i),$r[$i] } }
    $r.Close() } catch { "  ($tb : $($_.Exception.Message))" }
}
$conn.Close()
