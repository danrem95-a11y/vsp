$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$t=$cn.GetSchema("Tables")
$names=@()
foreach($r in $t.Rows){ if($r["TABLE_TYPE"] -eq "TABLE"){ $names+=[string]$r["TABLE_NAME"] } }
Write-Host ("total tabel: "+$names.Count)
Write-Host "=== tabel kandidat AP/AR/faktur/bayar/saldo/setup ==="
$names | Where-Object { $_ -match '(?i)hutang|piutang|faktur|bayar|terima|inkaso|giro|saldo|opname|_ap|_ar|kas|bank|dp_|uang_muka|retur|payment|alokasi|lunas|invoice|beli|jual|purch|sales_hdr|voucher' } | Sort-Object | ForEach-Object { Write-Host ("  "+$_) }
Write-Host "=== kolom gl_setup (kemungkinan mapping akun) ==="
$c=$cn.GetSchema("Columns",@($null,$null,"gl_setup",$null))
foreach($r in ($c.Rows|Sort-Object {[int]$_["ORDINAL_POSITION"]})){ Write-Host ("  "+$r["COLUMN_NAME"]+" ("+$r["TYPE_NAME"]+")") }
$cn.Close()
