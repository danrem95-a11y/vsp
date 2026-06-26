$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }
Q "Akun ekuitas/laba & penyesuaian (dari gl_report_detail)" "SELECT DISTINCT account_id, description FROM gl_report_detail WHERE account_id LIKE '3%' OR description LIKE '%aba %' OR description LIKE '%enyesuaian%' OR description LIKE '%elisih%' OR description LIKE '%itahan%' ORDER BY account_id"
Q "Akun 3xx terpakai di gl_journal (saldo)" "SELECT account_id, SUM(debet-kredit) saldo, COUNT(*) n FROM gl_journal WHERE account_id LIKE '3%' GROUP BY account_id ORDER BY account_id"
$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag128_equity_out.txt -Encoding UTF8
($out -join "`r`n")
