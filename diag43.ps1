Add-Type -AssemblyName System.Data
$con = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;uid=dba;pwd=jakarta;")
$con.Open()
$out = @()

# VP entries on 226-001 in Dec 2025 and Jan 2026
$sql1 = @"
SELECT tgl, voucher, ROUND(kredit,2) AS K, ROUND(debet,2) AS D, ket
FROM gl_journal
WHERE account_id='226-001' AND modul_id='VP'
  AND tgl BETWEEN '2025-12-25' AND '2026-01-10'
ORDER BY tgl, voucher
"@

# Sum of VP on 226-001 by month
$sql2 = @"
SELECT DATEFORMAT(tgl,'yyyy-mm') AS YM, SUM(ISNULL(kredit,0)) AS K, SUM(ISNULL(debet,0)) AS D, COUNT(*) AS C
FROM gl_journal
WHERE account_id='226-001' AND modul_id='VP'
GROUP BY DATEFORMAT(tgl,'yyyy-mm')
ORDER BY YM
"@

# Total of Dec 31 2025 VP K on 226-001
$sql3 = @"
SELECT SUM(ISNULL(kredit,0)) AS K_TOT, SUM(ISNULL(debet,0)) AS D_TOT, COUNT(*) AS C
FROM gl_journal
WHERE account_id='226-001' AND modul_id='VP' AND tgl='2025-12-31'
"@

try {
  $cmd = $con.CreateCommand(); $cmd.CommandTimeout=300
  foreach($p in @(@('=== VP 226-001 Dec25-Jan26 ===',$sql1),@('=== VP 226-001 by month ===',$sql2),@('VP_DEC31_TOT',$sql3))) {
    $out += $p[0]
    $cmd.CommandText = $p[1]
    $r = $cmd.ExecuteReader()
    $h=@();for($i=0;$i -lt $r.FieldCount;$i++){$h += $r.GetName($i)}
    $out += ($h -join "|")
    while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v += "$($r.GetValue($i))"};$out += ($v -join "|")}
    $r.Close()
  }
} finally { $con.Close() }
$out | Out-File 'c:\BTV\debug\diag43_out.txt' -Encoding UTF8
Write-Host ($out -join "`n")
