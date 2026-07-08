$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$t=$cn.GetSchema("Columns", @($null,$null,"GL_JOURNAL",$null))
foreach($r in $t.Rows){ Write-Host ("  "+$r["ORDINAL_POSITION"]+"  "+$r["COLUMN_NAME"]+"  "+$r["TYPE_NAME"]) }
$cn.Close()
