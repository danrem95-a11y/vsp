$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89e_tables_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

function NewConn {
    $c = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
    $c.Open()
    return $c
}

function RunQuery($label, $sql) {
    $output.Add("")
    $output.Add("===== $label =====")
    $conn2 = NewConn
    try {
        $cmd = $conn2.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 120
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t"))
        $output.Add(("-"*60))
        $cnt=0
        while($rdr.Read()){
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t"))
            $cnt++
        }
        $rdr.Close()
        $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") } finally { $conn2.Close() }
}

# List all user tables
RunQuery "ALL TABLES (INFORMATION_SCHEMA)" @"
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE'
ORDER BY TABLE_NAME
"@

# Find saldo/balance tables
RunQuery "TABLES WITH SALDO/BALANCE IN NAME" @"
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE'
  AND (TABLE_NAME LIKE '%saldo%' OR TABLE_NAME LIKE '%balance%'
    OR TABLE_NAME LIKE '%neraca%' OR TABLE_NAME LIKE '%opening%'
    OR TABLE_NAME LIKE '%opname%' OR TABLE_NAME LIKE '%awal%')
ORDER BY TABLE_NAME
"@

# Any GL bank entry near 76.6M (all years, part 1)
RunQuery "GL BANK DEBET 76-77.5M (ALL DATES)" @"
SELECT TOP 50 tgl, account_id, modul_id, kas_id, voucher, voucher_manual, debet, kredit, ket
FROM gl_journal
WHERE kas_id > 0
  AND debet IS NOT NULL AND debet > 76000000 AND debet < 77500000
ORDER BY tgl DESC
"@

# Any GL bank entry near 76.6M kredit (all years)
RunQuery "GL BANK KREDIT 76-77.5M (ALL DATES)" @"
SELECT TOP 50 tgl, account_id, modul_id, kas_id, voucher, voucher_manual, debet, kredit, ket
FROM gl_journal
WHERE kas_id > 0
  AND kredit IS NOT NULL AND kredit > 76000000 AND kredit < 77500000
ORDER BY tgl DESC
"@

# Dec 2025 CI bank (AR receipts) large amounts
RunQuery "DEC 2025 BANK CI DEBET (all, sorted)" @"
SELECT tgl, account_id, kas_id, voucher_manual, debet, ket
FROM gl_journal
WHERE tgl >= '2025-12-01' AND tgl <= '2025-12-31'
  AND kas_id > 0 AND modul_id = 'CI'
ORDER BY debet DESC
"@

# Dec 2025 orphan CI (no matching tbyr1)
RunQuery "DEC2025 ORPHAN CI BANK (no matching tbyr1 AR)" @"
SELECT g.voucher_manual, g.tgl, g.account_id, g.kas_id,
       g.debet, g.ket
FROM gl_journal g
WHERE g.tgl >= '2025-12-01' AND g.tgl <= '2025-12-31'
  AND g.modul_id = 'CI' AND g.kas_id > 0
  AND NOT EXISTS (
    SELECT 1 FROM tbyr1 t
    WHERE t.VOUCHER_MANUAL = g.voucher_manual AND t.FLAG_BAYAR = '1'
  )
ORDER BY g.tgl, g.debet DESC
"@

# Check if there are duplicate entries: same voucher_manual CI in both Dec2025 and Jan2026
RunQuery "CI BANK ENTRIES APPEAR IN BOTH DEC2025 AND JAN2026" @"
SELECT g1.voucher_manual, g1.tgl as tgl_dec, g2.tgl as tgl_jan,
       g1.debet as debet_dec, g2.debet as debet_jan, g1.ket
FROM gl_journal g1
JOIN gl_journal g2 ON g1.voucher_manual = g2.voucher_manual
WHERE g1.tgl >= '2025-12-01' AND g1.tgl <= '2025-12-31'
  AND g2.tgl >= '2026-01-01' AND g2.tgl <= '2026-01-31'
  AND g1.kas_id > 0 AND g2.kas_id > 0
  AND g1.modul_id = 'CI' AND g2.modul_id = 'CI'
ORDER BY g1.debet DESC
"@

$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
