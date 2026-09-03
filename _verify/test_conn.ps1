function TryCS($lbl,$cs){
  Write-Host ""; Write-Host "== $lbl =="
  $cn=New-Object System.Data.Odbc.OdbcConnection $cs
  try{ $cn.Open(); $c=$cn.CreateCommand(); $c.CommandText="select db_name()"; Write-Host ("   OK -> db="+[string]$c.ExecuteScalar()); $cn.Close() }
  catch{ Write-Host ("   GAGAL: "+($_.Exception.Message -replace "`r`n"," | ")) }
}

# 1) Persis konfigurasi user (tanpa PWD, CommLinks pakai kurung kurawal {})
TryCS "1. Config user apa adanya (no PWD, {})" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;Compress=No;CommLinks=TCPIP{host=103.233.89.43;port=2638};DisableMultiRowFetch=No;Debug=No;Integrated=No;AutoStop=Yes;EngineName=vspnew"

# 2) Tambah PWD saja, tetap kurung kurawal {}
TryCS "2. + PWD=jakarta, tetap {}" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=TCPIP{host=103.233.89.43;port=2638};EngineName=vspnew"

# 3) PWD + kurung biasa ()
TryCS "3. + PWD=jakarta, CommLinks=tcpip( )" "DRIVER=Adaptive Server Anywhere 9.0;UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);EngineName=vspnew"
