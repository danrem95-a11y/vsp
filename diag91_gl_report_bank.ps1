$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag91_gl_report_bank_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
try { $conn.Open() } catch { "CONN ERROR: $_" | Set-Content $outFile; exit }

function RunQuery($label, $sql) {
    $output.Add(""); $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t")); $output.Add(("-"*80))
        $cnt=0
        while($rdr.Read()){
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t")); $cnt++
        }
        $rdr.Close(); $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# 1. Show all columns in gl_report table
RunQuery "gl_report table structure" @"
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_DEFAULT
FROM SYS.SYSCOLUMNS
WHERE TABLE_NAME = 'GL_REPORT'
ORDER BY column_id
"@

# 2. Show gl_report rows for Balance Sheet (report '02')
RunQuery "gl_report rows for Balance Sheet (report_id=02)" @"
SELECT * FROM gl_report
WHERE REPORT_ID = '02'
ORDER BY seq_id
"@

# 3. Also check gl_report for BANK pattern - what account_id is used for BANK line
RunQuery "gl_report all rows" @"
SELECT * FROM gl_report
ORDER BY report_id, seq_id
"@

# 4. Now simulate ds_coa_saldo: what BANK line account_id pattern yields
# The manual code does: lds_saldo2.Retrieve(ii_bulan, ii_tahun, gs_site, ls_account+'%')
# For BANK the gl_report row probably has account_id like '101'
# ds_coa_saldo computes YTD balance by account pattern
# Let's check what account IDs match the BANK pattern from gl_report (probably '101%')
RunQuery "Accounts matching 101% with saldo Jan 2026" @"
SELECT a.AccountCode, a.AccountDes, a.FinCatCode,
       ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0) as opening,
       ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0) as movement,
       (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
       + ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0) as saldo
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode=a.AccountCode AND gb.Period='2026-01-01'
WHERE a.AccountCode LIKE '101%'
  AND a.DetailYN='1'
ORDER BY a.AccountCode
"@

# 5. Accounts matching 10% (100+101) - would include KAS too
RunQuery "Accounts matching 10% with saldo Jan 2026" @"
SELECT a.AccountCode, a.AccountDes, a.FinCatCode,
       (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
       + ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0) as saldo
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode=a.AccountCode AND gb.Period='2026-01-01'
WHERE a.AccountCode LIKE '10%'
  AND a.DetailYN='1'
ORDER BY a.AccountCode
"@

# 6. Check ds_coa_saldo - this datastore might be stored in DB as a view or table
RunQuery "SYS tables - any coa_saldo" @"
SELECT table_name, table_type
FROM SYS.SYSTABLE
WHERE table_name LIKE '%saldo%' OR table_name LIKE '%coa%' OR table_name LIKE '%neraca%'
ORDER BY table_type, table_name
"@

# 7. KEY QUESTION: What is 4,452,652,816.79 - 4,376,042,816.79 = 76,610,000
# Check if gl_report BANK entry includes pattern that captures account with 76.6M saldo
# Try range: 9,877,350 (KAS) + 76,610,000 = 86,487,350 -- does the bank row include both?
# Or maybe 4,376,042,816.79 + 76,610,000 = 4,452,652,816.79
# Let's check what account has saldo exactly 76,610,000
RunQuery "Account with saldo exactly between 75M-78M (all accounts)" @"
SELECT a.AccountCode, a.AccountDes, a.FinCatCode,
       (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
       + ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0) as saldo
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode=a.AccountCode AND gb.Period='2026-01-01'
WHERE a.DetailYN='1'
  AND ABS(
    (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
    + ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0)
  ) BETWEEN 50000000 AND 100000000
ORDER BY saldo
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
