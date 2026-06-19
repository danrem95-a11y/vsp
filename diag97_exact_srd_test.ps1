$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag97_exact_srd_test_out.txt'
$output = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;")
try { $conn.Open() } catch { "CONN ERROR: $_" | Set-Content $outFile; exit }

function RunQuery($label, $sql) {
    $output.Add(""); $output.Add("===== $label =====")
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 300
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

# Exact SRD SQL for BANK (fincatcode=BS2011)
# arg_tgl1=2026-01-01, arg_tgl2=2025-12-31, arg_tgl3=2026-01-01, arg_tgl4=2026-01-31
# With arg_show=1 (show all, INCLUDING show_hide=0 entries)
RunQuery "EXACT SRD BANK - with arg_show=1 (include all journal entries)" @"
SELECT a.accountcode, a.accountdes, a.flag_dk, a.show_hide as acc_show_hide,
    ISNULL(AWAL.DEBIT,0) as awal1_debit, ISNULL(AWAL.CREDIT,0) as awal1_credit,
    ISNULL(AWAL2.DEBIT,0) as awal2_debit, ISNULL(AWAL2.CREDIT,0) as awal2_credit,
    ISNULL(MUTASI.DEBIT,0) as mutasi_debit, ISNULL(MUTASI.CREDIT,0) as mutasi_credit,
    (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0)) * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END) as clalu11,
    ((ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END)) as mutasi_net,
    (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0) + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) 
    * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END) as cakhir11
FROM v_neraca a,
(SELECT GL_BALANCE.ACCOUNTCODE, SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
 FROM GL_BALANCE
 WHERE GL_BALANCE.PERIOD = '2026-01-01'
 GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
(SELECT GL_JOURNAL.ACCOUNT_ID, SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
 FROM GL_JOURNAL
 WHERE tgl between '2026-01-01' and '2025-12-31'
   AND ((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
 GROUP BY GL_JOURNAL.ACCOUNT_ID) AWAL2,
(SELECT GL_JOURNAL.ACCOUNT_ID, SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
 FROM GL_JOURNAL
 WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
   AND ((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
 GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE a.fincatcode = 'BS2011'
  AND ((isnull(a.show_hide,'1') = '1') or 1 = 1)
  AND a.ACCOUNTCODE *= AWAL.ACCOUNTCODE
  AND a.ACCOUNTCODE *= AWAL2.ACCOUNT_ID
  AND a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID
ORDER BY a.accountcode
"@

# With arg_show=NULL (filter: only show_hide=1 journal entries AND accounts)
RunQuery "EXACT SRD BANK - with arg_show=NULL (filter show_hide=0)" @"
SELECT a.accountcode, a.accountdes, a.flag_dk, a.show_hide as acc_show_hide,
    ISNULL(AWAL.DEBIT,0) as awal1_debit, ISNULL(AWAL.CREDIT,0) as awal1_credit,
    ISNULL(AWAL2.DEBIT,0) as awal2_debit, ISNULL(AWAL2.CREDIT,0) as awal2_credit,
    ISNULL(MUTASI.DEBIT,0) as mutasi_debit, ISNULL(MUTASI.CREDIT,0) as mutasi_credit,
    (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0)) * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END) as clalu11,
    ((ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END)) as mutasi_net,
    (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0) + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) 
    * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END) as cakhir11
FROM v_neraca a,
(SELECT GL_BALANCE.ACCOUNTCODE, SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
 FROM GL_BALANCE
 WHERE GL_BALANCE.PERIOD = '2026-01-01'
 GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
(SELECT GL_JOURNAL.ACCOUNT_ID, SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
 FROM GL_JOURNAL
 WHERE tgl between '2026-01-01' and '2025-12-31'
   AND (isnull(gl_journal.show_hide,'1') = '1')
 GROUP BY GL_JOURNAL.ACCOUNT_ID) AWAL2,
(SELECT GL_JOURNAL.ACCOUNT_ID, SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
 FROM GL_JOURNAL
 WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
   AND (isnull(gl_journal.show_hide,'1') = '1')
 GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE a.fincatcode = 'BS2011'
  AND (isnull(a.show_hide,'1') = '1')
  AND a.ACCOUNTCODE *= AWAL.ACCOUNTCODE
  AND a.ACCOUNTCODE *= AWAL2.ACCOUNT_ID
  AND a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID
ORDER BY a.accountcode
"@

# Total sum comparison
RunQuery "BANK TOTAL with arg_show=1" @"
SELECT SUM((ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0) + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) 
    * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END)) as bank_total
FROM v_neraca a,
(SELECT GL_BALANCE.ACCOUNTCODE, SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
 FROM GL_BALANCE WHERE GL_BALANCE.PERIOD = '2026-01-01' GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
(SELECT GL_JOURNAL.ACCOUNT_ID, SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
 FROM GL_JOURNAL WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
   AND ((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
 GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE a.fincatcode = 'BS2011'
  AND ((isnull(a.show_hide,'1') = '1') or 1 = 1)
  AND a.ACCOUNTCODE *= AWAL.ACCOUNTCODE
  AND a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID
"@

RunQuery "BANK TOTAL with arg_show=NULL (filter)" @"
SELECT SUM((ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0) + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) 
    * (CASE WHEN a.flag_dk='D' THEN 1 ELSE -1 END)) as bank_total
FROM v_neraca a,
(SELECT GL_BALANCE.ACCOUNTCODE, SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
 FROM GL_BALANCE WHERE GL_BALANCE.PERIOD = '2026-01-01' GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
(SELECT GL_JOURNAL.ACCOUNT_ID, SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
 FROM GL_JOURNAL WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
   AND (isnull(gl_journal.show_hide,'1') = '1')
 GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE a.fincatcode = 'BS2011'
  AND (isnull(a.show_hide,'1') = '1')
  AND a.ACCOUNTCODE *= AWAL.ACCOUNTCODE
  AND a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID
"@

# Check show_hide=0 entries in gl_journal for bank accounts Jan 2026
RunQuery "Jan 2026 gl_journal BANK entries with show_hide=0" @"
SELECT g.account_id, g.tgl, g.voucher, g.voucher_manual, g.debet, g.kredit, 
       g.show_hide, g.ket, g.modul_id
FROM gl_journal g
WHERE g.account_id LIKE '101%'
  AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'
  AND g.show_hide = '0'
ORDER BY g.account_id, g.tgl
"@

RunQuery "Jan 2026 gl_journal BANK entries with show_hide IS NULL" @"
SELECT g.account_id, g.tgl, g.voucher, g.voucher_manual, g.debet, g.kredit, 
       g.show_hide, g.ket, g.modul_id
FROM gl_journal g
WHERE g.account_id LIKE '101%'
  AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'
  AND g.show_hide IS NULL
ORDER BY g.account_id, g.tgl
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
