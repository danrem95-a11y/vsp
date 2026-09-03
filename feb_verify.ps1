$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; try{return [string]$c.ExecuteScalar()}catch{return "ERR: "+$_.Exception.Message} }
$opn=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql")
$opn=$opn -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''   # buang ORDER BY final + ';'
function OpnameTotal($t1,$t2){
  $q=$opn -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"
  return Val "select cast(sum(SISA_IDR) as numeric(18,2)) from ($q) x"
}
Write-Host "=== OPNAME PIUTANG saldo akhir per bulan (total SISA_IDR) ==="
Write-Host ("  Jan : "+(OpnameTotal '2026-01-01' '2026-01-31'))
Write-Host ("  Feb : "+(OpnameTotal '2026-02-01' '2026-02-28')+"   (benar lama=31.245.559.808,10 ; ter-disturb=31.280.559.808,10)")
Write-Host ("  Mar : "+(OpnameTotal '2026-03-01' '2026-03-31'))
Write-Host ("  Apr : "+(OpnameTotal '2026-04-01' '2026-04-30'))
Write-Host ("  Mei : "+(OpnameTotal '2026-05-01' '2026-05-31'))
$cn.Close()
