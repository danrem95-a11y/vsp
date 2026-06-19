Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

$sqlOp = Get-Content 'c:\BTV\debug\qryopname_ap.sql' -Raw

# Run for Dec 2025 - get closing balance
$sqlDec = $sqlOp.Replace(':arg_tgl1', "'2025-12-01'").Replace(':arg_tgl2', "'2025-12-31'")
# Also a per-voucher GL net approach for end of Dec 2025
$sqlGl = @'
SELECT SUM(NET) AS V, COUNT(*) AS C FROM (
  SELECT voucher, SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS NET
  FROM gl_journal
  WHERE account_id='226-001' AND tgl<'2026-01-01'
  GROUP BY voucher
  HAVING ROUND(SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)),2) <> 0
) X
'@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=600

  $cmd.CommandText = $sqlDec
  $r = $cmd.ExecuteReader()
  $rows=0;$sa=[decimal]0;$mut=[decimal]0;$adj=[decimal]0;$byr=[decimal]0;$sisa=[decimal]0
  while ($r.Read()) {
    $rows++
    $sa  += [decimal]$r['SALDO_AWAL_IDR']
    $mut += [decimal]$r['MUTASI_IDR']
    $adj += [decimal]$r['ADJ_IDR']
    $byr += [decimal]$r['NILAI_BAYAR_IDR']
    $sisa+= [decimal]$r['SISA_IDR']
  }
  $r.Close()
  $out += "OPN_DEC2025|ROWS=$rows|SA=$sa|MUTASI=$mut|ADJ=$adj|BAYAR=$byr|SISA=$sisa"

  $cmd.CommandText = $sqlGl
  $r = $cmd.ExecuteReader()
  if ($r.Read()) { $out += "GL_NET_OPEN_PRE2026|V=$($r['V'])|C=$($r['C'])" }
  $r.Close()
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag36_out.txt' -Encoding UTF8
