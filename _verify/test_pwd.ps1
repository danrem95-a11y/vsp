function T($lbl,$h,$eng,$pwd){
  $cs="DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=$pwd;CommLinks=TCPIP(host=$h;port=2638);ENG=$eng"
  $cn=New-Object System.Data.Odbc.OdbcConnection $cs
  try{ $cn.Open(); $c=$cn.CreateCommand(); $c.CommandText="select db_name()"; Write-Host ("   OK  $lbl (PWD=$pwd) -> db="+[string]$c.ExecuteScalar()); $cn.Close() }
  catch{ $m=$_.Exception.Message; if($m -match 'user ID or password'){Write-Host "   SALAH-PWD  $lbl (PWD=$pwd)"} elseif($m -match 'not found'){Write-Host "   TAK-TERJANGKAU  $lbl (PWD=$pwd)"} else {Write-Host ("   GAGAL  $lbl (PWD=$pwd): "+($m -replace "`r`n"," "))} }
}
Write-Host "== PROD 103.233.89.43 / vspnew =="
T "prod" "103.233.89.43" "vspnew" "jakarta"
T "prod" "103.233.89.43" "vspnew" "w1r4s"
Write-Host ""
Write-Host "== LOKAL localhost / vsp =="
T "lokal" "localhost" "vsp" "jakarta"
T "lokal" "localhost" "vsp" "w1r4s"
