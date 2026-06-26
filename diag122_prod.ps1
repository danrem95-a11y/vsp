$ErrorActionPreference='Stop'
"=== Registered ODBC drivers (SQL Anywhere / ASA) ==="
$dpaths='HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBCINST.INI\ODBC Drivers','HKLM:\SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers'
$drivers=@()
foreach($p in $dpaths){ if(Test-Path $p){ (Get-ItemProperty $p).PSObject.Properties | Where-Object {$_.Name -match 'Anywhere|ASA|SQL Anywhere'} | ForEach-Object { "{0}" -f $_.Name; $drivers+=$_.Name } } }
$drivers=$drivers | Select-Object -Unique

$ip='103.233.89.43'
$base = "CommLinks=tcpip(HOST=$ip:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$try=@()
foreach($d in $drivers){ $try += "DRIVER={$d};$base" }
$try += "DRIVER={SQL Anywhere 11};$base"
$try += "DRIVER={SQL Anywhere 12};$base"
$try += "DRIVER={Adaptive Server Anywhere 9.0};$base"

$conn=$null
foreach($cs in $try){
  try{ $c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.ConnectionTimeout=15; $c.Open(); "`nCONNECTED: $cs"; $conn=$c; break }
  catch{ "FAILED [$($cs.Substring(0,[Math]::Min(40,$cs.Length)))...]: $($_.Exception.Message)" }
}
if($conn -eq $null){ "`n>>> gagal semua driver"; exit 1 }

$cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
"`n=== IDENTITAS SERVER PRODUKSI ==="
foreach($kv in @(@('db_name','SELECT db_name()'),@('ServerName',"SELECT property('ServerName')"),@('host',"SELECT property('MachineName')"),@('TcpIp',"SELECT property('TcpIpAddresses')"),@('DBFile',"SELECT db_property('File')"),@('Ver',"SELECT property('ProductVersion')"),@('now','SELECT now(*)'),@('gl_journal_n','SELECT COUNT(*) FROM gl_journal'))){
  try{ $cmd.CommandText=$kv[1]; "{0,-12}= {1}" -f $kv[0],$cmd.ExecuteScalar() }catch{ "{0,-12}= ERR {1}" -f $kv[0],$_.Exception.Message }
}
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

Q "102-601 GRAND total" "SELECT SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) saldo FROM gl_journal WHERE account_id='102-601'"
Q "102-601 by year net" "SELECT YEAR(tgl) y, SUM(debet)-SUM(kredit) net, COUNT(*) n FROM gl_journal WHERE account_id='102-601' GROUP BY YEAR(tgl) ORDER BY y"
Q "RECON 2026 main ekspedisi" @"
SELECT a.order_client doc, a.tgl, a.vendor_id, a.ttl_kotor ap_kotor,
  (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2_alloc,
  (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id LIKE '102-%') gl_main_persed
FROM ap_trans a WHERE a.tipe_trans='05' AND a.tgl>='2026-01-01' AND ISNULL(a.order_reff,'')='' ORDER BY a.tgl,a.order_client
"@
Q "Case1/2 header + GL" "SELECT order_client, ttl_kotor, ttl_netto, ttl_ppn FROM ap_trans WHERE order_client IN ('10126040500001','10126040500002')"

$conn.Close()
$txt=$out -join "`r`n"; $txt | Set-Content c:\BTV\debug\diag122_prod_out.txt -Encoding UTF8
"`n"+$txt
