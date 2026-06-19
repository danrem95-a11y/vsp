$dbisql = "C:\Program Files (x86)\SQL Anywhere 11\bin32\dbisql.com"
$conn   = "DSN=vsp;UID=dba;PWD=jakarta"
$sql    = "c:\BTV\debug\diag89_bank_audit.sql"
$out    = "c:\BTV\debug\diag89_bank_audit_out.txt"

& $dbisql -nogui -onerror continue -c $conn -q $sql > $out 2>&1
Write-Host "Done. Output: $out"
