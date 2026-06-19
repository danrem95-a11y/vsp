$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
$out += "=== Tabel dgn nama mengandung EKSP/FREIGHT/TK ==="
$cmd.CommandText = "SELECT table_name FROM systable WHERE table_type='BASE' AND (LOWER(table_name) LIKE '%eksp%' OR LOWER(table_name) LIKE '%freight%' OR LOWER(table_name) LIKE '%biaya%')"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += $r[0].ToString() }; $r.Close()
$out += ""
$out += "=== Kolom bernama biaya_ekspedisi / freight di tabel mana saja ==="
$cmd.CommandText = "SELECT t.table_name, c.column_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_type='BASE' AND (LOWER(c.column_name) LIKE '%ekspedisi%' OR LOWER(c.column_name) LIKE '%freight%')"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "$($r[0]).$($r[1])" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116f_out.txt -Encoding UTF8
