$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$sql = [System.IO.File]::ReadAllText("C:\BTV\debug\_test_tstok2_select.sql")
$c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
Write-Host "=== Hasil SELECT tstok2 (patched) utk NR.201A order 10126062200169 ==="
try{
  $rd=$c.ExecuteReader()
  while($rd.Read()){
    $bukti=$rd["bukti_id"]; $stok=$rd["stok_id"]; $netto=$rd["netto"]; $hpp=$rd["hpp"]; $nh=$rd["netto_hpp"]
    Write-Host ("  bukti={0} stok={1} netto={2} hpp={3} netto_hpp={4}" -f $bukti,$stok,$netto,$hpp,$nh)
  }
  $rd.Close()
  Write-Host "STATEMENT VALID (jalan tanpa error)"
}catch{ Write-Host ("SQL ERROR: "+$_.Exception.Message) }
$cn.Close()
