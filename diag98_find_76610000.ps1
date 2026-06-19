$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag98_find_76610000_out.txt'
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

# 1. Check gl_balance for 101-011 at 2026-01-01
# Local shows 5,049,572,829.19 but maybe production has 5,126,182,829.19 (5B + 76.6M)?
RunQuery "gl_balance for all 101-xxx accounts at 2026-01-01" @"
SELECT AccountCode, AmountDebet, AmountCredit, site_id
FROM gl_balance
WHERE AccountCode LIKE '101%'
  AND Period = '2026-01-01'
ORDER BY AccountCode
"@

# 2. How does 5,049,572,829.19 for 101-011 compare to a possible wrong value?
# 5,049,572,829.19 + 76,610,000 = 5,126,182,829.19

# 3. What constitutes the 5,049,572,829.19 opening balance?
RunQuery "101-011 historical balance (sum of all gl_journal debet-kredit up to 2025-12-31)" @"
SELECT 
    SUM(debet) as total_debet,
    SUM(kredit) as total_kredit,
    SUM(debet) - SUM(kredit) as net_balance
FROM gl_journal
WHERE account_id = '101-011'
  AND tgl <= '2025-12-31'
"@

# 4. What is the 101-011 opening balance broken down by year?
RunQuery "101-011 balance by year (debet-kredit per year up to 2025)" @"
SELECT YEAR(tgl) as yr,
    SUM(debet) as total_debet,
    SUM(kredit) as total_kredit,
    SUM(debet) - SUM(kredit) as net_balance
FROM gl_journal
WHERE account_id = '101-011'
  AND tgl <= '2025-12-31'
GROUP BY YEAR(tgl)
ORDER BY YEAR(tgl)
"@

# 5. Check if there are AP-related GL entries in 101-011 from Jan 2026 that have show_hide='0'
RunQuery "All distinct show_hide values in gl_journal for 101-011 Jan 2026" @"
SELECT show_hide, COUNT(*) as cnt,
    SUM(debet) as total_debet, SUM(kredit) as total_kredit
FROM gl_journal
WHERE account_id = '101-011'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
GROUP BY show_hide
"@

# 6. Check what AP vouchers are in 101-011 January 2026
RunQuery "AP vouchers in 101-011 Jan 2026 (modul_id=AP)" @"
SELECT tgl, voucher, voucher_manual, debet, kredit, ket, modul_id, show_hide
FROM gl_journal
WHERE account_id = '101-011'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND modul_id = 'AP'
ORDER BY tgl, voucher
"@

# 7. Check the total AP disbursement in Jan 2026 on bank 101-011
RunQuery "Total AP payments in 101-011 Jan 2026 (tbyr2)" @"
SELECT t1.tgl_bayar, t1.voucher, t1.acc_kas, SUM(t2.nilai) as total_nilai
FROM tbyr1 t1
JOIN tbyr2 t2 ON t2.voucher = t1.voucher
WHERE t1.acc_kas = '101-011'
  AND t1.tgl_bayar >= '2026-01-01' AND t1.tgl_bayar <= '2026-01-31'
  AND t1.flag_bayar = '2'
GROUP BY t1.tgl_bayar, t1.voucher, t1.acc_kas
ORDER BY t1.tgl_bayar
"@

# 8. CRITICAL: Does the production server maybe have an OLD gl_balance entry?
RunQuery "gl_balance for 101-011 ALL periods" @"
SELECT Period, AmountDebet, AmountCredit, site_id
FROM gl_balance
WHERE AccountCode = '101-011'
ORDER BY Period
"@

# 9. Check if 76,610,000 appears anywhere in recent gl_journal for bank accounts
RunQuery "Bank entries for exactly 76610000" @"
SELECT account_id, tgl, voucher, voucher_manual, debet, kredit, ket, modul_id
FROM gl_journal
WHERE account_id LIKE '101%'
  AND (debet = 76610000 OR kredit = 76610000)
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
