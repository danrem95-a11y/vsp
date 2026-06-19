Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    X.BUKTI_ID,
    MAX(A.VENDOR_ID) AS VENDOR_ID,
    SUM(ISNULL(GK.GL_K, 0)) - SUM(ISNULL(GD.GL_D, 0)) AS GL_NET
FROM (
    SELECT DISTINCT A.ORDER_CLIENT AS BUKTI_ID
    FROM AP_TRANS A
    WHERE A.TGL >= '2025-01-01'
      AND A.TGL < '2026-01-01'
      AND A.ORDER_OKE = 'Y'
      AND A.TIPE_TRANS IN ('02', '05', '06', '12', '16')
      AND A.ORDER_CLIENT NOT LIKE '101BTB%'
      AND EXISTS (
          SELECT 1 FROM gl_journal GJ
          WHERE GJ.voucher = A.ORDER_CLIENT
            AND GJ.account_id = '226-001'
            AND GJ.kredit > 0)
      AND NOT EXISTS (
          SELECT 1 FROM SALDO_AWAL_FAKTUR S
          WHERE S.BUKTI_ID = A.ORDER_CLIENT
            AND S.TIPE_TRANS IN (1, 2)
            AND S.PERIODE >= '2026-01-01'
            AND S.PERIODE < '2026-02-01')
) X
LEFT JOIN AP_TRANS A
    ON A.ORDER_CLIENT = X.BUKTI_ID
LEFT JOIN (
    SELECT GG.voucher, SUM(GG.kredit) AS GL_K
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.kredit > 0
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.voucher
) GK ON GK.voucher = X.BUKTI_ID
LEFT JOIN (
    SELECT GG.order_reff, SUM(GG.debet) AS GL_D
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.debet > 0
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.order_reff
) GD ON GD.order_reff = X.BUKTI_ID
GROUP BY X.BUKTI_ID
HAVING ROUND(SUM(ISNULL(GK.GL_K, 0)) - SUM(ISNULL(GD.GL_D, 0)), 2) <> 0
ORDER BY ABS(SUM(ISNULL(GK.GL_K, 0)) - SUM(ISNULL(GD.GL_D, 0))) DESC
'@

$out = @()
try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $sum = [decimal]0
    while ($r.Read()) {
        $net = [decimal]$r['GL_NET']
        $sum += $net
        $out += "$($r['BUKTI_ID'])|$($r['VENDOR_ID'])|$net"
    }
    $r.Close()
    $out += "TOTAL=$sum"
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag28_out.txt' -Encoding UTF8