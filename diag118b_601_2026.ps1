$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd = $conn.CreateCommand(); $cmd.CommandTimeout = 180
$out = @()
function Q($title,$sql){
  $script:out += ""; $script:out += "=== $title ==="
  try { $cmd.CommandText=$sql; $r=$cmd.ExecuteReader()
    while($r.Read()){ $v=@(); for($i=0;$i -lt $r.FieldCount;$i++){ $v += "$($r.GetName($i))=$($r[$i])" }; $script:out += ($v -join ' | ') }
    $r.Close() } catch { $script:out += "ERR: $($_.Exception.Message)" }
}

Q "102-601 ALL lines tgl>=2026-01-01 (every module)" @"
SELECT tgl, modul_id, doc_reff, urut, debet, kredit, ket
FROM gl_journal WHERE account_id='102-601' AND tgl >= '2026-01-01'
ORDER BY tgl, modul_id, doc_reff, urut
"@

Q "102-601 per-year balance (Dr/Cr/net)" @"
SELECT YEAR(tgl) thn, SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) net
FROM gl_journal WHERE account_id='102-601' GROUP BY YEAR(tgl) ORDER BY thn
"@

Q "102-601 2026 net by module" @"
SELECT modul_id, SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) net, COUNT(*) n
FROM gl_journal WHERE account_id='102-601' AND tgl >= '2026-01-01' GROUP BY modul_id
"@

$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag118b_601_2026_out.txt -Encoding UTF8
Write-Output ($out -join "`r`n")
