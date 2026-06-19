Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# All VP entries on 226-001 with K>0 in 2025
$sql1 = @"
SELECT tgl, voucher, ROUND(kredit,2) AS K, ket
FROM gl_journal
WHERE account_id='226-001' AND modul_id='VP'
  AND tgl BETWEEN '2025-01-01' AND '2025-12-31'
  AND kredit > 0
ORDER BY voucher
"@

# Also: total of all SAF rows where TIPE_TRANS IN (1,2) for Jan 2026, all currency breakdowns
$sql2 = @"
SELECT CURR_ID, COUNT(*) AS C,
  SUM(SALDO_KURS) AS SK,
  SUM(SALDO_KURS*RATE) AS S_KxR,
  SUM(SALDO) AS S_S,
  SUM(NEW_SALDO) AS S_NS,
  SUM(SALDO_KURS*NEW_RATE) AS S_KxNR
FROM SALDO_AWAL_FAKTUR
WHERE TIPE_TRANS IN (1,2)
  AND PERIODE>='2026-01-01' AND PERIODE<'2026-02-01'
GROUP BY CURR_ID
ORDER BY CURR_ID
"@

# Per-voucher GL net pre-2026 for SAF JAN26 vouchers — for the 38 specifically
$sql3 = @"
SELECT
  S.BUKTI_ID,
  S.CURR_ID,
  S.SALDO       AS SAF_SALDO,
  S.NEW_SALDO   AS SAF_NS,
  (SELECT SUM(ISNULL(GJ.kredit,0))-SUM(ISNULL(GJ.debet,0))
   FROM gl_journal GJ
   WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.tgl<'2026-01-01' AND GJ.modul_id<>'VP') AS GL_NET_NO_VP,
  (SELECT SUM(ISNULL(GJ.kredit,0))
   FROM gl_journal GJ
   WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.tgl<'2026-01-01' AND GJ.modul_id='PO') AS GL_PO_K,
  (SELECT SUM(ISNULL(GJ.debet,0))
   FROM gl_journal GJ
   WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.tgl<'2026-01-01') AS GL_D
FROM SALDO_AWAL_FAKTUR S
WHERE S.TIPE_TRANS IN (1,2)
  AND S.PERIODE>='2026-01-01' AND S.PERIODE<'2026-02-01'
  AND S.CURR_ID <> 'IDR'
ORDER BY S.BUKTI_ID
"@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=300
  foreach($p in @(@('=== VP 226-001 K>0 in 2025 ===',$sql1),@('=== SAF by CURR Jan26 ===',$sql2),@('=== SAF FX vs GL no-VP ===',$sql3))) {
    $out += $p[0]
    $cmd.CommandText = $p[1]
    $r = $cmd.ExecuteReader()
    $h=@();for($i=0;$i -lt $r.FieldCount;$i++){$h += $r.GetName($i)}
    $out += ($h -join "|")
    while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|")}
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag44_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
