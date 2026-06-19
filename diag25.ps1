Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    GG.voucher,
    GG.order_reff,
    MAX(S.VENDOR_ID) AS VENDOR_ID,
    MAX(S.CURR_ID) AS CURR_ID,
    MAX(S.RATE) AS RATE,
    MAX(S.NEW_RATE) AS NEW_RATE,
    MAX(S.SALDO) AS SALDO,
    MAX(S.NEW_SALDO) AS NEW_SALDO,
    SUM(GG.kredit) AS K,
    SUM(GG.debet)  AS D,
    SUM(GG.kredit) - SUM(GG.debet) AS NET
FROM gl_journal GG
JOIN SALDO_AWAL_FAKTUR S
  ON S.BUKTI_ID = GG.order_reff
 AND S.TIPE_TRANS IN (1, 2)
 AND MONTH(S.PERIODE) = 1
 AND YEAR(S.PERIODE) = 2026
WHERE GG.account_id = '226-001'
  AND GG.tgl >= '2025-01-01'
  AND GG.tgl < '2026-01-01'
  AND GG.voucher NOT LIKE '101BTB%'
  AND NOT EXISTS (SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT = GG.voucher)
GROUP BY GG.voucher, GG.order_reff
HAVING (SUM(GG.kredit) - SUM(GG.debet)) <> 0
ORDER BY ABS(SUM(GG.kredit) - SUM(GG.debet)) DESC
'@

$out = @()
try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
        $out += "$($r['voucher'])|$($r['order_reff'])|$($r['VENDOR_ID'])|$($r['CURR_ID'])|$($r['SALDO'])|$($r['NEW_SALDO'])|$($r['NET'])"
    }
    $r.Close()
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag25_out.txt' -Encoding UTF8