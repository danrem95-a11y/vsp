Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# Strategy: ledger SA per voucher = SUM kredit - SUM debet pre-2026, only kredit-net positive vouchers
# Compare with SAF NEW_SALDO snapshot per voucher for same voucher set used by qryopname
$sql1 = @'
SELECT SUM(NET) AS V, COUNT(*) AS C FROM (
  SELECT voucher, SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS NET
  FROM gl_journal
  WHERE account_id='226-001' AND tgl<'2026-01-01'
  GROUP BY voucher
  HAVING ROUND(SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)),2) > 0
) X
'@

# SAF for Jan 2026 (PERIODE in Jan 2026), TIPE_TRANS 1,2, joined to GL kredit voucher list
$sql2 = @'
SELECT
  SUM(ISNULL(NEW_SALDO,0)) AS NS,
  SUM(ISNULL(SALDO,0))     AS SLD,
  SUM(ISNULL(SALDO_KURS*RATE,0)) AS SKxR,
  COUNT(*) AS C,
  COUNT(DISTINCT BUKTI_ID) AS CB
FROM SALDO_AWAL_FAKTUR
WHERE TIPE_TRANS IN (1,2)
  AND PERIODE >= '2026-01-01' AND PERIODE < '2026-02-01'
  AND BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
'@

# Cross-check: SAF bukti_id that DO NOT have positive GL net (likely the source of overshoot)
$sql3 = @'
SELECT SUM(ISNULL(S.NEW_SALDO,0)) AS NS_OVER, COUNT(*) AS C
FROM SALDO_AWAL_FAKTUR S
WHERE S.TIPE_TRANS IN (1,2)
  AND S.PERIODE >= '2026-01-01' AND S.PERIODE < '2026-02-01'
  AND S.BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
  AND NOT EXISTS (
    SELECT 1 FROM gl_journal GJ
    WHERE GJ.voucher = S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.tgl<'2026-01-01'
    GROUP BY GJ.voucher
    HAVING ROUND(SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0)),2) > 0
  )
'@

# And the reverse: SAF rows where SAF NEW_SALDO != GL net (per voucher diff)
$sql4 = @'
SELECT SUM(SAF_IDR - GL_NET) AS DIFF_TOT, SUM(ABS(SAF_IDR - GL_NET)) AS ABS_DIFF, COUNT(*) AS C
FROM (
  SELECT S.BUKTI_ID,
         SUM(ISNULL(S.NEW_SALDO,0)) AS SAF_IDR,
         (SELECT SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0))
          FROM gl_journal GJ
          WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.tgl<'2026-01-01') AS GL_NET
  FROM SALDO_AWAL_FAKTUR S
  WHERE S.TIPE_TRANS IN (1,2)
    AND S.PERIODE >= '2026-01-01' AND S.PERIODE < '2026-02-01'
    AND S.BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
  GROUP BY S.BUKTI_ID
) X
'@

# Direct: sum of GL net per voucher for same voucher set as SAF Jan 2026 rows
$sql5 = @'
SELECT SUM(NET) AS V, COUNT(*) AS C
FROM (
  SELECT GJ.voucher, SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0)) AS NET
  FROM gl_journal GJ
  WHERE GJ.account_id='226-001' AND GJ.tgl<'2026-01-01'
    AND GJ.voucher IN (
      SELECT DISTINCT BUKTI_ID FROM SALDO_AWAL_FAKTUR
      WHERE TIPE_TRANS IN (1,2)
        AND PERIODE >= '2026-01-01' AND PERIODE < '2026-02-01')
  GROUP BY GJ.voucher
) X
'@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600
  foreach ($pair in @(@('GL_OPEN_K_GT_D',$sql1),@('SAF_JAN26',$sql2),@('SAF_NO_GL_OPEN',$sql3),@('SAF_VS_GL_DIFF',$sql4),@('GL_NET_FOR_SAF',$sql5))) {
    $cmd.CommandText = $pair[1]
    $r = $cmd.ExecuteReader()
    if ($r.Read()) {
      $line = $pair[0]
      for ($i=0; $i -lt $r.FieldCount; $i++) {
        $line += "|" + $r.GetName($i) + "=" + $r.GetValue($i)
      }
      $out += $line
    }
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag38_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
