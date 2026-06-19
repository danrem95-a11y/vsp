Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

$qs = @(
# Filter only AP voucher types
@{n='K1_AP_VOUCHER_PRE2026'; q="SELECT SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)) AS V FROM gl_journal GG WHERE GG.account_id='226-001' AND GG.tgl<'2026-01-01' AND (EXISTS(SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT=GG.voucher) OR EXISTS(SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT=GG.order_reff) OR EXISTS(SELECT 1 FROM TBYR1 T WHERE T.VOUCHER=GG.voucher) OR EXISTS(SELECT 1 FROM TBYR2 T WHERE T.VOUCHER=GG.voucher))"}
@{n='K2_BTB_VOUCHER_PRE2026'; q="SELECT SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)) AS V FROM gl_journal GG WHERE GG.account_id='226-001' AND GG.tgl<'2026-01-01' AND (GG.voucher LIKE '101BTB%' OR GG.order_reff LIKE '101BTB%')"}
@{n='K3_NONBTB_NONAP_PRE2026'; q="SELECT SUM(ISNULL(GG.kredit,0))-SUM(ISNULL(GG.debet,0)) AS V FROM gl_journal GG WHERE GG.account_id='226-001' AND GG.tgl<'2026-01-01' AND GG.voucher NOT LIKE '101BTB%' AND ISNULL(GG.order_reff,'') NOT LIKE '101BTB%' AND NOT EXISTS(SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT=GG.voucher) AND NOT EXISTS(SELECT 1 FROM AP_TRANS A WHERE A.ORDER_CLIENT=GG.order_reff)"}
@{n='K4_MODULPO_PRE2026'; q="SELECT SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id='226-001' AND tgl<'2026-01-01' AND modul_id='PO'"}
@{n='K5_BYMODULID_PRE2026'; q="SELECT modul_id, SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V FROM gl_journal WHERE account_id='226-001' AND tgl<'2026-01-01' GROUP BY modul_id ORDER BY ABS(SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0))) DESC"}
)

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=300
  foreach ($x in $qs) {
    $out += "--- $($x.n)"
    $cmd.CommandText = $x.q
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
      $line=""; for ($i=0;$i -lt $r.FieldCount;$i++){ $line += "$($r.GetName($i))=$($r[$i])|" }
      $out += $line
    }
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag35_out.txt' -Encoding UTF8
