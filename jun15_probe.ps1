$cn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; return [double]$c.ExecuteScalar() }

Write-Host "=== sa_conn_info (semua kolom, lihat blocked/lock) ==="
Reader "select * from sa_conn_info()"

Write-Host "`n=== Engine aktif kerja atau idle? (sample counter 2x jeda 6 dtk) ==="
$props = "'DiskRead','DiskReadTime','CacheRead','CacheHits','ProcessCPU','Req','ActiveReq'"
$c=$cn.CreateCommand(); $c.CommandText="select PropName, Value from sa_eng_properties() where PropName in ($props)"
$t0=@{}; $rd=$c.ExecuteReader(); while($rd.Read()){ $t0[$rd[0]]=[double]$rd[1] }; $rd.Close()
Start-Sleep -Seconds 6
$c.CommandText="select PropName, Value from sa_eng_properties() where PropName in ($props)"
$t1=@{}; $rd=$c.ExecuteReader(); while($rd.Read()){ $t1[$rd[0]]=[double]$rd[1] }; $rd.Close()
foreach($k in $t0.Keys){ Write-Host ("  {0,-14} : {1,14} -> {2,14}   delta={3}" -f $k,$t0[$k],$t1[$k],($t1[$k]-$t0[$k])) }

$cn.Close()
