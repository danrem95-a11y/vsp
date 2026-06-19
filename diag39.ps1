Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()
$sql = @'
SELECT
  S.BUKTI_ID,
  S.VENDOR_ID,
  S.CURR_ID,
  S.SALDO_KURS,
  S.RATE,
  S.NEW_RATE,
  S.SALDO,
  S.NEW_SALDO,
  S.SALDO_KURS*S.RATE   AS S_KxR,
  S.SALDO_KURS*S.NEW_RATE AS S_KxNR,
  (SELECT SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0))
   FROM gl_journal GJ
   WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.tgl<'2026-01-01') AS GL_NET
FROM SALDO_AWAL_FAKTUR S
WHERE S.TIPE_TRANS IN (1,2)
  AND S.PERIODE >= '2026-01-01' AND S.PERIODE < '2026-02-01'
  AND S.BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
ORDER BY S.BUKTI_ID
'@
try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=300
  $cmd.CommandText = $sql
  $r = $cmd.ExecuteReader()
  $hdr = @(); for($i=0;$i -lt $r.FieldCount;$i++){$hdr += $r.GetName($i)}
  $out += ($hdr -join "|")
  while ($r.Read()) {
    $vals=@(); for($i=0;$i -lt $r.FieldCount;$i++){$vals += "$($r.GetValue($i))"}
    $out += ($vals -join "|")
  }
  $r.Close()
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag39_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
