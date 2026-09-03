$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
$b=[System.IO.File]::ReadAllBytes("C:\BTV\debug\dw_refresh_stok.srd")
$t=[System.Text.Encoding]::Unicode.GetString($b)
$m=[regex]::Match($t,'(?s)retrieve="(.*?)"\s*arguments')
if(-not $m.Success){ $m=[regex]::Match($t,'(?s)retrieve="(.*?)"\s*\r?\n') }
$sql=$m.Groups[1].Value
$sql=$sql -replace ':arg_tgl2',"'2026-02-28'"
$sql=$sql -replace ':arg_tgl',"'2026-02-01'"
[System.IO.File]::WriteAllText("C:\BTV\debug\_retr_full.sql",$sql)
Write-Host ("panjang SQL: "+$sql.Length+" char")
$esc=$sql -replace "'","''"
$c=$P.CreateCommand(); $c.CommandTimeout=120; $c.CommandText="select plan('"+$esc+"') p from SYS.DUMMY"
try{ $v=$c.ExecuteScalar(); Write-Host "=== PLAN retrieve dw_refresh_stok (Feb) ==="; Write-Host $v }
catch{ Write-Host ("PLAN ERR: "+$_.Exception.Message) }
$P.Close()
