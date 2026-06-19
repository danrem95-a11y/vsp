Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT 'VP1_OR_101PK' AS KET,
             SUM(GG.kredit) AS K,
             SUM(GG.debet)  AS D,
             SUM(GG.kredit) - SUM(GG.debet) AS NET
FROM gl_journal GG
WHERE GG.account_id = '226-001'
    AND GG.tgl >= '2025-01-01'
    AND GG.tgl < '2026-01-01'
    AND (GG.voucher LIKE 'VP1%' OR GG.voucher LIKE '101PK%')

UNION ALL

SELECT 'NON_BTB_ORDERREFF_BTB' AS KET,
             SUM(GG.kredit) AS K,
             SUM(GG.debet)  AS D,
             SUM(GG.kredit) - SUM(GG.debet) AS NET
FROM gl_journal GG
WHERE GG.account_id = '226-001'
    AND GG.tgl >= '2025-01-01'
    AND GG.tgl < '2026-01-01'
    AND GG.voucher NOT LIKE '101BTB%'
    AND ISNULL(GG.order_reff, '') LIKE '101BTB%'
'@

try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
        Write-Output "$($r['KET'])|K=$($r['K'])|D=$($r['D'])|NET=$($r['NET'])"
    }
    $r.Close()
}
finally {
    $con.Close()
}