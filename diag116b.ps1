$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandTimeout = 180
$out=@()

$out += "=== tstok2 columns ==="
$cmd.CommandText = "SELECT c.column_name FROM systable t JOIN syscolumn c ON c.table_id=t.table_id WHERE t.table_name='TSTOK2' ORDER BY c.column_id"
$r=$cmd.ExecuteReader(); $cols=@(); while($r.Read()){ $cols += $r[0].ToString() }; $r.Close()
$out += ($cols -join ', ')

$out += ""
$out += "=== Banding: ap_trans tipe 05 (2025-2026) vs jurnal EX (doc_reff=order_client) ==="
$cmd.CommandText = @"
SELECT a.order_client, a.tgl, a.ttl_kotor, a.ttl_ppn, a.ttl_netto,
       (SELECT SUM(debet) FROM gl_journal g WHERE g.doc_reff=a.order_client AND g.modul_id='EX') gl_dr,
       (SELECT SUM(kredit) FROM gl_journal g WHERE g.doc_reff=a.order_client AND g.modul_id='EX') gl_cr,
       (SELECT COUNT(*) FROM gl_journal g WHERE g.doc_reff=a.order_client AND g.modul_id='EX') gl_n
FROM ap_trans a
WHERE a.tipe_trans='05' AND a.tgl >= '2025-01-01'
ORDER BY a.tgl
"@
$r=$cmd.ExecuteReader()
while($r.Read()){
  $netto=[decimal]$r[4]; $dr= if($r[5] -is [DBNull]){0}else{[decimal]$r[5]}
  $flag = if([Math]::Abs($netto-$dr) -gt 1){'  <== BEDA'}else{''}
  $out += "oc=[$($r[0])] tgl=$([datetime]$r[1] | Get-Date -Format yyyy-MM-dd) kotor=$($r[2]) ppn=$($r[3]) netto=$netto glDr=$dr glCr=$($r[6]) n=$($r[7])$flag"
}
$r.Close()

$out += ""
$out += "=== Voucher FR05 (alokasi freight): jurnal vs sumber ==="
$cmd.CommandText = @"
SELECT g.doc_reff, MIN(g.tgl), SUM(g.debet), SUM(g.kredit), COUNT(*)
FROM gl_journal g WHERE g.modul_id='EX' AND g.doc_reff LIKE '%FR%'
GROUP BY g.doc_reff ORDER BY MIN(g.tgl)
"@
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "doc=[$($r[0])] tgl=$($r[1]) Dr=$($r[2]) Cr=$($r[3]) n=$($r[4])" }; $r.Close()

$out += ""
$out += "=== tstok1 tipe 05 / FR (2026) ==="
$cmd.CommandText = "SELECT order_client, tipe_trans, tgl, kurs, kurs1, kurs2, freight_kurs FROM tstok1 WHERE (tipe_trans='05' OR order_client LIKE '%FR%') AND tgl>='2026-01-01' ORDER BY tgl"
$r=$cmd.ExecuteReader(); while($r.Read()){ $out += "oc=[$($r[0])] tipe=$($r[1]) tgl=$($r[2]) kurs=$($r[3]) kurs1=$($r[4]) kurs2=$($r[5]) fkurs=$($r[6])" }; $r.Close()

$conn.Close()
$out -join "`r`n" | Set-Content c:\BTV\debug\diag116b_out.txt -Encoding UTF8
