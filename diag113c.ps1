$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
$out += "=== TBYR3 columns ==="
$cmd.CommandText = "SELECT c.column_name, c.domain_id FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_name='TBYR3' ORDER BY c.column_id"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "$($r[0])" }; $r.Close()
$out += ""
$out += "=== TBYR3 rows for case vouchers ==="
$cmd.CommandText = "SELECT * FROM tbyr3 WHERE voucher IN ('1010420260004','25102004P179P','26042004P050','25102004P179')"
$r=$cmd.ExecuteReader()
$n=$r.FieldCount
while($r.Read()){ $vals=@(); for($i=0;$i -lt $n;$i++){ $vals += "$($r.GetName($i))=$($r[$i])" }; $out += ($vals -join ' | ') }
$r.Close()
$out += ""
$out += "=== TBYR3 row count total ==="
$cmd.CommandText = "SELECT COUNT(*) FROM tbyr3"
$out += $cmd.ExecuteScalar().ToString()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag113c_out.txt -Encoding UTF8
