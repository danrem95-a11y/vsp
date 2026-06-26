$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=180
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();$n=0;while($r.Read()){$n++;$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};if($n -eq 0){$script:out+="(0)"};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

# FR yg kredit ke 226-006: rentang tanggal + vendor (regresi?)
Q "FR -> 226-006 : sebaran tgl & jumlah" "SELECT MIN(tgl) tgl_min, MAX(tgl) tgl_max, COUNT(*) n FROM gl_journal WHERE modul_id='EX' AND doc_reff LIKE '%FR%' AND account_id='226-006' AND kredit>0"
Q "FR -> 226-006 : per bulan" "SELECT YEAR(tgl) y, MONTH(tgl) m, COUNT(*) n, SUM(kredit) kr FROM gl_journal WHERE modul_id='EX' AND doc_reff LIKE '%FR%' AND account_id='226-006' AND kredit>0 GROUP BY YEAR(tgl),MONTH(tgl) ORDER BY y,m"
Q "FR -> 102-601 : rentang tgl" "SELECT MIN(tgl) tgl_min, MAX(tgl) tgl_max, COUNT(*) n FROM gl_journal WHERE modul_id='EX' AND doc_reff LIKE '%FR%' AND account_id='102-601' AND kredit>0"
# state terkini 2 dok April: jurnal lengkap (baris & akun)
Q "Jurnal EX lengkap doc 10126040500001 + FR05001 (state kini)" "SELECT doc_reff, urut, account_id, debet, kredit, ket FROM gl_journal WHERE modul_id='EX' AND doc_reff IN ('10126040500001','1012604FR05001') ORDER BY doc_reff, urut"
Q "main doc April: ap_kotor vs tstok2 vs GL persediaan (cek nilai 13.244.609 muncul lagi?)" @"
SELECT a.order_client doc, a.ttl_kotor ap_kotor,
 (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2_alloc,
 (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id='102-101') gl_persed
FROM ap_trans a WHERE a.order_client IN ('10126040500001','10126040500002')
"@
# ap_trans anak April: freight terisi lagi?
Q "ap_trans FR April: freight/ttl kini" "SELECT order_client, ttl_kotor, ttl_netto, freight, kurs, kurs2 FROM ap_trans WHERE order_client IN ('1012604FR05001','1012604FR05002')"
$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag131_regression_out.txt -Encoding UTF8
($out -join "`r`n")
