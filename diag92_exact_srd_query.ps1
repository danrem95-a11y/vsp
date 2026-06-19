$ErrorActionPreference = 'Continue'
$outFile = 'c:\BTV\debug\diag92_exact_srd_query_out.txt'
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

# Run EXACT SQL from dw_rpt_neraca_new_rekap.srd for January 2026
# arg_tgl1=2026-01-01, arg_tgl2=2025-12-31, arg_tgl3=2026-01-01, arg_tgl4=2026-01-31, arg_show=0
RunQuery "EXACT SRD QUERY - BANK rows (fincatcode=BS2011) Jan2026" @"
SELECT a.fincatcode, a.accountcode, a.accountdes, a.flag_dk,
       ISNULL(AWAL.DEBIT,0)  as AWAL1_DEBIT,
       ISNULL(AWAL.CREDIT,0) as AWAL1_CREDIT,
       ISNULL(AWAL2.DEBIT,0) as AWAL2_DEBIT,
       ISNULL(AWAL2.CREDIT,0) as AWAL2_CREDIT,
       ISNULL(MUTASI.DEBIT,0) AS MUTASI_DEBIT,
       ISNULL(MUTASI.CREDIT,0) AS MUTASI_CREDIT
FROM v_neraca a,
     (SELECT GL_BALANCE.ACCOUNTCODE,
             SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
      FROM GL_BALANCE
      WHERE GL_BALANCE.PERIOD = '2026-01-01'
      GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
     (SELECT GL_JOURNAL.ACCOUNT_ID,
             SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
      FROM GL_JOURNAL
      WHERE tgl between '2026-01-01' and '2025-12-31'
        AND (ISNULL(gl_journal.show_hide,'1') = '1')
      GROUP BY GL_JOURNAL.ACCOUNT_ID) AWAL2,
     (SELECT GL_JOURNAL.ACCOUNT_ID,
             SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
      FROM GL_JOURNAL
      WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
        AND (ISNULL(gl_journal.show_hide,'1') = '1')
      GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE (ISNULL(a.show_hide,'1') = '1')
  AND (a.ACCOUNTCODE *= AWAL.ACCOUNTCODE)
  AND (a.ACCOUNTCODE *= AWAL2.ACCOUNT_ID)
  AND (a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID)
  AND a.fincatcode = 'BS2011'
ORDER BY a.ACCOUNTCODE
"@

# Now compute cakhir11 (Saldo Sekarang) from the exact formula in the SRD
# cakhir11 = clalu11 + ((mutasi_debit - mutasi_credit) * flag_dk_multiplier)
# clalu11 for month=1: = (awal1_debit - awal1_credit) * if(flag_dk='D',1,-1)
RunQuery "EXACT SRD cakhir11 for BANK Jan 2026" @"
SELECT a.fincatcode, a.accountcode, a.accountdes, a.flag_dk,
       ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0) as clalu11_raw,
       ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0) as mutasi_net,
       -- cakhir11 = clalu11 + mutasi_net (for flag_dk='D', both × 1)
       (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0)
        + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0)) as cakhir11_bank
FROM v_neraca a,
     (SELECT GL_BALANCE.ACCOUNTCODE,
             SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
      FROM GL_BALANCE
      WHERE GL_BALANCE.PERIOD = '2026-01-01'
      GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
     (SELECT GL_JOURNAL.ACCOUNT_ID,
             SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
      FROM GL_JOURNAL
      WHERE tgl between '2026-01-01' and '2025-12-31'
        AND (ISNULL(gl_journal.show_hide,'1') = '1')
      GROUP BY GL_JOURNAL.ACCOUNT_ID) AWAL2,
     (SELECT GL_JOURNAL.ACCOUNT_ID,
             SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
      FROM GL_JOURNAL
      WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
        AND (ISNULL(gl_journal.show_hide,'1') = '1')
      GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE (ISNULL(a.show_hide,'1') = '1')
  AND (a.ACCOUNTCODE *= AWAL.ACCOUNTCODE)
  AND (a.ACCOUNTCODE *= AWAL2.ACCOUNT_ID)
  AND (a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID)
  AND a.fincatcode = 'BS2011'
ORDER BY a.ACCOUNTCODE
"@

# SUM of BANK cakhir11
RunQuery "SUM BANK cakhir11 Jan 2026" @"
SELECT SUM(
       (ISNULL(AWAL.DEBIT,0) - ISNULL(AWAL.CREDIT,0)
        + ISNULL(MUTASI.DEBIT,0) - ISNULL(MUTASI.CREDIT,0))
       ) as total_bank_cakhir11
FROM v_neraca a,
     (SELECT GL_BALANCE.ACCOUNTCODE,
             SUM(AMOUNTDEBET) AS DEBIT, SUM(AMOUNTCREDIT) AS CREDIT
      FROM GL_BALANCE
      WHERE GL_BALANCE.PERIOD = '2026-01-01'
      GROUP BY GL_BALANCE.ACCOUNTCODE) AWAL,
     (SELECT GL_JOURNAL.ACCOUNT_ID,
             SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
      FROM GL_JOURNAL
      WHERE tgl between '2026-01-01' and '2025-12-31'
        AND (ISNULL(gl_journal.show_hide,'1') = '1')
      GROUP BY GL_JOURNAL.ACCOUNT_ID) AWAL2,
     (SELECT GL_JOURNAL.ACCOUNT_ID,
             SUM(DEBET) AS DEBIT, SUM(KREDIT) AS CREDIT
      FROM GL_JOURNAL
      WHERE GL_JOURNAL.TGL between '2026-01-01' and '2026-01-31'
        AND (ISNULL(gl_journal.show_hide,'1') = '1')
      GROUP BY GL_JOURNAL.ACCOUNT_ID) MUTASI
WHERE (ISNULL(a.show_hide,'1') = '1')
  AND (a.ACCOUNTCODE *= AWAL.ACCOUNTCODE)
  AND (a.ACCOUNTCODE *= AWAL2.ACCOUNT_ID)
  AND (a.ACCOUNTCODE *= MUTASI.ACCOUNT_ID)
  AND a.fincatcode = 'BS2011'
"@

# Check what AP vouchers have MISSING bank GL entries
# i.e., tbyr1 where flag_bayar='2' but NO gl_journal entries for bank accounts (101-xxx) in the same voucher_manual
RunQuery "AP vouchers with no bank GL entry (Jan 2026)" @"
SELECT TOP 50 t1.VOUCHER, t1.VOUCHER_MANUAL, t1.TGL, t1.VENDOR_ID,
       t2.NILAI_BAYAR_IDR,
       (SELECT SUM(debet) - SUM(kredit)
        FROM gl_journal g
        WHERE g.voucher_manual = t1.VOUCHER_MANUAL
          AND g.account_id LIKE '101%') as bank_net_gl
FROM tbyr1 t1
JOIN tbyr2 t2 ON t2.VOUCHER = t1.VOUCHER
WHERE t1.FLAG_BAYAR = '2'
  AND t1.TGL >= '2026-01-01' AND t1.TGL <= '2026-01-31'
  AND NOT EXISTS (
    SELECT 1 FROM gl_journal g
    WHERE g.voucher_manual = t1.VOUCHER_MANUAL
      AND g.account_id LIKE '101%'
  )
ORDER BY t1.TGL, t1.VOUCHER
"@

# Also check: total of ALL AP voucher bank GL vs tbyr2 total for Jan 2026
RunQuery "Total AP bank GL vs tbyr2 Jan 2026" @"
SELECT 
  (SELECT SUM(ISNULL(NILAI_BAYAR_IDR,0)) FROM tbyr2 t2 
   JOIN tbyr1 t1 ON t1.VOUCHER=t2.VOUCHER 
   WHERE t1.FLAG_BAYAR='2' AND t1.TGL>='2026-01-01' AND t1.TGL<='2026-01-31') as total_tbyr2_nilai,
  (SELECT SUM(kredit) FROM gl_journal g
   WHERE g.account_id LIKE '101%'
     AND g.tgl >= '2026-01-01' AND g.tgl <= '2026-01-31'
     AND EXISTS (SELECT 1 FROM tbyr1 t WHERE t.VOUCHER_MANUAL=g.voucher_manual AND t.FLAG_BAYAR='2')
  ) as total_gl_bank_kredit_ap
"@

$conn.Close()
$output | Set-Content $outFile -Encoding UTF8
Write-Host "DONE: $outFile"
