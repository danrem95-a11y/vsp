$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
$cmd.CommandText = "SELECT t.table_name, c.column_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE LOWER(c.column_name) LIKE '%selisih%' OR LOWER(c.column_name) LIKE '%acc_sel%' OR LOWER(c.column_name) LIKE '%kurs%' AND t.table_type='BASE'"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "$($r[0]).$($r[1])" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag113b_out.txt -Encoding UTF8
