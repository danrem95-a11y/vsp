$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }
Q "neraca2014 102-601" "SELECT * FROM neraca2014 WHERE account_id='102-601'"
Q "gl_report_detail 102-601" "SELECT * FROM gl_report_detail WHERE account_id='102-601'"
# search any table with a column 'nama' that also has account-code col matching 102-601
$cmd.CommandText="SELECT t.table_name, c.column_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_type='BASE' AND (c.column_name IN ('nama','nama_account','account_name','keterangan','nm_account','description')) ORDER BY t.table_name"
$r=$cmd.ExecuteReader(); $cand=@(); while($r.Read()){ $cand+=,@($r[0],$r[1]) }; $r.Close()
$out+=""; $out+="=== tables with name-col ==="; $cand | ForEach-Object { $out+= ($_[0]+" . "+$_[1]) }
# COA master likely 'mperkiraan' style: list base tables with both account-ish PK and 'nama'
foreach($pair in $cand){ $tb=$pair[0]; $col=$pair[1]
  foreach($keycol in @('account_id','kode','no_account','account','perkiraan','kode_account','no_akun','akun')){
    try{ $cmd.CommandText="SELECT FIRST $keycol, $col FROM $tb WHERE $keycol='102-601'"; $r=$cmd.ExecuteReader()
      if($r.Read()){ $out+= "FOUND name: $tb($keycol=$($r[0])) -> $col = $($r[1])" }; $r.Close() } catch {}
  }
}
$conn.Close()
($out -join "`r`n")
