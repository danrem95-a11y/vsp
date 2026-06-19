$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag99_dp_journal_out.txt'
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

# 1. Find DP-related tables
RunQuery "Tables with DP in name" @"
SELECT table_name, table_type FROM SYSTABLE
WHERE LOWER(table_name) LIKE '%dp%' OR LOWER(table_name) LIKE '%dimuka%' OR LOWER(table_name) LIKE '%uang_muka%'
ORDER BY table_name
"@

# 2. Columns of tbyr1 (to understand flag_dp, tipe, etc.)
RunQuery "tbyr1 columns" @"
SELECT column_name, domain, width
FROM SYSCOLUMNS
WHERE tname = 'tbyr1'
ORDER BY colno
"@

# 3. Find the two DP vouchers in tbyr1 - search for the DP no 2602DPR001 reference
RunQuery "tbyr1 rows matching DP 2602DPR001 or 2602DP" @"
SELECT *
FROM tbyr1
WHERE voucher LIKE '2602DP%'
   OR voucher_manual LIKE '%2602DP%'
   OR ket LIKE '%2602DPR001%'
   OR ket LIKE '%DP%'
   AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
ORDER BY tgl
"@

# 4. All tbyr1 rows in Jan 2026 (to find what DP transactions look like)
RunQuery "tbyr1 all Jan 2026" @"
SELECT voucher, voucher_manual, tgl, acc_ar, acc_bayar, acc_kas, curr_id, nilai_idr, nilai_potidr, ket
FROM tbyr1
WHERE tgl >= '2026-01-01' AND tgl <= '2026-01-31'
ORDER BY tgl, voucher
"@

# 5. Find GL journal entries for bank accounts that match DP amounts in Jan 2026
# Looking for bank debit entries of ~56,610,000 or ~20,000,000
RunQuery "Bank GL entries Jan 2026 matching DP amounts" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE account_id LIKE '101%'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  AND (
    (debet >= 56000000 AND debet <= 57000000)
    OR (debet >= 19000000 AND debet <= 21000000)
    OR (kredit >= 56000000 AND kredit <= 57000000)
    OR (kredit >= 19000000 AND kredit <= 21000000)
  )
ORDER BY tgl, voucher
"@

# 6. Search all GL journal for voucher_manual containing 2602DPR
RunQuery "GL journal with voucher_manual containing 2602DPR" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE voucher_manual LIKE '%2602DPR%'
   OR voucher LIKE '%2602DPR%'
   OR ket LIKE '%2602DPR%'
ORDER BY tgl, account_id
"@

# 7. Find d_trace_ar SRD content in SYSCOMMENTS (if it's a view or stored query)
# Also check for t_dp or dp-related tables
RunQuery "Tables with tbyr in name" @"
SELECT table_name, table_type FROM SYSTABLE
WHERE LOWER(table_name) LIKE '%tbyr%' OR LOWER(table_name) LIKE '%bayar%'
ORDER BY table_name
"@

# 8. tbyr2 columns
RunQuery "tbyr2 columns" @"
SELECT column_name, domain, width
FROM SYSCOLUMNS
WHERE tname = 'tbyr2'
ORDER BY colno
"@

# 9. tbyr1 - look for rows with acc_bayar like '228%' (DP account) in Jan 2026
RunQuery "tbyr1 Jan 2026 with acc_bayar=228 (DP records)" @"
SELECT voucher, voucher_manual, tgl, acc_ar, acc_bayar, acc_kas, nilai_idr, nilai_potidr, ket
FROM tbyr1
WHERE acc_bayar LIKE '228%'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
ORDER BY tgl
"@

# 10. All GL journal entries for 228-xxx accounts in Jan 2026
RunQuery "GL journal 228-xxx in Jan 2026" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id
FROM gl_journal
WHERE account_id LIKE '228%'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
ORDER BY tgl, voucher
"@

# 11. For each 228-xxx GL entry, find the matching bank entry (same voucher_manual)
RunQuery "Bank GL entries matching 228-xxx vouchers in Jan 2026" @"
SELECT gj.tgl, gj.voucher, gj.voucher_manual, gj.account_id, gj.debet, gj.kredit, gj.ket, gj.modul_id
FROM gl_journal gj
WHERE gj.account_id LIKE '101%'
  AND gj.tgl >= '2026-01-01' AND gj.tgl <= '2026-01-31'
  AND gj.voucher_manual IN (
    SELECT DISTINCT voucher_manual FROM gl_journal
    WHERE account_id LIKE '228%'
      AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  )
ORDER BY gj.tgl, gj.voucher_manual
"@

# 12. Full picture: all GL entries for voucher_manual that have 228-xxx
RunQuery "All GL entries for voucher_manuals with 228-xxx account in Jan 2026" @"
SELECT gj.tgl, gj.voucher, gj.voucher_manual, gj.account_id, gj.debet, gj.kredit, gj.ket, gj.modul_id
FROM gl_journal gj
WHERE gj.tgl >= '2026-01-01' AND gj.tgl <= '2026-01-31'
  AND gj.voucher_manual IN (
    SELECT DISTINCT voucher_manual FROM gl_journal
    WHERE account_id LIKE '228%'
      AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
  )
ORDER BY gj.voucher_manual, gj.account_id
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
