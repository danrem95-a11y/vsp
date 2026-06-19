$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag89h_bank_final_out.txt'
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

# The correct DetailYN filter is '1' not 'Y'
RunQuery "BANK SALDO JAN2026 PER ACCOUNT (DetailYN=1)" @"
SELECT a.AccountCode, a.AccountDes, a.FinCatCode,
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
WHERE a.FinCatCode IN ('BS2010','BS2011')
  AND a.DetailYN = '1'
ORDER BY a.FinCatCode, a.AccountCode
"@

RunQuery "TOTAL BANK SALDO JAN2026 (BS2010+BS2011, DetailYN=1)" @"
SELECT
  SUM(COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0)) as total_opening_1jan,
  SUM(COALESCE(
    (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
     FROM gl_journal g
     WHERE g.account_id = a.AccountCode
       AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
  )) as total_movement_jan,
  SUM(
    (COALESCE(gb.AmountDebet,0) - COALESCE(gb.AmountCredit,0))
    + COALESCE(
        (SELECT SUM(COALESCE(debet,0)) - SUM(COALESCE(kredit,0))
         FROM gl_journal g
         WHERE g.account_id = a.AccountCode
           AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0
    )
  ) as total_saldo_jan31
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE a.FinCatCode IN ('BS2010','BS2011')
  AND a.DetailYN = '1'
"@

# Check gl_balance(1/1/2026) for 101-201 (Deposito BCA)
RunQuery "gl_balance 1/1/2026 for 101-201 and 101-202" @"
SELECT Period, AccountCode, AmountDebet, AmountCredit
FROM gl_balance
WHERE Period = '2026-01-01'
  AND AccountCode IN ('101-201','101-202','101-300')
"@

# Compare with expected 4,376,042,817.00
# If system shows 4,452,652,816.79 (76.6M more), find the difference
# Expected: 4,376,042,817.00
# System:   4,452,652,816.79
# Diff:        76,609,999.79 (system TOO HIGH)

# Check which specific account or movement causes the 76.6M excess
# The gl_balance opening values are the main candidates

# What if gl_balance(1/1/2026) for 101-201 or 101-202 has an error?
RunQuery "gl_balance ALL PERIODS FOR 101-201 AND 101-202" @"
SELECT Period, AccountCode, AmountDebet, AmountCredit
FROM gl_balance
WHERE AccountCode IN ('101-201','101-202')
ORDER BY AccountCode, Period
"@

# Check Jan 2026 orphan AR receipts more carefully
# Does TBYR1 FLAG_BAYAR='1' Jan2026 have matching tbyr2?
RunQuery "TBYR1 AR JAN2026 WITH VOUCHER_MANUAL AND AMOUNT" @"
SELECT t1.VOUCHER, t1.TGL, t1.VOUCHER_MANUAL, t1.KETERANGAN,
       CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) as jml_bayar_idr
FROM tbyr1 t1
LEFT JOIN tbyr2 t2 ON t2.VOUCHER = t1.VOUCHER
WHERE t1.FLAG_BAYAR = '1'
  AND t1.TGL >= '2026-01-01' AND t1.TGL <= '2026-01-31'
GROUP BY t1.VOUCHER, t1.TGL, t1.VOUCHER_MANUAL, t1.KETERANGAN
ORDER BY t1.TGL, t1.VOUCHER
"@

# Cross-check: AR tbyr1 Jan2026 vs GL CI journal (by voucher_manual)
RunQuery "AR RECEIPTS IN TBYR1 JAN2026 BUT GL_CI DEBET DIFFERS" @"
SELECT t1.VOUCHER_MANUAL,
       t1.TGL,
       t1.KETERANGAN,
       CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) as tbyr2_amount,
       CAST(
           (SELECT SUM(COALESCE(debet,0))
            FROM gl_journal g
            WHERE g.voucher_manual = t1.VOUCHER_MANUAL
              AND g.kas_id > 0 AND g.modul_id = 'CI') AS DECIMAL(18,2)
       ) as gl_ci_debet,
       CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) -
       CAST(
           (SELECT SUM(COALESCE(debet,0))
            FROM gl_journal g
            WHERE g.voucher_manual = t1.VOUCHER_MANUAL
              AND g.kas_id > 0 AND g.modul_id = 'CI') AS DECIMAL(18,2)
       ) as selisih
FROM tbyr1 t1
LEFT JOIN tbyr2 t2 ON t2.VOUCHER = t1.VOUCHER
WHERE t1.FLAG_BAYAR = '1'
  AND t1.TGL >= '2026-01-01' AND t1.TGL <= '2026-01-31'
GROUP BY t1.VOUCHER_MANUAL, t1.TGL, t1.KETERANGAN
HAVING ABS(
    CAST(SUM(t2.NILAI_BAYAR_IDR) AS DECIMAL(18,2)) -
    CAST(
        (SELECT SUM(COALESCE(debet,0))
         FROM gl_journal g
         WHERE g.voucher_manual = t1.VOUCHER_MANUAL
           AND g.kas_id > 0 AND g.modul_id = 'CI') AS DECIMAL(18,2)
    )
) > 1
ORDER BY ABS(selisih) DESC
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
