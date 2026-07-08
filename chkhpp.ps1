$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$c=$cn.CreateCommand();$c.CommandText="select kode_group,nama_group,hpp,persediaan from im_product_group where nama_group like '%THERMO%' or kode_group='TR'"
$rd=$c.ExecuteReader()
while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}
$cn.Close()
