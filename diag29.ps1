Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT SRC, VOUCHER, NET
FROM (
    SELECT
        'SAF_LINK_IDR' AS SRC,
        GG.voucher AS VOUCHER,
        -(SUM(GG.kredit) - SUM(GG.debet)) AS NET
    FROM gl_journal GG
    JOIN SALDO_AWAL_FAKTUR S
      ON S.BUKTI_ID = GG.order_reff
     AND S.TIPE_TRANS IN (1, 2)
     AND S.PERIODE >= '2026-01-01'
     AND S.PERIODE < '2026-02-01'
     AND S.CURR_ID = 'IDR'
    WHERE GG.account_id = '226-001'
      AND GG.tgl >= '2025-01-01'
      AND GG.tgl < '2026-01-01'
      AND GG.voucher NOT LIKE '101BTB%'
      AND NOT EXISTS (SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT = GG.voucher)
    GROUP BY GG.voucher
    HAVING -(SUM(GG.kredit) - SUM(GG.debet)) > 0

    UNION ALL

    SELECT
        'GL_ONLY_SMALL_IDR' AS SRC,
        GG.voucher AS VOUCHER,
        -(SUM(GG.kredit) - SUM(GG.debet)) AS NET
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.tgl >= '2025-01-01'
      AND GG.tgl < '2026-01-01'
      AND GG.curr_id = 'IDR'
      AND GG.voucher NOT LIKE '101BTB%'
      AND GG.voucher NOT LIKE 'VP1%'
      AND GG.voucher NOT LIKE '101PK%'
      AND NOT EXISTS (SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT = GG.voucher)
      AND NOT EXISTS (
          SELECT 1 FROM SALDO_AWAL_FAKTUR S
          WHERE S.BUKTI_ID = GG.voucher
            AND S.TIPE_TRANS IN (1, 2)
            AND S.PERIODE >= '2026-01-01'
            AND S.PERIODE < '2026-02-01')
      AND ISNULL(GG.order_reff, '') NOT LIKE '101BTB%'
    GROUP BY GG.voucher
    HAVING -(SUM(GG.kredit) - SUM(GG.debet)) > 0
       AND -(SUM(GG.kredit) - SUM(GG.debet)) < 1000000
) X
ORDER BY NET DESC
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
        $out += "$($r['SRC'])|$($r['VOUCHER'])|$net"
    }
    $r.Close()
    $out += "TOTAL=$sum"
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag29_out.txt' -Encoding UTF8