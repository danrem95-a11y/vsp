$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Cols($tbl){ $t=$cn.GetSchema("Columns", @($null,$null,$tbl,$null)); Write-Host ("=== "+$tbl+" ===")
  $rows=@($t.Rows) | Sort-Object {[int]$_["ORDINAL_POSITION"]}
  foreach($r in $rows){ Write-Host ("  "+$r["ORDINAL_POSITION"]+"  "+$r["COLUMN_NAME"]+"  "+$r["TYPE_NAME"]) } }
Cols "TSTOK1"
Cols "TSTOK2"
$cn.Close()
