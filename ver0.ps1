$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$t=$cn.GetSchema("Columns", @($null,$null,"GL_BALANCE",$null))
Write-Host "=== GL_BALANCE cols ==="
foreach($r in ($t.Rows|Sort-Object {[int]$_["ORDINAL_POSITION"]})){ Write-Host ("  "+$r["COLUMN_NAME"]+" ("+$r["TYPE_NAME"]+")") }
$c=$cn.CreateCommand(); $c.CommandText="select * from GL_BALANCE where account_id='102-110'"; $rd=$c.ExecuteReader()
Write-Host "=== contoh baris GL_BALANCE 102-110 ==="
while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()
$cn.Close()
