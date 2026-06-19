$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
$out += "=== Tables with name like kas ==="
$cmd.CommandText = "SELECT table_name FROM systable WHERE LOWER(table_name) LIKE '%kas%' AND table_type='BASE'"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += $r[0].ToString() }; $r.Close()
$out += ""
$out += "=== gl_journal rows with voucher = GL_REFF 200410126040346 ==="
$cmd.CommandText = "SELECT voucher, voucher_manual, urut, account_id, debet, kredit, kas_id, modul_id, ket FROM gl_journal WHERE voucher='200410126040346'"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "v=$($r[0]) vm=$($r[1]) urut=$($r[2]) acc=$($r[3]) Dr=$($r[4]) Cr=$($r[5]) kas=$($r[6]) mod=$($r[7]) ket=[$($r[8])]" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag113e_out.txt -Encoding UTF8
