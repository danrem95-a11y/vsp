$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag94_old_report_path_out.txt'
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

# 1. What tables exist for report_form / coa_saldo?
RunQuery "Tables with report_form or coa_saldo" @"
SELECT table_name, table_type
FROM SYS.SYSTABLE
WHERE table_name LIKE '%report%' OR table_name LIKE '%coa%'
ORDER BY table_type, table_name
"@

# 2. The gl_report table (actual name used in the old code is ds_report_form)
RunQuery "GL_REPORT all rows (Balance Sheet = report_id 02?)" @"
SELECT * FROM gl_report
ORDER BY 1
"@

# 3. What are the columns of gl_report?
RunQuery "GL_REPORT column names" @"
SELECT c.column_name, c.domain, c.width, c.default_value
FROM SYS.SYSCOLUMNS c
JOIN SYS.SYSTABLE t ON t.table_id = c.table_id
WHERE t.table_name = 'GL_REPORT'
ORDER BY c.column_id
"@

# 4. What are the columns/query in ds_coa_saldo view?
RunQuery "v_saldo_awal view content (if it's the saldo view)" @"
SELECT viewtext FROM SYS.SYSVIEWS WHERE view_name = 'V_SALDO_AWAL'
"@

# 5. Run the OLD saldo calculation for BANK accounts using ds_coa_saldo logic
# ds_coa_saldo args: (ii_bulan, ii_tahun, gs_site, account_like)
# For BANK in Jan 2026: (1, 2026, '101', '101%')
# The key question: what account prefix does gl_report use for BANK line?
# Let's simulate: what if account_id = '10' (matches 100+101)?
RunQuery "Simulate ds_coa_saldo if account_id=10 (both KAS+BANK)" @"
SELECT 'pattern=10%' as pattern,
       SUM(ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) as opening_2026,
       SUM(ISNULL(gj.net,0)) as movement_jan,
       SUM((ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) + ISNULL(gj.net,0)) as total
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode=a.AccountCode AND gb.Period='2026-01-01'
LEFT JOIN (SELECT account_id, SUM(debet)-SUM(kredit) as net
           FROM gl_journal WHERE tgl>='2026-01-01' AND tgl<='2026-01-31'
           GROUP BY account_id) gj ON gj.account_id=a.AccountCode
WHERE a.AccountCode LIKE '10%' AND a.DetailYN='1'
"@

RunQuery "Simulate ds_coa_saldo if account_id=101 (BANK only)" @"
SELECT 'pattern=101%' as pattern,
       SUM(ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) as opening_2026,
       SUM(ISNULL(gj.net,0)) as movement_jan,
       SUM((ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) + ISNULL(gj.net,0)) as total
FROM gl_acc a
LEFT JOIN gl_balance gb ON gb.AccountCode=a.AccountCode AND gb.Period='2026-01-01'
LEFT JOIN (SELECT account_id, SUM(debet)-SUM(kredit) as net
           FROM gl_journal WHERE tgl>='2026-01-01' AND tgl<='2026-01-31'
           GROUP BY account_id) gj ON gj.account_id=a.AccountCode
WHERE a.AccountCode LIKE '101%' AND a.DetailYN='1'
"@

# 6. What does the 101-011 January movement look like when using SKAS-style?
# Check: SKAS KAS_ID 2004 for 2026
RunQuery "SKAS all 2026 entries" @"
SELECT s.KAS_ID, m.NAMA, m.ACCOUNT_ID, m.FLAG_KAS,
       s.PERIODE, s.SALDO, s.SITE_ID
FROM SKAS s
JOIN MKAS m ON m.KAS_ID = s.KAS_ID
WHERE s.PERIODE >= '2026-01-01'
ORDER BY s.KAS_ID, s.PERIODE
"@

# 7. KEY: what is the sum of SKAS bank entries for Jan 2026?
# SKAS might be used as opening balance by an old report path
RunQuery "SKAS bank total for Jan 2026 (all bank KAS_ID)" @"
SELECT SUM(s.SALDO) as skas_total_bank
FROM SKAS s
JOIN MKAS m ON m.KAS_ID = s.KAS_ID
WHERE m.FLAG_KAS = 'B'
  AND s.PERIODE = '2026-01-01'
"@

# 8. Is there a v_saldo or similar that might include extra accounts?
RunQuery "What views exist" @"
SELECT table_name
FROM SYS.SYSTABLE
WHERE table_type = 'VIEW'
ORDER BY table_name
"@

# 9. Check the 101-201 triple entry more carefully
RunQuery "GL_JOURNAL detail for 101-201 voucher_manual 26012004R039" @"
SELECT tgl, voucher, voucher_manual, account_id, debet, kredit, ket, modul_id, show_hide
FROM gl_journal
WHERE voucher_manual = '26012004R039'
ORDER BY tgl, account_id
"@

# 10. What IS the 101-201 January movement at detailed level?
RunQuery "GL_JOURNAL 101-201 full Jan 2026" @"
SELECT tgl, voucher, voucher_manual, debet, kredit, ket, modul_id
FROM gl_journal
WHERE account_id = '101-201'
  AND tgl >= '2026-01-01' AND tgl <= '2026-01-31'
ORDER BY tgl, voucher
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
