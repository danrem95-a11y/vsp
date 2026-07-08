$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Exec($label,$s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s
  try{$n=$c.ExecuteNonQuery();Write-Host ("  OK  "+$label+" (rows="+$n+")")}catch{Write-Host ("  ERR "+$label+": "+$_.Exception.Message)}}
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s;try{$rd=$c.ExecuteReader()}catch{Write-Host("  ERR:"+$_.Exception.Message);return};while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Write-Host "=== FIX effective_from: tgl_start(2026-05-31) bukan awal data -> 1900-01-01 ==="
Exec "fix effective_from" "UPDATE rekon_account_map SET effective_from='1900-01-01' WHERE effective_from > '1900-01-01'"
Exec "commit" "COMMIT"
Qry "SELECT domain, COUNT(*) n, MIN(effective_from) ef FROM rekon_account_map GROUP BY domain"
$cn.Close()
