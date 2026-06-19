Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# 1) Search gl_journal for the exact amount 14159923466.61 or close
$sql1 = @'
SELECT TOP 30 voucher, tgl, account_id, kredit, debet, ket, modul_id
FROM gl_journal
WHERE ABS(kredit-14159923466.61) < 1 OR ABS(debet-14159923466.61) < 1
   OR ABS(kredit+debet-14159923466.61) < 1
'@

# 2) Net of 226-001 by year-end Dec 2025 (per voucher) using KREDIT only (original) and full net
$sql2 = @'
SELECT SUM(K) AS KSUM, SUM(D) AS DSUM, SUM(K-D) AS NETSUM, COUNT(*) AS C
FROM (
  SELECT voucher, SUM(ISNULL(kredit,0)) AS K, SUM(ISNULL(debet,0)) AS D
  FROM gl_journal
  WHERE account_id='226-001' AND tgl<'2026-01-01'
  GROUP BY voucher
  HAVING ROUND(SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)),2) <> 0
) X
'@

# 3) Try: AP_TRANS yearly invoices kredit-side (NEW_RATE applied) for Dec 31 carry-over
$sql3 = @'
SELECT
  SUM(TTL_NETTO * ISNULL(NEW_RATE,KURS)) AS NEW_RATE_TOTAL,
  SUM(TTL_NETTO * ISNULL(KURS,1))        AS ORIG_TOTAL,
  COUNT(*) AS C
FROM AP_TRANS
WHERE ORDER_CLIENT IN (
  SELECT DISTINCT BUKTI_ID FROM SALDO_AWAL_FAKTUR
  WHERE TIPE_TRANS IN (1,2)
    AND PERIODE>='2026-01-01' AND PERIODE<'2026-02-01'
)
AND TIPE_TRANS IN ('02','05','06','12','16')
'@

# 4) SAF: also check NEW_SALDO_KURS or other IDR columns we might have missed
$sql4 = @'
SELECT * FROM SALDO_AWAL_FAKTUR
WHERE BUKTI_ID = '101BTB251100051'
  AND PERIODE>='2026-01-01' AND PERIODE<'2026-02-01'
'@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600

  $cmd.CommandText = $sql1
  $r = $cmd.ExecuteReader()
  $out += "=== SEARCH GL FOR 14159923466.61 ==="
  $hdr=@();for($i=0;$i -lt $r.FieldCount;$i++){$hdr += $r.GetName($i)}
  $out += ($hdr -join "|")
  while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|")}
  $r.Close()

  foreach($p in @(@('GL_NET_PRE2026_ALL',$sql2),@('AP_TRANS_NEW_RATE',$sql3))){
    $cmd.CommandText = $p[1]; $r = $cmd.ExecuteReader()
    if($r.Read()){
      $line=$p[0]
      for($i=0;$i -lt $r.FieldCount;$i++){$line += "|"+$r.GetName($i)+"="+$r.GetValue($i)}
      $out += $line
    }
    $r.Close()
  }

  $cmd.CommandText = $sql4
  $r = $cmd.ExecuteReader()
  $out += "=== SAF FULL COLUMNS for 251100051 CNY ==="
  $hdr=@();for($i=0;$i -lt $r.FieldCount;$i++){$hdr += $r.GetName($i)}
  $out += ($hdr -join "|")
  while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|")}
  $r.Close()
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag41_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
