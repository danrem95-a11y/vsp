$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== SINV_COPY: total per periode + LC.12.0012 (masih bersih?) ==="
Reader "select periode, cast(sum(nilai) as numeric(18,0)) total_nilai, sum(case when nilai<0 then 1 else 0 end) neg from sinv_copy where periode between '2026-04-01' and '2026-06-01' group by periode order by periode"
Write-Host "--- LC.12.0012 di SINV_COPY ---"
Reader "select periode, cast(qty as numeric(18,2)) qty, cast(hpp_avg as numeric(18,2)) hpp from sinv_copy where stok_id='LC.12.0012' and periode in ('2026-04-01','2026-05-01')"
$cn.Close()
