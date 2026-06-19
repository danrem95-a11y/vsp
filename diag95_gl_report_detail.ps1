$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag95_gl_report_detail_out.txt'
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

# 1. Show all columns from gl_report_detail
RunQuery "gl_report_detail - all rows" @"
SELECT *
FROM gl_report_detail
ORDER BY 1, 2, 3
"@

# 2. BANK line specifically
RunQuery "gl_report_detail for Balance Sheet (report_id=02) BANK entries" @"
SELECT *
FROM gl_report_detail
WHERE report_id = '02'
ORDER BY seq_no
"@

# 3. Simulate OLD code path for BANK line in Jan 2026
# For EACH row in gl_report_detail with report_id='02',
# simulate what lds_saldo2.Retrieve(1, 2026, site, account_id plus percent) would return
RunQuery "Simulate OLD balance sheet BANK - check account pattern" @"
SELECT d.seq_no, d.description, d.account_id,
       d.t1,
       SUM(ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0)) as opening_2026,
       SUM(ISNULL(
           (SELECT SUM(debet)-SUM(kredit) FROM gl_journal g
            WHERE g.account_id = a.AccountCode
              AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0)) as movement_jan,
       SUM((ISNULL(gb.AmountDebet,0) - ISNULL(gb.AmountCredit,0))
           + ISNULL((SELECT SUM(debet)-SUM(kredit) FROM gl_journal g
                     WHERE g.account_id = a.AccountCode
                       AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'), 0)
           ) as saldo_jan31
FROM gl_report_detail d
JOIN gl_acc a ON a.AccountCode LIKE d.account_id + '%'
LEFT JOIN gl_balance gb ON gb.AccountCode = a.AccountCode AND gb.Period = '2026-01-01'
WHERE d.report_id = '02' AND a.DetailYN = '1'
GROUP BY d.seq_no, d.description, d.account_id, d.trd123, d.t1
ORDER BY d.seq_no
"@

# 4. Check if there is a v_neraca definition
RunQuery "v_neraca view definition (SA11 syntax)" @"
SELECT SUBSTRING(text, 1, 4000) as view_text
FROM SYSCOMMENTS
WHERE id = OBJECT_ID('v_neraca')
"@

# 5. Check what the w_rpt_neraca balance sheet rekap report ID is
RunQuery "gl_report all with report_tipe" @"
SELECT site_id, report_id, report_desc, report_tipe
FROM gl_report
ORDER BY report_id
"@

# 6. The OLD code path computes BANK using account pattern from ds_report_form
RunQuery "Tables or views with form in name" @"
SELECT table_name, table_type
FROM SYSTABLE
WHERE LOWER(table_name) LIKE '%form%' OR LOWER(table_name) LIKE '%report%'
ORDER BY table_name
"@

# 7. Check if gl_report_detail has account_id for BANK that includes BOTH kas and bank
RunQuery "Accounts matching gl_report_detail BANK pattern (102 check)" @"
SELECT d.account_id, 
       COUNT(a.AccountCode) as matching_accounts,
       STRING(a.AccountCode, ',') as account_list
FROM gl_report_detail d
JOIN gl_acc a ON a.AccountCode LIKE d.account_id + '%' AND a.DetailYN='1'
WHERE d.report_id = '02'
  AND (d.description LIKE '%BANK%' OR d.account_id LIKE '10%')
GROUP BY d.account_id, d.description, d.seq_no
ORDER BY d.seq_no
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
