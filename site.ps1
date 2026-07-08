$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Qry($s){$c=$cn.CreateCommand();$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Qry "select distinct site_id from gl_balance where AccountCode='102-201'"
Write-Host "-- gl_balance 102-201 & 102-001 (opening 2026) --"
Qry "select AccountCode, Period, cast(AmountDebet-AmountCredit as numeric(18,2)) opening from gl_balance where AccountCode in ('102-201','102-001') and year(Period)=2026"
$cn.Close()
