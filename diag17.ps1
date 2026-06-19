# diag17.ps1 - Cari entry GL 226-001 sebelum 2026-01-01 yang bukan dari BTB sub-ledger
Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

# Step 1: List semua voucher di GL 226-001 yang BUKAN format BTB
# dan hitung NET-nya (bisa jadi revaluasi atau jurnal manual)
$sql = @'
SELECT
    GG.voucher,
    GG.tgl,
    GG.ket,
    SUM(GG.kredit) AS K,
    SUM(GG.debet)  AS D,
    SUM(GG.kredit) - SUM(GG.debet) AS NET
FROM gl_journal GG
WHERE GG.account_id = '226-001'
  AND GG.tgl < '2026-01-01'
  AND GG.voucher NOT LIKE '101BTB%'
GROUP BY GG.voucher, GG.tgl, GG.ket
HAVING (SUM(GG.kredit) - SUM(GG.debet)) <> 0
ORDER BY GG.tgl
'@

$out = @()
$out += "=== GL 226-001 non-BTB entries (TGL < 2026-01-01) ==="
$out += "VOUCHER|TGL|KET|K|D|NET"
try {
    $cmd = $con.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $tNet=0
    while ($r.Read()) {
        $net = [decimal]$r["NET"]
        $tNet += $net
        $out += "$($r['voucher'])|$($r['tgl'])|$($r['ket'])|$($r['K'])|$($r['D'])|$net"
    }
    $r.Close()
    $out += "--- TOTAL NET non-BTB ---"
    $out += "SUM(NET) = $tNet"
    $out += ""
    $out += "GL SA total              = 14159923466.61"
    $out += "SUM(SALDO_KURS*RATE)     = 14099742532.194"
    $out += "Gap (non-BTB GL NET)     = 60180934.416  (expected: $tNet)"
} catch { $out += "ERROR: $_" }
finally { $con.Close() }

$out | Out-File "C:\BTV\debug\diag17_out.txt" -Encoding UTF8
Write-Host "Done. C:\BTV\debug\diag17_out.txt"
