$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89i_final_verify_out.txt'
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
            $vals=@(); for($i=0;$i -lt $rdr.FieldCount;$i++){$v=$rdr.GetValue($i);if($v -is [System.DBNull]){$v='(null)'};$vals+=$v}
            $output.Add(($vals -join "`t")); $cnt++
        }
        $rdr.Close(); $output.Add("($cnt rows)")
    } catch { $output.Add("ERROR: $_") }
}

# VERIFY: BANK (BS2011) saldo Jan31,2026 - should be 4,376,042,817
RunQuery "BANK SALDO JAN31 2026 - BS2011 ONLY" @"
SELECT
  SUM(COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0)) as opening_bank,
  SUM(COALESCE(
    (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
     FROM gl_journal g
     WHERE g.account_id = a.AccountCode
       AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
  )) as movement_jan,
  SUM(
    (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
    + COALESCE(
        (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
         FROM gl_journal g
         WHERE g.account_id = a.AccountCode
           AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
    )
  ) as total_saldo_bank_jan31
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode = 'BS2011'
  AND a.DetailYN = '1'
"@

# VERIFY: KAS (BS2010) saldo Jan31,2026
RunQuery "KAS SALDO JAN31 2026 - BS2010 ONLY" @"
SELECT
  SUM(COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0)) as opening_kas,
  SUM(COALESCE(
    (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
     FROM gl_journal g
     WHERE g.account_id = a.AccountCode
       AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
  )) as movement_jan,
  SUM(
    (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
    + COALESCE(
        (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
         FROM gl_journal g
         WHERE g.account_id = a.AccountCode
           AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
    )
  ) as total_saldo_kas_jan31
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode = 'BS2010'
  AND a.DetailYN = '1'
"@

# Breakdown BS2011 per account
RunQuery "BS2011 BANK PER ACCOUNT JAN31 2026" @"
SELECT a.AccountCode, a.AccountDes,
       COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0) as saldo_awal,
       COALESCE(
           (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
            FROM gl_journal g
            WHERE g.account_id = a.AccountCode
              AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
       ) as movement,
       (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
       + COALESCE(
           (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
            FROM gl_journal g
            WHERE g.account_id = a.AccountCode
              AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
       ) as saldo_jan31
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode = 'BS2011' AND a.DetailYN = '1'
ORDER BY a.AccountCode
"@

# Check what 4,452,652,816.79 could come from - try without deposito
RunQuery "BANK SALDO WITHOUT DEPOSITO (101-201)" @"
SELECT
  SUM(
    (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
    + COALESCE(
        (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
         FROM gl_journal g
         WHERE g.account_id = a.AccountCode
           AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
    )
  ) as saldo
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode = 'BS2011' AND a.DetailYN = '1'
  AND a.AccountCode NOT IN ('101-201','101-202','101-300')
"@

# Check PIUTANG LAIN PEMEGANG SAHAM (BS2032) opening balance
RunQuery "PIUTANG LAIN PEMEGANG SAHAM (BS2032) Jan31 balance" @"
SELECT a.AccountCode, a.AccountDes,
       COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0) as saldo_awal,
       COALESCE(
           (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
            FROM gl_journal g
            WHERE g.account_id = a.AccountCode
              AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
       ) as movement_jan,
       (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
       + COALESCE(
           (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
            FROM gl_journal g
            WHERE g.account_id = a.AccountCode
              AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
       ) as saldo_jan31
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode = 'BS2032' AND a.DetailYN = '1'
  AND (COALESCE(gb.AmountDebet,0) > 0 OR EXISTS (
    SELECT 1 FROM gl_journal g
    WHERE g.account_id = a.AccountCode AND g.tgl >= '2026-01-01'))
ORDER BY a.AccountCode
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
