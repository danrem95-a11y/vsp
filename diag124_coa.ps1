$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.ConnectionTimeout=20; $conn.Open()
$cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

# find COA table columns
Q "coa 102-601 (try gl_account)" "SELECT * FROM gl_account WHERE account_id='102-601'"
Q "coa 102-601 (try account)"    "SELECT * FROM account WHERE account_id='102-601'"
Q "coa 102-601 (try coa)"        "SELECT * FROM coa WHERE account_id='102-601'"
Q "coa 102-601 (try gl_coa)"     "SELECT * FROM gl_coa WHERE account_id='102-601'"
Q "equity/penyesuaian candidates 3xx & selisih" "SELECT account_id, nama FROM gl_account WHERE account_id LIKE '3%' OR nama LIKE '%aba ditahan%' OR nama LIKE '%enyesuaian%' OR nama LIKE '%elisih%' ORDER BY account_id"
Q "saldo 102-601 reconfirm" "SELECT SUM(debet) dr, SUM(kredit) cr, SUM(debet)-SUM(kredit) saldo FROM gl_journal WHERE account_id='102-601'"
Q "gl_journal columns probe (1 row EX)" "SELECT TOP 1 * FROM gl_journal WHERE modul_id='GJ' ORDER BY tgl DESC"

$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag124_coa_out.txt -Encoding UTF8
$out -join "`r`n"
