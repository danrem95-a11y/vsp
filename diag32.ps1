Add-Type -AssemblyName System.Data

$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()

$out = @()

# 1. Ledger 226-001 opening balance as of 2026-01-01 (cumulative net credit before 2026)
$sql1 = @'
SELECT SUM(ISNULL(kredit,0)) AS K, SUM(ISNULL(debet,0)) AS D,
       SUM(ISNULL(kredit,0)) - SUM(ISNULL(debet,0)) AS SA
FROM gl_journal
WHERE account_id = '226-001'
  AND tgl < '2026-01-01'
'@

# 2. Ledger 226-001 movement during Jan 2026
$sql2 = @'
SELECT SUM(ISNULL(kredit,0)) AS K, SUM(ISNULL(debet,0)) AS D
FROM gl_journal
WHERE account_id = '226-001'
  AND tgl >= '2026-01-01' AND tgl < '2026-02-01'
'@

# 3. Current qryopname totals
$sqlOp = Get-Content 'c:\BTV\debug\qryopname_ap.sql' -Raw
$sqlOp = $sqlOp.Replace(':arg_tgl1', "'2026-01-01'").Replace(':arg_tgl2', "'2026-01-31'")

try {
    $cmd = $con.CreateCommand()
    $cmd.CommandTimeout = 300

    $cmd.CommandText = $sql1
    $r = $cmd.ExecuteReader()
    if ($r.Read()) { $out += "LEDGER_PRE2026|K=$($r['K'])|D=$($r['D'])|SA=$($r['SA'])" }
    $r.Close()

    $cmd.CommandText = $sql2
    $r = $cmd.ExecuteReader()
    if ($r.Read()) { $out += "LEDGER_JAN2026|K=$($r['K'])|D=$($r['D'])" }
    $r.Close()

    $cmd.CommandText = $sqlOp
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
    $out += "OPNAME|ROWS=$rows|SA=$sa|MUTASI=$mut|ADJ=$adj|BAYAR=$byr|SISA=$sisa"
}
finally { $con.Close() }

$out | Out-File 'c:\BTV\debug\diag32_out.txt' -Encoding UTF8
