$ErrorActionPreference = 'Stop'
$sql = Get-Content c:\BTV\debug\qryopname_ap.sql -Raw
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

# Per-voucher comparison: SISA_JAN vs SA_FEB
$sJan = $sql -replace ':arg_tgl1', "'2026-01-01'" -replace ':arg_tgl2', "'2026-01-31'"
$sJan = $sJan.TrimEnd().TrimEnd(';')
$sFeb = $sql -replace ':arg_tgl1', "'2026-02-01'" -replace ':arg_tgl2', "'2026-02-28'"
$sFeb = $sFeb.TrimEnd().TrimEnd(';')

$diag = @"
SELECT
  ISNULL(J.ORDER_CLIENT, F.ORDER_CLIENT)               AS VC,
  ISNULL(J.SISA_IDR, 0)                                AS SISA_JAN,
  ISNULL(F.SALDO_AWAL_IDR, 0)                          AS SA_FEB,
  ISNULL(F.SALDO_AWAL_IDR, 0) - ISNULL(J.SISA_IDR, 0)  AS DIFF
FROM ($sJan) J
FULL OUTER JOIN ($sFeb) F ON F.ORDER_CLIENT = J.ORDER_CLIENT
WHERE ABS(ISNULL(F.SALDO_AWAL_IDR, 0) - ISNULL(J.SISA_IDR, 0)) > 0.5
ORDER BY ABS(ISNULL(F.SALDO_AWAL_IDR, 0) - ISNULL(J.SISA_IDR, 0)) DESC
"@
$c = $conn.CreateCommand(); $c.CommandText = $diag; $c.CommandTimeout = 600
$r = $c.ExecuteReader()
$rows = @()
while ($r.Read()) {
  $rows += "{0,-20} SISA_JAN={1,18:N2}  SA_FEB={2,18:N2}  DIFF={3,16:N2}" -f $r['VC'], $r['SISA_JAN'], $r['SA_FEB'], $r['DIFF']
}
$r.Close(); $conn.Close()
"Total rows mismatched: $($rows.Count)"
$rows | Select-Object -First 30
$rows | Out-File c:\BTV\debug\diag50_out.txt -Encoding ascii
"---written diag50_out.txt---"
