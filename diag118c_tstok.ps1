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
$mains = "'10126040500001','10126040500002'"

Q "tstok2 allocation (biaya_ekspedisi) per main" @"
SELECT bukti_id, COUNT(*) n, SUM(biaya_ekspedisi*qty) sum_byk, SUM(ABS(biaya_ekspedisi*qty)) sum_abs, SUM(netto) sum_netto
FROM tstok2 WHERE bukti_id IN ($mains) GROUP BY bukti_id
"@

Q "Compare: ap_trans header vs GL persediaan(102-101) vs tstok2 alloc" @"
SELECT a.order_client,
  a.ttl_kotor ap_kotor, a.ttl_netto ap_netto, a.ttl_ppn ap_ppn,
  (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2_alloc,
  (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id='102-101') gl_persediaan_dr,
  (SELECT SUM(kredit) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id='226-006') gl_hutang_cr
FROM ap_trans a WHERE a.order_client IN ($mains)
"@

$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag118c_tstok_out.txt -Encoding UTF8
Write-Output ($out -join "`r`n")
