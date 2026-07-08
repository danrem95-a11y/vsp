$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Scalar($sql){ $c=$cn.CreateCommand(); $c.CommandText=$sql; try{return $c.ExecuteScalar()}catch{return $null} }
$myNo=[int](Scalar "select connection_property('Number')")
try{ $c=$cn.CreateCommand(); $c.CommandText="set option public.remember_last_statement='On'"; $c.ExecuteNonQuery()|Out-Null }catch{}
$seen=@{}
Write-Host "Poll cepat 12 detik utk menangkap statement app..."
for($i=0; $i -lt 60; $i++){
  $c=$cn.CreateCommand(); $c.CommandText="select Number, Value from sa_conn_properties() where PropName='LastStatement' and Value<>'' and Number<>$myNo"
  try{ $rd=$c.ExecuteReader(); while($rd.Read()){ $k=[string]$rd[0]+"|"+[string]$rd[1]; if(-not $seen.ContainsKey($k)){ $seen[$k]=$true; Write-Host ("  c"+$rd[0]+": "+[string]$rd[1]) } }; $rd.Close() }catch{}
  Start-Sleep -Milliseconds 200
}
Write-Host ("`nTotal statement unik tertangkap: "+$seen.Count)
$cn.Close()
