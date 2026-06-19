$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$tgl1 = "'2026-02-01'"
$tgl2 = "'2026-02-28'"
$invSql = @"
SELECT
    JANGKAR.ORDER_CLIENT,
    ISNULL(MAX(A_BASE.TGL),          MAX(SAF.TGL_FAKTUR))             AS TGL,
    ISNULL(MAX(A_BASE.VENDOR_ID),    MAX(SAF.VENDOR_ID))              AS VENDOR_ID,
    ISNULL(MAX(A_BASE.CURR_ID),      MAX(SAF.CURR_ID))                AS CURR_ID,
    ISNULL(MAX(A_BASE.TIPE_TRANS),   CAST(MAX(SAF.TIPE_TRANS) AS VARCHAR(2))) AS TIPE_TRANS,
    ISNULL(MAX(A_BASE.KURS),         MAX(SAF.RATE))                   AS KURS
FROM (
    SELECT AT.ORDER_CLIENT
    FROM AP_TRANS AT
    WHERE AT.TIPE_TRANS IN ('02','05','06','12','16')
      AND AT.TGL >= $tgl1 AND AT.TGL < DATEADD(day, 1, $tgl2)
      AND AT.ORDER_CLIENT IN (SELECT GJ.voucher FROM gl_journal GJ WHERE GJ.account_id='226-001' AND GJ.kredit>0)
    UNION
    SELECT SAF2.BUKTI_ID
    FROM SALDO_AWAL_FAKTUR SAF2
    WHERE SAF2.TIPE_TRANS IN (1, 2)
      AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1)
      AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1))
      AND SAF2.BUKTI_ID IN (SELECT GJ.voucher FROM gl_journal GJ WHERE GJ.account_id='226-001' AND GJ.kredit>0)
    UNION
    SELECT AT2.ORDER_CLIENT
    FROM AP_TRANS AT2
    WHERE AT2.TIPE_TRANS IN ('02','05','06','12','16')
      AND AT2.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1)
      AND AT2.TGL  < $tgl1
      AND AT2.ORDER_CLIENT IN (SELECT GJ.voucher FROM gl_journal GJ WHERE GJ.account_id='226-001' AND GJ.kredit>0)
) JANGKAR
LEFT JOIN AP_TRANS A_BASE
    ON  A_BASE.ORDER_CLIENT = JANGKAR.ORDER_CLIENT
    AND A_BASE.TIPE_TRANS  IN ('02','05','06','12','16')
LEFT JOIN SALDO_AWAL_FAKTUR SAF
    ON  SAF.BUKTI_ID        = JANGKAR.ORDER_CLIENT
    AND SAF.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1)
    AND SAF.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1))
WHERE JANGKAR.ORDER_CLIENT = '101BTB251200032'
GROUP BY JANGKAR.ORDER_CLIENT
"@
$c = $conn.CreateCommand(); $c.CommandText = $invSql; $c.CommandTimeout = 300
$r = $c.ExecuteReader()
$found = $false
while ($r.Read()) {
  $found = $true
  $row = @()
  for ($i = 0; $i -lt $r.FieldCount; $i++) { $row += "$($r.GetName($i))=$($r[$i])" }
  Write-Host ($row -join ' | ')
}
if (-not $found) { Write-Host "INV: voucher NOT in JANGKAR for Feb" }
$r.Close(); $conn.Close()
