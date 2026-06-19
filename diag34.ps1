Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

$queries = @(
 # Per site
 "SELECT site_id, SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0)) AS V, COUNT(*) AS C FROM gl_journal WHERE account_id='226-001' AND tgl<'2026-01-01' GROUP BY site_id ORDER BY ABS(SUM(ISNULL(kredit,0))-SUM(ISNULL(debet,0))) DESC",
 # Per site, ledger amount during Jan2026 (to identify the active site)
 "SELECT site_id, SUM(ISNULL(kredit,0)) AS K, SUM(ISNULL(debet,0)) AS D FROM gl_journal WHERE account_id='226-001' AND tgl>='2026-01-01' AND tgl<'2026-02-01' GROUP BY site_id"
)

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=300
  foreach ($q in $queries) {
    $out += "--- $q"
    $cmd.CommandText = $q
    $r = $cmd.ExecuteReader()
    while ($r.Read()) {
      $line = ""
      for ($i=0; $i -lt $r.FieldCount; $i++) { $line += "$($r.GetName($i))=$($r[$i])|" }
      $out += $line
    }
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag34_out.txt' -Encoding UTF8
