$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag100_dp_root_cause_out.txt'
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

# 1. Check what category/fincatcode account 103-001 belongs to
RunQuery "gl_acc for 103-xxx accounts" @"
SELECT AccountCode, AccountDes, FinCatCode, DetailYN, DebetCredit, ParentCode
FROM gl_acc
WHERE AccountCode LIKE '103%'
ORDER BY AccountCode
"@

# 2. Check v_neraca for 103-001 - is it mapped to BANK or PIUTANG?
RunQuery "v_neraca for 103-001" @"
SELECT group_id, group_name, subgroup_id, subgroup_name, fincatcode, fincatdes, parentcode, parentname, accountcode, accountdes, flag_dk, show_hide
FROM v_neraca
WHERE accountcode LIKE '103%' OR parentcode LIKE '103%'
ORDER BY accountcode
"@

# 3. gl_cate - what is BS2011 and what FinCatCode does piutang use?
RunQuery "gl_cate codes (balance sheet categories)" @"
SELECT FinCatCode, FinCatDes
FROM gl_cate
WHERE FinCatCode LIKE 'BS%'
ORDER BY FinCatCode
"@

# 4. Check gl_acc FinCatCode for 103-001 AND what fincatcode BANK accounts (101-xxx) use
RunQuery "FinCatCode comparison 101-xxx vs 103-xxx" @"
SELECT LEFT(AccountCode,3) as acc_prefix, FinCatCode, COUNT(*) as cnt
FROM gl_acc
WHERE AccountCode LIKE '10%' AND DetailYN='1'
GROUP BY LEFT(AccountCode,3), FinCatCode
ORDER BY acc_prefix
"@

# 5. Check tdp table structure
RunQuery "tdp table all columns and rows (limit 20)" @"
SELECT TOP 20 *
FROM tdp
ORDER BY 1 DESC
"@

# 6. Check if AR refresh (f_transfer_ar) created wrong bank entries for DP vouchers
# Look for CI/AR modul_id entries dated same as DPs with bank debit
RunQuery "CI modul bank entries Jan 6 2026 (2601DPR001 date)" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE tgl = '2026-01-06'
  AND account_id LIKE '101%'
ORDER BY voucher
"@

RunQuery "All GL entries Jan 6 2026 for DP-related voucher 2601DPR001" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE tgl = '2026-01-06'
  AND (voucher_manual LIKE '%2601DPR%' OR voucher_manual LIKE '%DPR00%' OR ket LIKE '%ANUGERAH MITRA%')
ORDER BY voucher, account_id
"@

# 7. All GL entries Jan 22, 2026 for EAT MORE (2602DPR001/002 date)
RunQuery "All GL entries Jan 22 2026 EAT MORE or 2602DPR" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE tgl = '2026-01-22'
  AND (ket LIKE '%EAT MORE%' OR voucher_manual LIKE '%2602DP%' OR ket LIKE '%2602DPR%')
ORDER BY voucher, account_id
"@

# 8. Check if there are ANY bank GL entries where the corresponding 228 entry is missing
# (i.e., bank Dr WITHOUT a proper 228/piutang offset - sign of wrong DP processing)
RunQuery "Bank debit entries in Jan 2026 where NO matching AR/piutang kredit same voucher" @"
SELECT DISTINCT gj.tgl, gj.voucher, gj.voucher_manual, gj.account_id, gj.debet, gj.ket, gj.modul_id
FROM gl_journal gj
WHERE gj.account_id LIKE '101%'
  AND gj.debet > 0
  AND gj.tgl >= '2026-01-01' AND gj.tgl <= '2026-01-31'
  AND NOT EXISTS (
    SELECT 1 FROM gl_journal gj2
    WHERE gj2.voucher_manual = gj.voucher_manual
      AND gj2.account_id LIKE '10[234]%'
      AND gj2.kredit > 0
  )
ORDER BY gj.tgl, gj.voucher
"@

# 9. Check SUM of bank (101) per modul_id in Jan 2026
RunQuery "Bank 101-xxx net per modul_id Jan 2026" @"
SELECT modul_id, COUNT(*) as cnt,
       SUM(debet) as total_debet, SUM(kredit) as total_kredit,
       SUM(debet)-SUM(kredit) as net
FROM gl_journal
WHERE account_id LIKE '101%'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
GROUP BY modul_id
ORDER BY modul_id
"@

# 10. Check what the CORRECT bank total should be using gl_balance + Jan movements
RunQuery "Bank total calculation step by step" @"
SELECT
  (SELECT SUM(AmountDebet - AmountCredit) FROM gl_balance WHERE AccountCode LIKE '101%' AND Period = '2026-01-01') as opening_balance,
  (SELECT SUM(debet) FROM gl_journal WHERE account_id LIKE '101%' AND tgl >= '2026-01-01' AND tgl <= '2026-01-31') as jan_debet,
  (SELECT SUM(kredit) FROM gl_journal WHERE account_id LIKE '101%' AND tgl >= '2026-01-01' AND tgl <= '2026-01-31') as jan_kredit,
  (SELECT SUM(AmountDebet - AmountCredit) FROM gl_balance WHERE AccountCode LIKE '101%' AND Period = '2026-01-01')
  + (SELECT SUM(debet) FROM gl_journal WHERE account_id LIKE '101%' AND tgl >= '2026-01-01' AND tgl <= '2026-01-31')
  - (SELECT SUM(kredit) FROM gl_journal WHERE account_id LIKE '101%' AND tgl >= '2026-01-01' AND tgl <= '2026-01-31') as ending_balance
"@

# 11. Check SKAS (AR opening) for 103-001 equivalent
RunQuery "gl_balance for 103-xxx at 2026-01-01" @"
SELECT AccountCode, AmountDebet, AmountCredit, site_id
FROM gl_balance
WHERE AccountCode LIKE '103%' AND Period = '2026-01-01'
ORDER BY AccountCode
"@

# 12. KEY: What is the AR/piutang net movement in Jan 2026 from DP vouchers?
RunQuery "103-001 GL movement Jan 2026 from DP vouchers" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE account_id = '103-001'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
ORDER BY tgl, voucher
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
