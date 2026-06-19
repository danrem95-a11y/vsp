$dbisql = 'C:\Program Files (x86)\SQL Anywhere 11\bin32\dbisql.com'
$out    = 'c:\BTV\debug\diag89_bank_audit_out.txt'
$sql    = 'c:\BTV\debug\diag89_bank_audit.sql'
$conn   = 'DSN=vsp;UID=dba;PWD=jakarta'

& $dbisql -nogui -onerror continue -c $conn $sql 2>&1 | Tee-Object -FilePath $out
Write-Host "Output saved to $out"
