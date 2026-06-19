Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# Various interpretations of "saldo awal AP 226-001 per 2026-01-01"
$queries = @{
'A_FULL_CUM_PRE2026' = "SELECT SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id='226-001' AND tgl<'2026-01-01'"
'B_CUM_FROM_2025' = "SELECT SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id='226-001' AND tgl>='2025-01-01' AND tgl<'2026-01-01'"
'C_CUM_PRE2025' = "SELECT SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id='226-001' AND tgl<'2025-01-01'"
'D_SAF_RATE_JAN26' = "SELECT SUM(ISNULL(S.SALDO_KURS*S.RATE,0)) AS V FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS IN (1,2) AND S.PERIODE>='2026-01-01' AND S.PERIODE<'2026-02-01'"
'E_SAF_NEWSAL_JAN26' = "SELECT SUM(ISNULL(S.NEW_SALDO,0)) AS V FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS IN (1,2) AND S.PERIODE>='2026-01-01' AND S.PERIODE<'2026-02-01'"
'F_SAF_SALDO_JAN26' = "SELECT SUM(ISNULL(S.SALDO,0)) AS V FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS IN (1,2) AND S.PERIODE>='2026-01-01' AND S.PERIODE<'2026-02-01'"
'G_SAF_RATE_GLFILT' = "SELECT SUM(ISNULL(S.SALDO_KURS*S.RATE,0)) AS V FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS IN (1,2) AND S.PERIODE>='2026-01-01' AND S.PERIODE<'2026-02-01' AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.kredit>0)"
'H_SAF_NEW_GLFILT' = "SELECT SUM(ISNULL(S.NEW_SALDO,0)) AS V FROM SALDO_AWAL_FAKTUR S WHERE S.TIPE_TRANS IN (1,2) AND S.PERIODE>='2026-01-01' AND S.PERIODE<'2026-02-01' AND EXISTS (SELECT 1 FROM gl_journal GJ WHERE GJ.voucher=S.BUKTI_ID AND GJ.account_id='226-001' AND GJ.kredit>0)"
'I_LEDGER_END_DEC' = "SELECT SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id='226-001' AND tgl<='2025-12-31'"
'J_226001_LIKE' = "SELECT SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id LIKE '226-001%' AND tgl<'2026-01-01'"
}

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=300
  foreach ($k in $queries.Keys | Sort-Object) {
    $cmd.CommandText = $queries[$k]
    $r = $cmd.ExecuteReader()
    if ($r.Read()) { $out += ("{0}={1}" -f $k, $r['V']) }
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag33_out.txt' -Encoding UTF8
