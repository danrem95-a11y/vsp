$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Go($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql; $c.ExecuteNonQuery()|Out-Null }
try{ Go "set option public.remember_last_statement='On'" }catch{}
$ok=$false
for($n=1; $n -le 12; $n++){
  try{
    Go "create index idx_tsales1_tgl on tsales1(tgl, tipe_trans)"
    Write-Host ("ATTEMPT {0}: OK - index dibuat!" -f $n); $ok=$true; break
  }catch{
    Write-Host ("ATTEMPT {0}: gagal - {1}" -f $n, ($_.Exception.Message -replace '.*Anywhere\]',''))
    try{ Go "rollback" }catch{}
    Start-Sleep -Milliseconds 1500
  }
}
if(-not $ok){
  Write-Host "`n=== Pemblokir (statement terakhir tiap koneksi app) ==="
  $c=$cn.CreateCommand(); $c.CommandText="select Number, Value from sa_conn_properties() where PropName='LastStatement' and Value<>''"
  try{$rd=$c.ExecuteReader(); while($rd.Read()){Write-Host ("  conn "+$rd[0]+": "+([string]$rd[1]).Substring(0,[Math]::Min(140,([string]$rd[1]).Length)))}; $rd.Close()}catch{Write-Host ("  "+$_.Exception.Message)}
}
$cn.Close()
