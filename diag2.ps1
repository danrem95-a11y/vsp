$out = [System.Collections.Generic.List[string]]::new()

$conn = New-Object System.Data.Odbc.OdbcConnection
$conn.ConnectionString = "DSN=vsp;uid=dba;pwd=jakarta;"
$conn.Open(); $cmd = $conn.CreateCommand()

# GL_JOURNAL account_id breakdown for Jan 2026 AP-related entries
$cmd.CommandText = "SELECT account_id, SUM(debet) AS debet, SUM(kredit) AS kredit, COUNT(*) AS jml FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-01-31' GROUP BY account_id ORDER BY kredit DESC"
$r = $cmd.ExecuteReader(); "=== GL_JOURNAL ACCOUNT_ID JAN2026 ==="
while($r.Read()){ "ACC={0}  D={1:N0}  K={2:N0}  JML={3}" -f $r[0],$r[1],$r[2],$r[3] }
$r.Close()

# GL_JOURNAL for AP account: what cust_ids appear (sample)
$cmd.CommandText = "SELECT account_id, SUM(debet) AS D, SUM(kredit) AS K FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-01-31' AND account_id LIKE '22%' GROUP BY account_id ORDER BY K DESC"
$r = $cmd.ExecuteReader(); "=== GL_JOURNAL 22x ACCOUNTS ==="
while($r.Read()){ "ACC={0}  D={1:N0}  K={2:N0}" -f $r[0],$r[1],$r[2] }
$r.Close()

# Saldo awal GL account 226-001 (before Jan 2026) from gl_journal cumulative
$cmd.CommandText = "SELECT SUM(debet) AS D, SUM(kredit) AS K FROM gl_journal WHERE tgl < '2026-01-01' AND account_id='226-001'"
$r = $cmd.ExecuteReader(); "=== GL 226-001 CUMULATIVE BEFORE JAN2026 ==="
while($r.Read()){ "D={0:N2}  K={1:N2}  SALDO(K-D)={2:N2}" -f $r[0],$r[1],([double]$r[1]-[double]$r[0]) }
$r.Close()

# GL_JOURNAL Jan 2026 for account 226-001: kredit=new invoices, debet=payments
$cmd.CommandText = "SELECT voucher, tgl, debet, kredit, cust_id, ket FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-01-31' AND account_id='226-001' ORDER BY tgl"
$r = $cmd.ExecuteReader(); "=== GL_JOURNAL 226-001 JAN2026 ENTRIES ==="
$td=0.0; $tk=0.0
while($r.Read()){
    $d=[double]$r["debet"]; $k=[double]$r["kredit"]; $td+=$d; $tk+=$k
    "V={0}  TGL={1}  D={2:N0}  K={3:N0}  CUST={4}  KET={5}" -f $r[0],$r[1],$d,$k,$r[4],$r[5]
}
"TOTAL D={0:N2}  TOTAL K={1:N2}" -f $td,$tk
$r.Close()

$conn.Close()
