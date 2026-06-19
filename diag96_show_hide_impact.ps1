$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag96_show_hide_impact_out.txt'
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

# 1. Check what accounts in v_neraca have show_hide = '0' or NULL
# These would be excluded when arg_show is NULL
RunQuery "v_neraca BANK accounts with show_hide" @"
SELECT v.AccountCode, v.AccountDes, v.show_hide
FROM v_neraca v
WHERE v.fincatcode = 'BS2011'
ORDER BY v.AccountCode
"@

# 2. Compute bank total WITH show_hide filter (simulating arg_show=NULL)
# i.e. only where show_hide = '1'
RunQuery "BANK total with show_hide filter (arg_show NULL - only show_hide=1)" @"
SELECT SUM(
    (ISNULL(AWAL.AmountDebet, 0) - ISNULL(AWAL.AmountCredit, 0)
    + ISNULL((SELECT SUM(g2.debet) - SUM(g2.kredit) 
              FROM gl_journal g2 
              WHERE g2.account_id = a.AccountCode 
                AND g2.tgl >= '2025-01-01' 
                AND g2.tgl < '2026-01-01'), 0))
    * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END
) as clalu11,
SUM(
    (ISNULL((SELECT SUM(g3.debet) - SUM(g3.kredit) 
             FROM gl_journal g3 
             WHERE g3.account_id = a.AccountCode 
               AND g3.tgl >= '2026-01-01' 
               AND g3.tgl <= '2026-01-31'), 0))
    * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END
) as mutasi,
SUM(
    (ISNULL(AWAL.AmountDebet, 0) - ISNULL(AWAL.AmountCredit, 0)
    + ISNULL((SELECT SUM(g2.debet) - SUM(g2.kredit) 
              FROM gl_journal g2 
              WHERE g2.account_id = a.AccountCode 
                AND g2.tgl >= '2025-01-01' 
                AND g2.tgl < '2026-01-01'), 0)
    + ISNULL((SELECT SUM(g3.debet) - SUM(g3.kredit) 
              FROM gl_journal g3 
              WHERE g3.account_id = a.AccountCode 
                AND g3.tgl >= '2026-01-01' 
                AND g3.tgl <= '2026-01-31'), 0))
    * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END
) as cakhir11_total
FROM v_neraca v
JOIN gl_acc a ON a.AccountCode = v.AccountCode
LEFT JOIN gl_balance AWAL ON AWAL.AccountCode = a.AccountCode AND AWAL.Period = '2026-01-01'
WHERE v.fincatcode = 'BS2011'
  AND v.show_hide = '1'
"@

# 3. Compute bank total WITHOUT show_hide filter (arg_show = 1, include everything)
RunQuery "BANK total without show_hide filter (arg_show=1 - all)" @"
SELECT SUM(
    (ISNULL(AWAL.AmountDebet, 0) - ISNULL(AWAL.AmountCredit, 0)
    + ISNULL((SELECT SUM(g2.debet) - SUM(g2.kredit) 
              FROM gl_journal g2 
              WHERE g2.account_id = a.AccountCode 
                AND g2.tgl >= '2025-01-01' 
                AND g2.tgl < '2026-01-01'), 0))
    * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END
) as clalu11,
SUM(
    (ISNULL((SELECT SUM(g3.debet) - SUM(g3.kredit) 
             FROM gl_journal g3 
             WHERE g3.account_id = a.AccountCode 
               AND g3.tgl >= '2026-01-01' 
               AND g3.tgl <= '2026-01-31'), 0))
    * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END
) as mutasi,
SUM(
    (ISNULL(AWAL.AmountDebet, 0) - ISNULL(AWAL.AmountCredit, 0)
    + ISNULL((SELECT SUM(g2.debet) - SUM(g2.kredit) 
              FROM gl_journal g2 
              WHERE g2.account_id = a.AccountCode 
                AND g2.tgl >= '2025-01-01' 
                AND g2.tgl < '2026-01-01'), 0)
    + ISNULL((SELECT SUM(g3.debet) - SUM(g3.kredit) 
              FROM gl_journal g3 
              WHERE g3.account_id = a.AccountCode 
                AND g3.tgl >= '2026-01-01' 
                AND g3.tgl <= '2026-01-31'), 0))
    * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END
) as cakhir11_total
FROM v_neraca v
JOIN gl_acc a ON a.AccountCode = v.AccountCode
LEFT JOIN gl_balance AWAL ON AWAL.AccountCode = a.AccountCode AND AWAL.Period = '2026-01-01'
WHERE v.fincatcode = 'BS2011'
"@

# 4. Show the difference per account (show_hide=0 accounts that have balances)
RunQuery "BANK accounts with show_hide=0 that have non-zero balances" @"
SELECT a.AccountCode, a.AccountDes, v.show_hide,
       ISNULL(AWAL.AmountDebet, 0) - ISNULL(AWAL.AmountCredit, 0) as opening,
       ISNULL((SELECT SUM(g3.debet) - SUM(g3.kredit) 
               FROM gl_journal g3 
               WHERE g3.account_id = a.AccountCode 
                 AND g3.tgl >= '2026-01-01' AND g3.tgl <= '2026-01-31'), 0) as jan_movement,
       (ISNULL(AWAL.AmountDebet, 0) - ISNULL(AWAL.AmountCredit, 0) +
        ISNULL((SELECT SUM(g3.debet) - SUM(g3.kredit) 
                FROM gl_journal g3 
                WHERE g3.account_id = a.AccountCode 
                  AND g3.tgl >= '2026-01-01' AND g3.tgl <= '2026-01-31'), 0)) 
       * CASE WHEN a.DebetCredit = 'D' THEN 1 ELSE -1 END as saldo_jan31
FROM v_neraca v
JOIN gl_acc a ON a.AccountCode = v.AccountCode
LEFT JOIN gl_balance AWAL ON AWAL.AccountCode = a.AccountCode AND AWAL.Period = '2026-01-01'
WHERE v.fincatcode = 'BS2011'
  AND (v.show_hide IS NULL OR v.show_hide <> '1')
ORDER BY a.AccountCode
"@

# 5. Check the actual v_neraca view definition - what is show_hide column?
RunQuery "v_neraca view columns" @"
SELECT c.column_name
FROM SYS.SYSCOLUMNS c
JOIN SYS.SYSTABLE t ON t.table_id = c.table_id
WHERE t.table_name = 'V_NERACA'
ORDER BY c.column_id
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
