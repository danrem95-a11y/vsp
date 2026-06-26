$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();$any=$false;while($r.Read()){$any=$true;$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};if(-not $any){$script:out+="(0 baris)"};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

Q "1. Jurnal EX FR (masih ada / sudah dihapus?)" "SELECT doc_reff, urut, account_id, debet, kredit, tgl, ket FROM gl_journal WHERE modul_id='EX' AND doc_reff IN ('1012604FR05001','1012604FR05002') ORDER BY doc_reff, urut"
Q "2. ap_trans FR sekarang (ttl vs freight)" "SELECT order_client, ttl_kotor, ttl_netto, ttl_ppn, freight, kurs, kurs2 FROM ap_trans WHERE order_client IN ('1012604FR05001','1012604FR05002')"
Q "3. ap_trans MAIN sekarang" "SELECT order_client, ttl_kotor, ttl_netto, ttl_ppn, freight, kurs2 FROM ap_trans WHERE order_client IN ('10126040500001','10126040500002')"
Q "4. tstok2 alloc utama" "SELECT bukti_id, SUM(biaya_ekspedisi*qty) alloc FROM tstok2 WHERE bukti_id IN ('10126040500001','10126040500002') GROUP BY bukti_id"
Q "5. apakah tabel backup diag117 ADA?" "SELECT table_name FROM systable WHERE table_name LIKE 'diag117%' ORDER BY table_name"
Q "6. backup ap_trans FR (nilai ASLI sebelum script)" "SELECT order_client, ttl_kotor, ttl_netto, freight, kurs, kurs2 FROM diag117_backup_aptrans WHERE order_client IN ('1012604FR05001','1012604FR05002')"
Q "7. backup ap_trans MAIN (nilai ASLI sebelum script)" "SELECT order_client, ttl_kotor, ttl_netto FROM diag117_backup_aptrans WHERE order_client IN ('10126040500001','10126040500002')"
Q "8. backup GL (jurnal FR asli sebelum script)" "SELECT doc_reff, urut, account_id, debet, kredit FROM diag117_backup_gl WHERE doc_reff IN ('1012604FR05001','1012604FR05002') ORDER BY doc_reff,urut"
Q "9. backup tstok2 alloc asli" "SELECT bukti_id, SUM(biaya_ekspedisi*qty) alloc_asli FROM diag117_backup_tstok2 GROUP BY bukti_id"

$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag129_frcheck_out.txt -Encoding UTF8
($out -join "`r`n")
