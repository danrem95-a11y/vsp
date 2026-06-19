Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    GG.voucher,
    MAX(GG.tgl) AS TGL,
    SUM(GG.kredit) AS K,
    SUM(GG.debet)  AS D,
    SUM(GG.kredit) - SUM(GG.debet) AS NET
FROM gl_journal GG
WHERE GG.account_id = '226-001'
  AND GG.tgl >= '2025-01-01'
  AND GG.tgl < '2026-01-01'
  AND GG.voucher NOT LIKE '101BTB%'
  AND GG.voucher NOT LIKE 'VP1%'
  AND GG.voucher NOT LIKE '101PK%'
  AND NOT EXISTS (SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT = GG.voucher)
  AND NOT EXISTS (SELECT 1 FROM SALDO_AWAL_FAKTUR S WHERE S.BUKTI_ID = GG.voucher AND MONTH(S.PERIODE) = 1 AND YEAR(S.PERIODE) = 2026)
GROUP BY GG.voucher
HAVING (SUM(GG.kredit) - SUM(GG.debet)) <> 0
ORDER BY ABS(SUM(GG.kredit) - SUM(GG.debet)) DESC
'@

$out = @()
try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $sum = [decimal]0
    while ($r.Read()) {
        $net = [decimal]$r['NET']
        $sum += $net
        $out += "$($r['voucher'])|$($r['TGL'])|$($r['K'])|$($r['D'])|$net"
    }
    $r.Close()
    $out += "TOTAL=$sum"
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag21_out.txt' -Encoding UTF8