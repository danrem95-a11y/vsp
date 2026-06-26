$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand(); $cmd.CommandTimeout = 180
$out = @()
function Q($title,$sql){
  $script:out += ""; $script:out += "=== $title ==="
  try {
    $cmd.CommandText = $sql
    $r = $cmd.ExecuteReader()
    while($r.Read()){ $v=@(); for($i=0;$i -lt $r.FieldCount;$i++){ $v += "$($r.GetName($i))=$($r[$i])" }; $script:out += ($v -join ' | ') }
    $r.Close()
  } catch { $script:out += "ERR: $($_.Exception.Message)" }
}

$mains = "'10126040500001','10126040500002'"

Q "ap_trans MAIN docs (SELECT *)" "SELECT * FROM ap_trans WHERE order_client IN ($mains)"
Q "ap_trans CHILD docs (order_reff = main)" "SELECT * FROM ap_trans WHERE order_reff IN ($mains)"

Q "GL journal for MAIN + CHILD (by doc_reff)" @"
SELECT doc_reff, urut, modul_id, account_id, debet, kredit, curr_id, rate_rp, ket, voucher, voucher_manual, tgl
FROM gl_journal
WHERE doc_reff IN ($mains)
   OR doc_reff IN (SELECT order_client FROM ap_trans WHERE order_reff IN ($mains))
ORDER BY doc_reff, modul_id, urut
"@

Q "GL summary per doc_reff/modul (balance check)" @"
SELECT doc_reff, modul_id, SUM(debet) dr, SUM(kredit) cr, COUNT(*) n
FROM gl_journal
WHERE doc_reff IN ($mains)
   OR doc_reff IN (SELECT order_client FROM ap_trans WHERE order_reff IN ($mains))
GROUP BY doc_reff, modul_id ORDER BY doc_reff, modul_id
"@

Q "ALL GL lines hitting 102-601 (any module) - detail" @"
SELECT modul_id, doc_reff, urut, account_id, debet, kredit, tgl, ket
FROM gl_journal WHERE account_id='102-601' ORDER BY tgl, doc_reff, urut
"@

Q "102-601 GRAND total (whole ledger)" "SELECT SUM(debet) total_debet, SUM(kredit) total_kredit, SUM(debet)-SUM(kredit) saldo FROM gl_journal WHERE account_id='102-601'"

Q "102-601 by module" "SELECT modul_id, SUM(debet) dr, SUM(kredit) cr, COUNT(*) n FROM gl_journal WHERE account_id='102-601' GROUP BY modul_id ORDER BY modul_id"

Q "Vendor master 4SL.S045 / 4SL.L010" "SELECT * FROM supplier WHERE supplier_id IN ('4SL.S045','4SL.L010')"

$conn.Close()
$txt = $out -join "`r`n"
$txt | Set-Content c:\BTV\debug\diag118_import_probe_out.txt -Encoding UTF8
Write-Output $txt
