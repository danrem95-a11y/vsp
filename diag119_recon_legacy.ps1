$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd = $conn.CreateCommand(); $cmd.CommandTimeout = 300
$out = @()
function Q($title,$sql){
  $script:out += ""; $script:out += "=== $title ==="
  try { $cmd.CommandText=$sql; $r=$cmd.ExecuteReader()
    while($r.Read()){ $v=@(); for($i=0;$i -lt $r.FieldCount;$i++){ $v += "$($r.GetName($i))=$($r[$i])" }; $script:out += ($v -join ' | ') }
    $r.Close() } catch { $script:out += "ERR: $($_.Exception.Message)" }
}

# ===== ISSUE 1: reconciliation per MAIN ekspedisi doc 2026 =====
Q "RECON 2026 main ekspedisi: faktur(ap) vs tstok2 alloc vs GL" @"
SELECT a.order_client doc, a.tgl, a.vendor_id,
  a.ttl_kotor ap_kotor, a.ttl_ppn ap_ppn,
  (SELECT SUM(c.freight) FROM ap_trans c WHERE c.order_reff=a.order_client) child_freight_BM,
  (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2_alloc,
  (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id LIKE '102-%') gl_main_persed,
  (SELECT SUM(kredit) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id='226-006') gl_main_hutang
FROM ap_trans a
WHERE a.tipe_trans='05' AND a.tgl >= '2026-01-01' AND ISNULL(a.order_reff,'')=''
ORDER BY a.tgl, a.order_client
"@

# ===== ISSUE 2 LEGACY: 102-601 source of 2015-2016 imbalance =====
Q "102-601 by module ALL years (Dr/Cr/net)" @"
SELECT modul_id, SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) net, COUNT(*) n
FROM gl_journal WHERE account_id='102-601' GROUP BY modul_id ORDER BY modul_id
"@

Q "102-601 2015-2016 by year+module" @"
SELECT YEAR(tgl) y, modul_id, SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) net, COUNT(*) n
FROM gl_journal WHERE account_id='102-601' AND tgl < '2017-01-01'
GROUP BY YEAR(tgl), modul_id ORDER BY y, modul_id
"@

Q "102-601 EARLIEST 20 entries (cari saldo awal/opening)" @"
SELECT TOP 20 tgl, modul_id, doc_reff, urut, debet, kredit, ket
FROM gl_journal WHERE account_id='102-601' ORDER BY tgl, modul_id, doc_reff
"@

Q "102-601 2015 monthly net" @"
SELECT MONTH(tgl) m, SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) net, COUNT(*) n
FROM gl_journal WHERE account_id='102-601' AND tgl>='2015-01-01' AND tgl<'2016-01-01'
GROUP BY MONTH(tgl) ORDER BY m
"@

Q "102-601 2015 biggest single CREDIT lines (top 15)" @"
SELECT TOP 15 tgl, modul_id, doc_reff, kredit, ket
FROM gl_journal WHERE account_id='102-601' AND tgl>='2015-01-01' AND tgl<'2016-01-01' AND kredit>0
ORDER BY kredit DESC
"@

Q "102-601 2015 biggest single DEBET lines (top 15)" @"
SELECT TOP 15 tgl, modul_id, doc_reff, debet, ket
FROM gl_journal WHERE account_id='102-601' AND tgl>='2015-01-01' AND tgl<'2016-01-01' AND debet>0
ORDER BY debet DESC
"@

$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag119_recon_legacy_out.txt -Encoding UTF8
Write-Output ($out -join "`r`n")
