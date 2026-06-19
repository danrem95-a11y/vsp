Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# Compute SUM(per-voucher GL net) for the SAME JANGKAR voucher set used by qryopname Jan 2026
$sql = @'
SELECT SUM(NET) AS TOTAL_GL_SA, COUNT(*) AS C
FROM (
  SELECT GJ.voucher, SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0)) AS NET
  FROM gl_journal GJ
  WHERE GJ.account_id='226-001'
    AND GJ.tgl < '2026-01-01'
    AND GJ.voucher IN (
        SELECT AT.ORDER_CLIENT FROM AP_TRANS AT
        WHERE AT.TIPE_TRANS IN ('02','05','06','12','16')
          AND AT.TGL >= '2026-01-01' AND AT.TGL < '2026-02-01'
          AND AT.ORDER_CLIENT IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
        UNION
        SELECT SAF2.BUKTI_ID FROM SALDO_AWAL_FAKTUR SAF2
        WHERE SAF2.TIPE_TRANS IN (1,2)
          AND SAF2.PERIODE >= '2026-01-01' AND SAF2.PERIODE < '2026-02-01'
          AND SAF2.BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
        UNION
        SELECT AT2.ORDER_CLIENT FROM AP_TRANS AT2
        WHERE AT2.TIPE_TRANS IN ('02','05','06','12','16')
          AND AT2.TGL >= '2026-01-01' AND AT2.TGL < '2026-01-01'
          AND AT2.ORDER_CLIENT IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
    )
  GROUP BY GJ.voucher
) X
'@

# Also: only positive-net (open) vouchers in same set
$sql2 = @'
SELECT SUM(NET) AS TOTAL_GL_SA_POS, COUNT(*) AS C
FROM (
  SELECT GJ.voucher, SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0)) AS NET
  FROM gl_journal GJ
  WHERE GJ.account_id='226-001'
    AND GJ.tgl < '2026-01-01'
    AND GJ.voucher IN (
        SELECT AT.ORDER_CLIENT FROM AP_TRANS AT
        WHERE AT.TIPE_TRANS IN ('02','05','06','12','16')
          AND AT.TGL >= '2026-01-01' AND AT.TGL < '2026-02-01'
          AND AT.ORDER_CLIENT IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
        UNION
        SELECT SAF2.BUKTI_ID FROM SALDO_AWAL_FAKTUR SAF2
        WHERE SAF2.TIPE_TRANS IN (1,2)
          AND SAF2.PERIODE >= '2026-01-01' AND SAF2.PERIODE < '2026-02-01'
          AND SAF2.BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
    )
  GROUP BY GJ.voucher
  HAVING ROUND(SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0)),2) > 0
) X
'@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600
  foreach($p in @(@('GL_SA_JANGKAR_ALL',$sql),@('GL_SA_JANGKAR_POS',$sql2))){
    $cmd.CommandText = $p[1]; $r = $cmd.ExecuteReader()
    if ($r.Read()) {
      $line = $p[0]
      for($i=0;$i -lt $r.FieldCount;$i++){$line += "|"+$r.GetName($i)+"="+$r.GetValue($i)}
      $out += $line
    }
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag40_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
