$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag90_neraca_bank_out.txt'
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

# 1. Show v_neraca view definition
RunQuery "VIEW DEFINITION: v_neraca" @"
SELECT view_def
FROM SYS.SYSVIEWS
WHERE view_name = 'V_NERACA'
"@

# 2. Show all accounts with their fincatcode from v_neraca
RunQuery "v_neraca accounts (BANK/KAS related)" @"
SELECT group_id, group_name, subgroup_id, subgroup_name, fincatcode, fincatdes, accountcode, accountdes, flag_dk, show_hide
FROM v_neraca
WHERE fincatcode IN ('BS2010','BS2011')
ORDER BY fincatcode, accountcode
"@

# 3. What fincatcode maps to BANK in gl_cate / gl_report
RunQuery "gl_cate - BANK categories" @"
SELECT * FROM gl_cate
WHERE FinCatCode LIKE 'BS201%'
ORDER BY FinCatCode
"@

# 4. Direct check: what accounts in gl_acc have fincatcode like BS201x but are WRONG
RunQuery "gl_acc BS2010/BS2011 accounts vs v_neraca" @"
SELECT a.AccountCode, a.AccountDes, a.FinCatCode,
       v.fincatcode as v_neraca_fincatcode
FROM gl_acc a
LEFT JOIN v_neraca v ON v.accountcode = a.AccountCode
WHERE a.FinCatCode IN ('BS2010','BS2011')
  AND a.DetailYN = '1'
ORDER BY a.AccountCode
"@

# 5. THE KEY QUERY: Same as balance sheet SQL, but filtered to BANK (BS2011)
# Args: arg_tgl1=2026-01-01, arg_tgl2=2025-12-31, arg_tgl3=2026-01-01, arg_tgl4=2026-01-31, arg_show=0
RunQuery "BALANCE SHEET QUERY - accounts in BANK (BS2011) from v_neraca" @"
SELECT a.fincatcode, a.fincatdes, a.accountcode, a.accountdes, a.flag_dk,
       ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0) as opening_bal,
       ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0) as mutasi_net,
       (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0)
        + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)
       ) * CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END as saldo_jan31
FROM v_neraca a
LEFT JOIN (
    SELECT GL_BALANCE.ACCOUNTCODE,
           SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
    FROM GL_BALANCE
    WHERE GL_BALANCE.PERIOD = '2026-01-01'
    GROUP BY GL_BALANCE.ACCOUNTCODE
) AWAL ON a.ACCOUNTCODE = AWAL.ACCOUNTCODE
LEFT JOIN (
    SELECT GL_JOURNAL.ACCOUNT_ID,
           SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
    FROM GL_JOURNAL
    WHERE GL_JOURNAL.TGL BETWEEN '2026-01-01' AND '2026-01-31'
      AND (ISNULL(gl_journal.show_hide,'1') = '1')
    GROUP BY GL_JOURNAL.ACCOUNT_ID
) MUTASI ON a.ACCOUNTCODE = MUTASI.ACCOUNT_ID
WHERE a.fincatcode = 'BS2011'
  AND (ISNULL(a.show_hide,'1') = '1')
ORDER BY a.accountcode
"@

# 6. What the balance sheet TOTAL shows for BANK (sum cakhir11 for group=BS2011)
RunQuery "TOTAL BANK saldo per balance sheet logic (v_neraca accounts)" @"
SELECT a.fincatcode, a.fincatdes,
       SUM((ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0)
            + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)
           ) * CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END) as total_saldo_jan31
FROM v_neraca a
LEFT JOIN (
    SELECT GL_BALANCE.ACCOUNTCODE,
           SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
    FROM GL_BALANCE
    WHERE GL_BALANCE.PERIOD = '2026-01-01'
    GROUP BY GL_BALANCE.ACCOUNTCODE
) AWAL ON a.ACCOUNTCODE = AWAL.ACCOUNTCODE
LEFT JOIN (
    SELECT GL_JOURNAL.ACCOUNT_ID,
           SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
    FROM GL_JOURNAL
    WHERE GL_JOURNAL.TGL BETWEEN '2026-01-01' AND '2026-01-31'
      AND (ISNULL(gl_journal.show_hide,'1') = '1')
    GROUP BY GL_JOURNAL.ACCOUNT_ID
) MUTASI ON a.ACCOUNTCODE = MUTASI.ACCOUNT_ID
WHERE (ISNULL(a.show_hide,'1') = '1')
GROUP BY a.fincatcode, a.fincatdes
ORDER BY a.fincatcode
"@

# 7. Check if there are accounts in v_neraca with fincatcode=BS2011 that are NOT in gl_acc FinCatCode=BS2011
RunQuery "v_neraca BS2011 accounts NOT in gl_acc as BS2011" @"
SELECT v.accountcode, v.accountdes, v.fincatcode as v_fincatcode,
       a.FinCatCode as gl_acc_fincatcode
FROM v_neraca v
LEFT JOIN gl_acc a ON a.AccountCode = v.accountcode
WHERE v.fincatcode = 'BS2011'
  AND (a.FinCatCode IS NULL OR a.FinCatCode <> 'BS2011')
ORDER BY v.accountcode
"@

# 8. Show the EXACT difference: 4,452,652,816.79 - 4,376,042,816.79 = 76,610,000
# Find accounts with saldo ≈ 76,610,000
RunQuery "All accounts with |saldo| approx 76.6M" @"
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
WHERE a.DetailYN='1'
  AND ABS(
    (ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
    + ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0)
  ) BETWEEN 70000000 AND 83000000
ORDER BY ABS((ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
    + ISNULL((SELECT SUM(COALESCE(debet,0))-SUM(COALESCE(kredit,0))
               FROM gl_journal g
               WHERE g.account_id=a.AccountCode
                 AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0))
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
