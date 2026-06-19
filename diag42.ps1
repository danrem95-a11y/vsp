Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# 1) Distinct SAF PERIODE values around year-end
$sql1 = @"
SELECT PERIODE, COUNT(*) AS C, SUM(SALDO) AS SLD, SUM(NEW_SALDO) AS NS
FROM SALDO_AWAL_FAKTUR
WHERE PERIODE BETWEEN '2025-11-01' AND '2026-02-01'
  AND TIPE_TRANS IN (1,2)
  AND BUKTI_ID IN (SELECT voucher FROM gl_journal WHERE account_id='226-001' AND kredit>0)
GROUP BY PERIODE
ORDER BY PERIODE
"@

# 2) GL 226-001 journals dated 2025-12-31 or 2026-01-01 (potential year-end adjustment)
$sql2 = @"
SELECT TOP 50 tgl, voucher, kredit, debet, ket, modul_id
FROM gl_journal
WHERE account_id='226-001' AND tgl IN ('2025-12-31','2026-01-01')
ORDER BY tgl, voucher
"@

# 3) GL 226-001 sum by modul_id pre-2026 (identify revaluation journals)
$sql3 = @"
SELECT modul_id, SUM(ISNULL(kredit,0)) AS K, SUM(ISNULL(debet,0)) AS D, COUNT(*) AS C
FROM gl_journal
WHERE account_id='226-001' AND tgl<'2026-01-01'
GROUP BY modul_id
ORDER BY modul_id
"@

# 4) GL 226-001 net for ALL vouchers WITH a positive net pre-2026 (full carry-forward, not just SAF subset)
$sql4 = @"
SELECT SUM(NET) AS GL_OPEN_TOTAL, COUNT(*) AS C
FROM (
  SELECT voucher, SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS NET
  FROM gl_journal
  WHERE account_id='226-001' AND tgl<'2026-01-01'
  GROUP BY voucher
  HAVING ROUND(SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)),2) > 0
) X
"@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600
  $cmd.CommandText = $sql1
  $r = $cmd.ExecuteReader()
  $out += "=== SAF PERIODE around year-end ==="
  $h=@();for($i=0;$i -lt $r.FieldCount;$i++){$h += $r.GetName($i)}
  $out += ($h -join "|")
  while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|")}
  $r.Close()

  $cmd.CommandText = $sql2
  $r = $cmd.ExecuteReader()
  $out += "=== GL 226-001 on Dec31/Jan1 ==="
  $h=@();for($i=0;$i -lt $r.FieldCount;$i++){$h += $r.GetName($i)}
  $out += ($h -join "|")
  $cnt=0
  while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|");$cnt++}
  $r.Close()
  $out += "COUNT=$cnt"

  $cmd.CommandText = $sql3
  $r = $cmd.ExecuteReader()
  $out += "=== GL 226-001 by modul_id pre-2026 ==="
  $h=@();for($i=0;$i -lt $r.FieldCount;$i++){$h += $r.GetName($i)}
  $out += ($h -join "|")
  while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|")}
  $r.Close()

  $cmd.CommandText = $sql4
  $r = $cmd.ExecuteReader()
  if($r.Read()){
    $line = "GL_OPEN_POS_TOTAL"
    for($i=0;$i -lt $r.FieldCount;$i++){$line += "|"+$r.GetName($i)+"="+$r.GetValue($i)}
    $out += $line
  }
  $r.Close()
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag42_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
