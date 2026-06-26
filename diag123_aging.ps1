$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.ConnectionTimeout=20; $conn.Open()
$cmd=$conn.CreateCommand(); $cmd.CommandTimeout=300
"CONNECTED db=$($conn.CreateCommand().ExecuteScalar)"
$cmd.CommandText="SELECT db_name()"; "DB = $($cmd.ExecuteScalar())  host=" + (New-Object Data.Odbc.OdbcCommand("SELECT property('MachineName')",$conn)).ExecuteScalar()
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

$out += "###################### LAPORAN 1: AGING / DEKOMPOSISI 102-601 ######################"

Q "1a. Saldo per tahun + saldo akumulatif akhir tahun" @"
SELECT YEAR(tgl) y, SUM(debet) dr, SUM(kredit) cr, SUM(debet-kredit) yr_net,
 (SELECT SUM(debet-kredit) FROM gl_journal g2 WHERE g2.account_id='102-601' AND YEAR(g2.tgl)<=YEAR(g1.tgl)) cum_saldo
FROM gl_journal g1 WHERE account_id='102-601' GROUP BY YEAR(tgl) ORDER BY y
"@

Q "1b. Rekonsiliasi by-NILAI (seluruh ledger): OVER-CREDIT = legacy hole (kredit>debet), top 25" @"
SELECT TOP 25 amt, dcnt, ccnt, (ccnt-dcnt) netcnt, (ccnt-dcnt)*amt over_credit
FROM ( SELECT amt, SUM(d) dcnt, SUM(c) ccnt FROM (
   SELECT debet amt, COUNT(*) d, 0 c FROM gl_journal WHERE account_id='102-601' AND debet>0 GROUP BY debet
   UNION ALL SELECT kredit amt, 0 d, COUNT(*) c FROM gl_journal WHERE account_id='102-601' AND kredit>0 GROUP BY kredit
 ) x GROUP BY amt ) y WHERE ccnt>dcnt ORDER BY (ccnt-dcnt)*amt DESC
"@

Q "1c. TOTAL over-credit (legacy hole) vs TOTAL under-credit (open in-transit)" @"
SELECT
 (SELECT SUM((ccnt-dcnt)*amt) FROM (SELECT amt,SUM(d) dcnt,SUM(c) ccnt FROM (
   SELECT debet amt,COUNT(*) d,0 c FROM gl_journal WHERE account_id='102-601' AND debet>0 GROUP BY debet
   UNION ALL SELECT kredit amt,0 d,COUNT(*) c FROM gl_journal WHERE account_id='102-601' AND kredit>0 GROUP BY kredit) x GROUP BY amt) z WHERE ccnt>dcnt) total_over_credit_legacy,
 (SELECT SUM((dcnt-ccnt)*amt) FROM (SELECT amt,SUM(d) dcnt,SUM(c) ccnt FROM (
   SELECT debet amt,COUNT(*) d,0 c FROM gl_journal WHERE account_id='102-601' AND debet>0 GROUP BY debet
   UNION ALL SELECT kredit amt,0 d,COUNT(*) c FROM gl_journal WHERE account_id='102-601' AND kredit>0 GROUP BY kredit) x GROUP BY amt) z WHERE dcnt>ccnt) total_under_credit_open
"@

Q "1d. 2026 detail (semua baris 102-601) - utk lihat matched vs open" @"
SELECT tgl, modul_id, CAST(debet AS numeric(15,0)) dr, CAST(kredit AS numeric(15,0)) cr, ket
FROM gl_journal WHERE account_id='102-601' AND tgl>='2026-01-01' ORDER BY tgl, modul_id
"@

Q "1e. 2026 nilai under-credit (debet tanpa kredit pasangan) = OPEN in-transit" @"
SELECT amt, dcnt, ccnt, (dcnt-ccnt) open_cnt, (dcnt-ccnt)*amt open_value FROM (
  SELECT amt, SUM(d) dcnt, SUM(c) ccnt FROM (
   SELECT debet amt,COUNT(*) d,0 c FROM gl_journal WHERE account_id='102-601' AND debet>0 AND tgl>='2026-01-01' GROUP BY debet
   UNION ALL SELECT kredit amt,0 d,COUNT(*) c FROM gl_journal WHERE account_id='102-601' AND kredit>0 AND tgl>='2026-01-01' GROUP BY kredit
  ) x GROUP BY amt) y WHERE dcnt>ccnt ORDER BY (dcnt-ccnt)*amt DESC
"@

$out += ""
$out += "###################### LAPORAN 2: DRILL-DOWN LEGACY 2015-2016 ######################"

Q "2a. Semua baris 102-601 mengandung 'TK.107' (kasus -300jt)" @"
SELECT tgl, modul_id, doc_reff, CAST(debet AS numeric(15,0)) dr, CAST(kredit AS numeric(15,0)) cr, ket
FROM gl_journal WHERE account_id='102-601' AND ket LIKE '%TK.107%' ORDER BY tgl
"@

Q "2b. 2015 H1 (Jan-Jun) semua baris EX (kredit kapitalisasi) - cek barang dari 2014" @"
SELECT tgl, doc_reff, CAST(kredit AS numeric(15,0)) cr, ket
FROM gl_journal WHERE account_id='102-601' AND modul_id='EX' AND tgl>='2015-01-01' AND tgl<'2015-07-01' ORDER BY tgl
"@

Q "2c. EX credits 2015-2016 yg TIDAK ada debet senilai sama di SELURUH ledger 102-601 (top 25 over-credit)" @"
SELECT TOP 25 amt, dcnt, ccnt, (ccnt-dcnt)*amt over_credit FROM (
  SELECT amt, SUM(d) dcnt, SUM(c) ccnt FROM (
   SELECT debet amt,COUNT(*) d,0 c FROM gl_journal WHERE account_id='102-601' AND debet>0 GROUP BY debet
   UNION ALL SELECT kredit amt,0 d,COUNT(*) c FROM gl_journal WHERE account_id='102-601' AND kredit>0 AND YEAR(tgl) IN (2015,2016) GROUP BY kredit
  ) x GROUP BY amt) y WHERE ccnt>dcnt ORDER BY (ccnt-dcnt)*amt DESC
"@

$conn.Close()
$txt=$out -join "`r`n"; $txt | Set-Content c:\BTV\debug\diag123_aging_out.txt -Encoding UTF8
$txt
