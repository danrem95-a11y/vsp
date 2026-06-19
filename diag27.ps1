Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    S.BUKTI_ID,
    MAX(S.VENDOR_ID) AS VENDOR_ID,
    MAX(S.CURR_ID) AS CURR_ID,
    SUM(ISNULL(S.SALDO_KURS * S.RATE, 0)) AS SAF_RATE,
    SUM(ISNULL(S.NEW_SALDO, 0)) AS SAF_NEW,
    ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0) AS GL_NET,
    (ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0)) - SUM(ISNULL(S.SALDO_KURS * S.RATE, 0)) AS DIFF_RATE,
    (ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0)) - SUM(ISNULL(S.NEW_SALDO, 0)) AS DIFF_NEW
FROM SALDO_AWAL_FAKTUR S
LEFT JOIN (
    SELECT GG.voucher, SUM(GG.kredit) AS GL_K
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.kredit > 0
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.voucher
) GK
    ON GK.voucher = S.BUKTI_ID
LEFT JOIN (
    SELECT GG.order_reff, SUM(GG.debet) AS GL_D
    FROM gl_journal GG
    WHERE GG.account_id = '226-001'
      AND GG.debet > 0
      AND GG.tgl < '2026-01-01'
    GROUP BY GG.order_reff
) GD
    ON GD.order_reff = S.BUKTI_ID
WHERE S.TIPE_TRANS IN (1, 2)
  AND S.PERIODE >= '2026-01-01'
  AND S.PERIODE < '2026-02-01'
  AND EXISTS (
      SELECT 1 FROM gl_journal GJ
      WHERE GJ.voucher = S.BUKTI_ID
        AND GJ.account_id = '226-001'
        AND GJ.kredit > 0)
GROUP BY S.BUKTI_ID, ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0)
HAVING ROUND((ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0)) - SUM(ISNULL(S.SALDO_KURS * S.RATE, 0)), 2) <> 0
ORDER BY ABS((ISNULL(GK.GL_K, 0) - ISNULL(GD.GL_D, 0)) - SUM(ISNULL(S.SALDO_KURS * S.RATE, 0))) DESC
'@

$out = @()
try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $sumRate = [decimal]0
    $sumNew = [decimal]0
    while ($r.Read()) {
        $dRate = [decimal]$r['DIFF_RATE']
        $dNew = [decimal]$r['DIFF_NEW']
        $sumRate += $dRate
        $sumNew += $dNew
        $out += "$($r['BUKTI_ID'])|$($r['VENDOR_ID'])|$($r['CURR_ID'])|$($r['SAF_RATE'])|$($r['SAF_NEW'])|$($r['GL_NET'])|$dRate|$dNew"
    }
    $r.Close()
    $out += "TOTAL_DIFF_RATE=$sumRate"
    $out += "TOTAL_DIFF_NEW=$sumNew"
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag27_out.txt' -Encoding UTF8