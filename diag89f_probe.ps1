$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89f_probe_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
try { $conn.Open() } catch { $output.Add("CONN ERROR: $_"); $output | Set-Content $outFile -Encoding UTF8; Write-Host "CONN FAILED"; exit }

function RunQuery($label, $sql) {
    $output.Add("")
    $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand()
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
    } catch { $output.Add("ERROR: $_") }
}

# List tables - try INFORMATION_SCHEMA
RunQuery "ALL TABLES" @"
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME
"@

# Saldo-related tables
RunQuery "TABLES WITH SALDO/AWAL" @"
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE='BASE TABLE'
  AND (TABLE_NAME LIKE '%saldo%' OR TABLE_NAME LIKE '%awal%'
    OR TABLE_NAME LIKE '%neraca%' OR TABLE_NAME LIKE '%balance%')
ORDER BY TABLE_NAME
"@

# Any GL bank entry debet 76-77.5M
RunQuery "GL BANK DEBET 76-77.5M (ALL DATES)" @"
SELECT TOP 30 tgl, account_id, modul_id, kas_id, voucher_manual, debet, ket
FROM gl_journal WHERE kas_id > 0
  AND debet > 76000000 AND debet < 77500000
ORDER BY tgl DESC
"@

# Any GL bank entry kredit 76-77.5M
RunQuery "GL BANK KREDIT 76-77.5M (ALL DATES)" @"
SELECT TOP 30 tgl, account_id, modul_id, kas_id, voucher_manual, kredit, ket
FROM gl_journal WHERE kas_id > 0
  AND kredit > 76000000 AND kredit < 77500000
ORDER BY tgl DESC
"@

# CI entries Dec 2025 (all) sorted by debet desc
RunQuery "DEC2025 BANK CI ALL (sorted desc)" @"
SELECT tgl, account_id, kas_id, voucher_manual, debet, ket
FROM gl_journal
WHERE tgl >= '2025-12-01' AND tgl <= '2025-12-31'
  AND kas_id > 0 AND modul_id = 'CI'
ORDER BY debet DESC
"@

# Dec 2025 orphan CI (no matching tbyr1)  
RunQuery "DEC2025 ORPHAN CI BANK (no tbyr1 AR match)" @"
SELECT g.voucher_manual, g.tgl, g.account_id, g.kas_id, g.debet, g.ket
FROM gl_journal g
WHERE g.tgl >= '2025-12-01' AND g.tgl <= '2025-12-31'
  AND g.modul_id = 'CI' AND g.kas_id > 0
  AND NOT EXISTS (
    SELECT 1 FROM tbyr1 t
    WHERE t.VOUCHER_MANUAL = g.voucher_manual AND t.FLAG_BAYAR = '1'
  )
ORDER BY g.debet DESC
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
