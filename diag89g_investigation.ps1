$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89g_investigation_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
try { $conn.Open() } catch { "CONN ERROR: $_" | Set-Content $outFile; exit }

function RunQuery($label, $sql) {
    $output.Add(""); $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
        $rdr = $cmd.ExecuteReader()
        $cols = @(); for($i=0;$i -lt $rdr.FieldCount;$i++){$cols+=$rdr.GetName($i)}
        $output.Add(($cols -join "`t")); $output.Add(("-"*60))
        $cnt=0
        while($rdr.Read()){
            $vals=@()
            for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t")); $cnt++
        }
        $rdr.Close(); $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# gl_acc - actual account master
RunQuery "gl_acc BANK/KAS ACCOUNTS" @"
SELECT AccountCode, AccountDes, FinCatCode, AccType, DetailYN, DebetCredit
FROM gl_acc
WHERE AccountCode LIKE '10%'
ORDER BY AccountCode
"@

RunQuery "gl_acc KAS AND BANK (FinCatCode)" @"
SELECT AccountCode, AccountDes, FinCatCode, DetailYN, DebetCredit
FROM gl_acc
WHERE FinCatCode IN ('BS2010','BS2011')
ORDER BY FinCatCode, AccountCode
"@

# Full bank saldo using gl_acc for account categorization
RunQuery "BANK SALDO JAN2026: gl_balance + gl_journal (via gl_acc)" @"
SELECT a.AccountCode, a.AccountDes, a.FinCatCode,
       COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0) as saldo_awal,
       COALESCE(
           (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
            FROM gl_journal
            WHERE account_id = a.AccountCode
              AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'), 0
       ) as movement,
       (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
       + COALESCE(
           (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
            FROM gl_journal
            WHERE account_id = a.AccountCode
              AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'), 0
       ) as saldo_akhir
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode IN ('BS2010','BS2011')
  AND a.DetailYN = 'Y'
ORDER BY a.FinCatCode, a.AccountCode
"@

RunQuery "TOTAL BANK SALDO JAN2026 (sum from gl_acc BS2010+BS2011)" @"
SELECT SUM(
    (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
    + COALESCE(
        (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
         FROM gl_journal
         WHERE account_id = a.AccountCode
           AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'), 0
    )
) as total_bank_saldo
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode IN ('BS2010','BS2011')
  AND a.DetailYN = 'Y'
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
