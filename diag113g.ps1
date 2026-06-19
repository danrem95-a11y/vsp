$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 240
$out=@()
$out += "=== AP payment vouchers (join tbyr1 flag_bayar=2) with >=2 free GL rows ==="
$cmd.CommandText = @"
SELECT COUNT(*) FROM (
  SELECT g.voucher_manual
  FROM gl_journal g
  JOIN (SELECT DISTINCT voucher_manual FROM tbyr1 WHERE flag_bayar=2) t
    ON t.voucher_manual = g.voucher_manual
  WHERE g.modul_id='CO' AND ISNULL(g.kas_id,0)=0
    AND ISNULL(g.doc_reff,'')='' AND ISNULL(g.order_reff,'')=''
  GROUP BY g.voucher_manual HAVING COUNT(*) >= 2
) x
"@
$out += "count: " + $cmd.ExecuteScalar()
$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag113g_out.txt -Encoding UTF8
