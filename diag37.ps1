Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# Strategy GL-per-voucher: SA per ORDER_CLIENT = SUM(K-D) GL 226-001 where voucher=ORDER_CLIENT AND tgl<period
# Then sum only those vouchers that are in JANGKAR (the active list).
$qs = @(
  @{n='G_GL_VOUCHER_AP_NET_PRE26'; q=@"
SELECT SUM(NET) AS V, COUNT(*) AS C FROM (
  SELECT GG.voucher, SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)) AS NET
  FROM gl_journal GG
  WHERE GG.account_id='226-001' AND GG.tgl<'2026-01-01'
    AND (EXISTS(SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT=GG.voucher AND A.TIPE_TRANS IN ('02','05','06','12','16'))
         OR EXISTS(SELECT 1 FROM SALDO_AWAL_FAKTUR S WHERE S.BUKTI_ID=GG.voucher AND S.TIPE_TRANS IN (1,2)))
  GROUP BY GG.voucher
  HAVING ROUND(SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)),2)<>0
) X
"@}
  @{n='G_GL_ALL_AP_TYPE_PRE26'; q=@"
SELECT SUM(NET) AS V, COUNT(*) AS C FROM (
  SELECT GG.voucher, SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)) AS NET
  FROM gl_journal GG
  WHERE GG.account_id='226-001' AND GG.tgl<'2026-01-01'
    AND GG.modul_id IN ('PO','EX')
  GROUP BY GG.voucher
  HAVING ROUND(SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)),2)<>0
) X
"@}
  @{n='G_GL_BTB_VOUCHER_PRE26'; q=@"
SELECT SUM(NET) AS V, COUNT(*) AS C FROM (
  SELECT GG.voucher, SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)) AS NET
  FROM gl_journal GG
  WHERE GG.account_id='226-001' AND GG.tgl<'2026-01-01'
    AND GG.voucher LIKE '101BTB%'
  GROUP BY GG.voucher
  HAVING ROUND(SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)),2)<>0
) X
"@}
)
try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600
  foreach ($x in $qs) {
    $out += "--- $($x.n)"
    $cmd.CommandText = $x.q
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
      $line=""; for ($i=0;$i -lt $r.FieldCount;$i++){ $line += "$($r.GetName($i))=$($r[$i])|" }
      $out += $line
    }
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag37_out.txt' -Encoding UTF8
