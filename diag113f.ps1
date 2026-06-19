$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$out=@()
$out += "=== CO vouchers with >=2 free rows (kas_id=0/null, empty refs) ==="
$cmd.CommandText = @"
SELECT COUNT(*) FROM (
  SELECT voucher_manual FROM gl_journal
  WHERE modul_id='CO' AND ISNULL(kas_id,0)=0 AND ISNULL(doc_reff,'')='' AND ISNULL(order_reff,'')=''
  GROUP BY voucher_manual HAVING COUNT(*) >= 2
) x
"@
$out += "count: " + $cmd.ExecuteScalar()
$out += ""
$out += "=== distinct accounts used on free rows (top usage) ==="
$cmd.CommandText = @"
SELECT TOP 15 account_id, COUNT(*) FROM gl_journal
WHERE modul_id='CO' AND ISNULL(kas_id,0)=0 AND ISNULL(doc_reff,'')='' AND ISNULL(order_reff,'')=''
GROUP BY account_id ORDER BY COUNT(*) DESC
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "$($r[0])  n=$($r[1])" }; $r.Close()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag113f_out.txt -Encoding UTF8
