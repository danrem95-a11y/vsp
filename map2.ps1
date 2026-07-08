$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Cols($tbl){ try{ $c=$cn.CreateCommand(); $c.CommandText="select * from "+$tbl+" where 1=0"; $rd=$c.ExecuteReader(); $a=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$a+=$rd.GetName($i)}; $rd.Close(); Write-Host ("  "+$tbl+" -> "+($a -join ", ")) }catch{ Write-Host ("  "+$tbl+" -> ERR "+$_.Exception.Message) } }
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
Cols "IM_PRODUCT_GROUP"
Cols "groupxx"
Cols "gl_group"
Write-Host "=== isi IM_PRODUCT_GROUP (5 baris, lihat kolom akun) ==="
Reader "select top 5 * from IM_PRODUCT_GROUP"
$cn.Close()
