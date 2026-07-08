$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Cols($tbl){ try{ $c=$cn.CreateCommand(); $c.CommandText="select * from "+$tbl+" where 1=0"; $rd=$c.ExecuteReader(); $a=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$a+=$rd.GetName($i)}; $rd.Close(); Write-Host ("  "+$tbl+" -> "+($a -join ", ")) }catch{ Write-Host ("  "+$tbl+" -> (tidak ada)") } }
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Write-Host "=== tabel kandidat group ==="
Reader "select table_name from SYS.SYSTABLE where lower(table_name) like '%group%' or lower(table_name) like '%grup%' order by table_name"
Write-Host "=== kolom mgroup & im_produk ==="
Cols "mgroup"
Cols "im_produk"
$cn.Close()
