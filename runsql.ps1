param($f)
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$c=$cn.CreateCommand();$c.CommandTimeout=900;$c.CommandText=(Get-Content $f -Raw)
$sw=[Diagnostics.Stopwatch]::StartNew()
try{$rd=$c.ExecuteReader();$hdr=@();for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)};Write-Host ("  "+($hdr -join " | "))
 while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
catch{Write-Host("  ERR: "+$_.Exception.Message)}
$sw.Stop();Write-Host ("  ("+$sw.ElapsedMilliseconds+" ms)")
$cn.Close()
