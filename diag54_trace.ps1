$ErrorActionPreference = 'Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()
$vc = '101BTB251200032'
$tgl1 = "'2026-02-01'"
function Show($q, $label) {
  $c = $conn.CreateCommand(); $c.CommandText = $q; $c.CommandTimeout = 600
  $r = $c.ExecuteReader()
  Write-Host "=== $label ==="
  while ($r.Read()) {
    $row = @()
    for ($i = 0; $i -lt $r.FieldCount; $i++) { $row += "$($r.GetName($i))=$($r[$i])" }
    Write-Host ($row -join ' | ')
  }
  $r.Close()
}

# Branch 2 (SAF carry-over)
Show @"
SELECT SAF2.BUKTI_ID
FROM SALDO_AWAL_FAKTUR SAF2
WHERE SAF2.TIPE_TRANS IN (1, 2)
  AND SAF2.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1)
  AND SAF2.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1))
  AND SAF2.BUKTI_ID = '$vc'
  AND SAF2.BUKTI_ID IN (SELECT GJ.voucher FROM gl_journal GJ WHERE GJ.account_id='226-001' AND GJ.kredit>0)
"@ 'JANGKAR branch 2 (SAF)'

# OPN_HIST
Show @"
SELECT SAF_O.BUKTI_ID, AVG(SAF_O.RATE) RATE, SUM(SAF_O.SALDO_KURS) AWAL_KURS, SUM(SAF_O.SALDO) * 14159923466.61 / 14211832355.63 AWAL_IDR
FROM SALDO_AWAL_FAKTUR SAF_O
WHERE SAF_O.TIPE_TRANS IN (1, 2)
  AND SAF_O.PERIODE >= DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1)
  AND SAF_O.PERIODE <  DATEADD(month, 1, DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1))
  AND SAF_O.BUKTI_ID = '$vc'
GROUP BY SAF_O.BUKTI_ID
"@ 'OPN_HIST for voucher'

# HIST_BYR
Show @"
SELECT T2.BUKTI_ID, SUM(T2.NILAI_BAYAR) BAYAR_LALU, SUM(T2.NILAI_BAYAR_IDR) BAYAR_LALU_IDR
FROM TBYR1 T1 INNER JOIN TBYR2 T2 ON T2.VOUCHER=T1.VOUCHER
WHERE T1.FLAG_BAYAR IN (1,2)
  AND T1.TGL >= DATEADD(day, 1 - DATEPART(dayofyear, $tgl1), $tgl1)
  AND T1.TGL  < $tgl1
  AND T2.BUKTI_ID = '$vc'
GROUP BY T2.BUKTI_ID
"@ 'HIST_BYR for voucher'

# Outer query running for Feb, look for this voucher only at INV stage
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$sFeb = $sql -replace ':arg_tgl1', $tgl1 -replace ':arg_tgl2', "'2026-02-28'"
$sFeb = $sFeb.TrimEnd().TrimEnd(';')
# Strip outer WHERE -- find "WHERE\n    ROUND" through ORDER BY
$noFilter = $sFeb -replace '(?s)WHERE\s+ROUND.*?ORDER BY', 'ORDER BY'
$q = "SELECT ORDER_CLIENT, SALDO_AWAL_IDR, MUTASI_IDR, ADJ_IDR, NILAI_BAYAR_IDR, SISA_IDR FROM ($noFilter) X WHERE ORDER_CLIENT='$vc'"
Show $q 'Feb output WITHOUT outer ROUND filter'

$conn.Close()
