$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$inner=[System.IO.File]::ReadAllText("C:\BTV\debug\_test_movavg.sql")
# ringkasan regresi
$sql="select count(*) total, sum(case when new_hpp<>old_hpp then 1 else 0 end) berubah, sum(case when new_hpp<>old_hpp and old_hpp>0 then 1 else 0 end) regresi from ($inner) x"
$c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
try{ $rd=$c.ExecuteReader(); while($rd.Read()){ Write-Host ("  total={0} berubah={1} regresi={2}" -f $rd[0],$rd[1],$rd[2]) }; $rd.Close() }catch{ Write-Host ("ERR: "+$_.Exception.Message) }
# baris berubah
$sql2="select * from ($inner) x where new_hpp<>old_hpp order by stok_id"
$c.CommandText=$sql2
try{ $rd=$c.ExecuteReader(); Write-Host "-- baris berubah --"; while($rd.Read()){ Write-Host ("  {0} | {1} | old={2} new={3}" -f $rd[0],$rd[1],$rd[2],$rd[3]) }; $rd.Close() }catch{ Write-Host ("ERR2: "+$_.Exception.Message) }
$cn.Close()
