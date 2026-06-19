$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp")
$conn.Open()
$cmd = $conn.CreateCommand()
# Find a GL journal for AP payment that has 3+ rows (likely includes selisih kurs)
$cmd.CommandText = @"
SELECT voucher_manual, account_id, debet, kredit, doc_reff, order_reff, kas_id, ket
FROM gl_journal
WHERE modul_id = 'CO'
  AND voucher_manual IN (
    SELECT voucher_manual FROM gl_journal 
    WHERE modul_id = 'CO' AND kas_id > 0
    GROUP BY voucher_manual HAVING COUNT(*) >= 3
  )
  AND voucher_manual IN (
    SELECT voucher_manual FROM gl_journal 
    WHERE modul_id = 'CO' AND isnull(doc_reff,'') = '' AND isnull(order_reff,'') = '' AND kas_id = 0
  )
ORDER BY voucher_manual, urut
"@
$rd = $cmd.ExecuteReader()
$rows = 0
while($rd.Read() -and $rows -lt 20){
    Write-Host "$($rd['voucher_manual']) | $($rd['account_id']) | D:$($rd['debet']) | K:$($rd['kredit']) | doc:$($rd['doc_reff']) | ord:$($rd['order_reff']) | kas:$($rd['kas_id']) | $($rd['ket'])"
    $rows++
}
$conn.Close()
