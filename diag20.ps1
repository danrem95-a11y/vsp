Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$sql = @'
SELECT
    A.ORDER_CLIENT,
    MAX(A.TGL) AS TGL,
    MAX(A.VENDOR_ID) AS VENDOR_ID,
    MAX(A.TIPE_TRANS) AS TIPE_TRANS,
    SUM(CASE WHEN A.TIPE_TRANS = '05'
                 THEN A.TTL_NETTO
             ELSE (CASE WHEN A.TIPE_TRANS IN ('02', '06', '16') THEN A.TTL_NETTO
                        WHEN A.TIPE_TRANS = '12' THEN -ABS(A.TTL_NETTO)
                        ELSE 0 END) * ISNULL(A.KURS, 1)
        END) AS IDR_NETTO
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
        AND (GJ.kredit > 0 OR GJ.debet > 0))
  AND NOT EXISTS (
      SELECT 1 FROM SALDO_AWAL_FAKTUR S
      WHERE S.BUKTI_ID = A.ORDER_CLIENT
        AND S.TIPE_TRANS IN (1, 2)
        AND MONTH(S.PERIODE) = 1
        AND YEAR(S.PERIODE) = 2026)
GROUP BY A.ORDER_CLIENT
ORDER BY MAX(A.TGL) DESC, A.ORDER_CLIENT
'@

$out = @()
try {
    $cmd = $con.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $r = $cmd.ExecuteReader()
    $sum = [decimal]0
    $rows = @()
    while ($r.Read()) {
        $idr = [decimal]$r['IDR_NETTO']
        $sum += $idr
        $rows += "$($r['ORDER_CLIENT'])|$($r['TGL'])|$($r['VENDOR_ID'])|$($r['TIPE_TRANS'])|$idr"
    }
    $r.Close()
    $out += "TOTAL=$sum"
    $out += "TOP20"
    $out += ($rows | Select-Object -First 20)
}
finally {
    $con.Close()
}

$out | Out-File 'c:\BTV\debug\diag20_out.txt' -Encoding UTF8