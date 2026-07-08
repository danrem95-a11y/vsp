$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Cols($t){ $c=$cn.GetSchema("Columns",@($null,$null,$t,$null)); $n=@(); foreach($r in ($c.Rows|Sort-Object {[int]$_["ORDINAL_POSITION"]})){ $n+=($r["COLUMN_NAME"]+":"+$r["TYPE_NAME"]) }; Write-Host ("=== "+$t+" ("+$n.Count+") ==="); Write-Host ("  "+($n -join ", ")) }
Cols "MFAKTUR"
Cols "TINKASO1"
Cols "TINKASO2"
Cols "SKAS"
Cols "SALDO_AWAL_FAKTUR"
Cols "t_opname_ap"
Cols "t_opname_ar"
$cn.Close()
