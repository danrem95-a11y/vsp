$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=180
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();$n=0;while($r.Read()){$n++;$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};if($n -eq 0){$script:out+="(0)"};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

# Akun kredit non-persediaan yg dipakai jurnal freight (doc_reff mengandung 'FR'), seluruh sejarah
Q "Akun KREDIT pada jurnal EX dok freight (doc_reff LIKE %FR%) - histori" "SELECT account_id, COUNT(*) n, SUM(kredit) total_kredit FROM gl_journal WHERE modul_id='EX' AND doc_reff LIKE '%FR%' AND kredit>0 GROUP BY account_id ORDER BY account_id"
# Vendor dari dokumen FR (ap_trans anak) + akun kredit jurnalnya, 2025-2026
Q "Vendor FR (ap_trans anak) tipe 05, 2025-2026" "SELECT vendor_id, COUNT(*) n FROM ap_trans WHERE order_client LIKE '%FR%' AND tipe_trans='05' GROUP BY vendor_id ORDER BY vendor_id"
# Semua vendor 'supplier lain-lain'-ish di master
Q "Master supplier mengandung 'LAIN'" "SELECT supplier_id, nama FROM mcstsupp WHERE upper(nama) LIKE '%LAIN%' ORDER BY supplier_id"
# detail: untuk tiap dok FR 2026, vendor + akun kredit jurnalnya
Q "Per dok FR 2026: vendor + akun kredit" @"
SELECT a.order_client doc, a.vendor_id,
 (SELECT MIN(g.account_id) FROM gl_journal g WHERE g.doc_reff=a.order_client AND g.modul_id='EX' AND g.kredit>0) kredit_acc
FROM ap_trans a WHERE a.order_client LIKE '%FR%' AND a.tipe_trans='05' AND a.tgl>='2025-01-01'
ORDER BY a.tgl
"@
$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag130_frvendor_out.txt -Encoding UTF8
($out -join "`r`n")
