$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
foreach($tbl in 'TBYR1','TBYR2'){
  $out += "=== $tbl columns ==="
  $cmd.CommandText = "SELECT c.column_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_name='$tbl' ORDER BY c.column_id"
  $r=$cmd.ExecuteReader(); $cols=@(); while($r.Read()){ $cols += $r[0].ToString() }; $r.Close()
  $out += ($cols -join ', ')
}
$out += ""
$out += "=== tbyr1 full row for case (correct voucher) ==="
$cmd.CommandText = "SELECT * FROM tbyr1 WHERE voucher='1010420260004'"
$r=$cmd.ExecuteReader(); $n=$r.FieldCount
while($r.Read()){ for($i=0;$i -lt $n;$i++){ $v=$r[$i]; if("$v" -ne '' -and "$v" -ne '0'){ $out += "$($r.GetName($i)) = $v" } } }
$r.Close()
$out += ""
$out += "=== tbyr2 full row for case ==="
$cmd.CommandText = "SELECT * FROM tbyr2 WHERE voucher='1010420260004'"
$r=$cmd.ExecuteReader(); $n=$r.FieldCount
while($r.Read()){ for($i=0;$i -lt $n;$i++){ $v=$r[$i]; if("$v" -ne '' -and "$v" -ne '0'){ $out += "$($r.GetName($i)) = $v" } } }
$r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag113d_out.txt -Encoding UTF8
