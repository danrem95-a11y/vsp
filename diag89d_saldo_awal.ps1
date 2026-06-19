$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89d_saldo_awal_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
$conn.Open()

function RunQuery($label, $sql) {
    $output.Add("")
    $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 300
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

# Find tables with 'saldo' in the name
RunQuery "TABLES WITH SALDO IN NAME" @"
SELECT tname FROM SYS.SYSTABLE WHERE tname LIKE '%saldo%' OR tname LIKE '%balance%' OR tname LIKE '%neraca%'
"@

# All tables in the database  
RunQuery "ALL USER TABLES" @"
SELECT tname, creator FROM SYS.SYSTABLE WHERE tabletype='BASE' ORDER BY tname
"@

# Bank entries in December 2025
RunQuery "BANK GL DEC 2025 (kas_id>0)" @"
SELECT account_id, modul_id, kas_id,
       COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit,
       COUNT(*) as cnt
FROM gl_journal
WHERE tgl >= '2025-12-01' AND tgl <= '2025-12-31'
  AND kas_id > 0
GROUP BY account_id, modul_id, kas_id
ORDER BY account_id, modul_id
"@

# Total bank movement Dec 2025
RunQuery "TOTAL BANK DEC 2025 (kas_id>0)" @"
SELECT COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit,
       COALESCE(SUM(debet),0) - COALESCE(SUM(kredit),0) as netto
FROM gl_journal
WHERE tgl >= '2025-12-01' AND tgl <= '2025-12-31' AND kas_id > 0
"@

# All bank GL entries in Nov 2025
RunQuery "TOTAL BANK NOV 2025 (kas_id>0)" @"
SELECT COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit,
       COALESCE(SUM(debet),0) - COALESCE(SUM(kredit),0) as netto
FROM gl_journal
WHERE tgl >= '2025-11-01' AND tgl <= '2025-11-30' AND kas_id > 0
"@

# Cumulative bank balance over all periods (to find when balance first exceeded)
RunQuery "YEARLY BANK BALANCE (per year, kas_id>0)" @"
SELECT DATEPART(year,tgl) as tahun,
       COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit,
       COALESCE(SUM(debet),0) - COALESCE(SUM(kredit),0) as netto
FROM gl_journal
WHERE kas_id > 0
GROUP BY DATEPART(year,tgl)
ORDER BY tahun
"@

# Check if gl_journal has a posting type that indicates opening balance
RunQuery "GL_JOURNAL POSTING TYPES (bank)" @"
SELECT posting, modul_id, COUNT(*) as cnt
FROM gl_journal
WHERE kas_id > 0 AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
GROUP BY posting, modul_id
ORDER BY posting, modul_id
"@

# Look for a saldo/balance entry with no modul_id or special modul_id in Jan 2026
RunQuery "ALL MODUL_ID IN GL_JOURNAL JAN2026 (kas_id>0)" @"
SELECT DISTINCT modul_id, COUNT(*) as cnt,
       COALESCE(SUM(debet),0) as total_debet,
       COALESCE(SUM(kredit),0) as total_kredit
FROM gl_journal
WHERE kas_id > 0 AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
GROUP BY modul_id
"@

# Check Dec 2025 bank CI entries (looking for CI 76.6M)
RunQuery "BANK CI DEC 2025 LARGE DEBET (>10M)" @"
SELECT tgl, account_id, modul_id, kas_id, voucher_manual,
       debet, kredit, ket
FROM gl_journal
WHERE tgl >= '2025-12-01' AND tgl <= '2025-12-31'
  AND kas_id > 0
  AND modul_id = 'CI'
  AND debet > 10000000
ORDER BY debet DESC
"@

# Check all GL bank entries near 76.6M in any period
RunQuery "ANY GL BANK ENTRY NEAR 76,609,999 (ALL DATES)" @"
SELECT tgl, account_id, modul_id, kas_id, voucher, voucher_manual, debet, kredit, ket
FROM gl_journal
WHERE kas_id > 0
  AND (
    (debet IS NOT NULL AND debet > 76000000 AND debet < 77500000)
    OR (kredit IS NOT NULL AND kredit > 76000000 AND kredit < 77500000)
  )
ORDER BY tgl DESC
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
