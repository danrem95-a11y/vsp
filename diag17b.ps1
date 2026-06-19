# diag17b.ps1 - Cari entry GL 226-001 yang BENAR-BENAR bukan BTB
# (bukan invoice BTB dan bukan pembayaran BTB)
Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    GG.voucher,
    GG.tgl,
    GG.ket,
    GG.order_reff,
    SUM(GG.kredit) AS K,
    SUM(GG.debet)  AS D,
    SUM(GG.kredit) - SUM(GG.debet) AS NET
FROM gl_journal GG
WHERE GG.account_id = '226-001'
  AND GG.tgl < '2026-01-01'
  AND GG.voucher NOT LIKE '101BTB%'
  AND ISNULL(GG.order_reff, '') NOT LIKE '101BTB%'
GROUP BY GG.voucher, GG.tgl, GG.ket, GG.order_reff
HAVING (SUM(GG.kredit) - SUM(GG.debet)) <> 0
ORDER BY GG.tgl DESC
'@

$out = @()
$out += "=== GL 226-001: Entry BUKAN BTB invoice/pembayaran (TGL < 2026-01-01) ==="
$out += "VOUCHER|TGL|KET|ORDER_REFF|K|D|NET"
try {
    $cmd = $con.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $tNet=0; $tK=0; $tD=0
    while ($r.Read()) {
        $net = [decimal]$r["NET"]
        $tNet += $net; $tK += [decimal]$r["K"]; $tD += [decimal]$r["D"]
        $out += "$($r['voucher'])|$($r['tgl'])|$($r['ket'])|$($r['order_reff'])|$($r['K'])|$($r['D'])|$net"
    }
    $r.Close()
    $out += "--- TOTAL ---"
    $out += "SUM(K)   = $tK"
    $out += "SUM(D)   = $tD"
    $out += "SUM(NET) = $tNet"
    $out += ""
    $out += "GL SA total            = 14159923466.61"
    $out += "SUM(SALDO_KURS*RATE)   = 14099742532.194"
    $out += "Expected NET orphan    = 60180934.416"
    $out += "Actual NET orphan      = $tNet"
} catch { $out += "ERROR: $_" }
finally { $con.Close() }

$out | Out-File "C:\BTV\debug\diag17b_out.txt" -Encoding UTF8
Write-Host "Done. C:\BTV\debug\diag17b_out.txt"
