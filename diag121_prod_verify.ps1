$ErrorActionPreference='Stop'
$drv = 'C:\Program Files (x86)\Sybase\SQL Anywhere 9\win32\dbodbc9.dll'
$ip='103.233.89.43'
$candidates = @(
 "DRIVER={$drv};CommLinks=tcpip(HOST=$ip;PORT=2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta",
 "DRIVER={$drv};CommLinks=tcpip(HOST=$ip);DBN=vspnew;UID=dba;PWD=jakarta",
 "DRIVER={$drv};CommLinks=tcpip(HOST=$ip:2638);UID=dba;PWD=jakarta",
 "DRIVER={Adaptive Server Anywhere 9.0};CommLinks=tcpip(HOST=$ip;PORT=2638);DBN=vspnew;UID=dba;PWD=jakarta",
 "DRIVER={$drv};CommLinks=tcpip(HOST=$ip;PORT=2638);ENG=vsp;DBN=vspnew;UID=dba;PWD=jakarta"
)
$conn=$null
foreach($cs in $candidates){
  try{
    $c = New-Object System.Data.Odbc.OdbcConnection($cs)
    $c.ConnectionTimeout = 15
    $c.Open()
    "CONNECTED with: $cs"
    $conn=$c; break
  } catch { "FAILED: $($_.Exception.Message)  [cs: $($cs.Substring(0,[Math]::Min(70,$cs.Length)))...]" }
}
if($conn -eq $null){ "`n>>> Tidak bisa konek ke produksi dengan semua kandidat. Perlu ServerName/port yang benar."; exit 1 }

$cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
"`n=== IDENTITAS SERVER PRODUKSI ==="
$id = @{
 'db_name()'        = "SELECT db_name()"
 'ServerName'       = "SELECT property('ServerName')"
 'host/MachineName' = "SELECT property('MachineName')"
 'TcpIpAddresses'   = "SELECT property('TcpIpAddresses')"
 'DBFile'           = "SELECT db_property('File')"
 'now'              = "SELECT now(*)"
 'gl_journal n'     = "SELECT COUNT(*) FROM gl_journal"
}
foreach($k in $id.Keys){ try{ $cmd.CommandText=$id[$k]; "{0,-18}= {1}" -f $k,$cmd.ExecuteScalar() }catch{ "{0,-18}= ERR {1}" -f $k,$_.Exception.Message } }

$out=@()
function Q($t,$s){ $script:out+=""; $script:out+="=== $t ==="; try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

Q "102-601 GRAND total" "SELECT SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) saldo FROM gl_journal WHERE account_id='102-601'"
Q "102-601 by year (net)" "SELECT YEAR(tgl) y, SUM(debet)-SUM(kredit) net, COUNT(*) n FROM gl_journal WHERE account_id='102-601' GROUP BY YEAR(tgl) ORDER BY y"
Q "RECON 2026 main ekspedisi (faktur vs tstok2 vs GL)" @"
SELECT a.order_client doc, a.tgl, a.vendor_id, a.ttl_kotor ap_kotor,
  (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2_alloc,
  (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id LIKE '102-%') gl_main_persed
FROM ap_trans a
WHERE a.tipe_trans='05' AND a.tgl >= '2026-01-01' AND ISNULL(a.order_reff,'')=''
ORDER BY a.tgl, a.order_client
"@
Q "Case1/2 ap_trans header (cek nilai terkoreksi?)" "SELECT order_client, ttl_kotor, ttl_netto, ttl_ppn FROM ap_trans WHERE order_client IN ('10126040500001','10126040500002')"

$conn.Close()
$txt=$out -join "`r`n"
$txt | Set-Content c:\BTV\debug\diag121_prod_verify_out.txt -Encoding UTF8
"`n"+$txt
