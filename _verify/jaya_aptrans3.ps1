$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandTimeout=300
$c.CommandText="select first * from ap_trans where order_client='NOITEM260700029'"
try{
  $rd=$c.ExecuteReader()
  if($rd.Read()){
    for($i=0;$i -lt $rd.FieldCount;$i++){
      $v=[string]$rd[$i]
      Write-Host ("   {0,-22} = {1}" -f $rd.GetName($i), $v)
    }
  } else { Write-Host "   <tidak ada baris NOITEM260700029 di ap_trans>" }
  $rd.Close()
}catch{Write-Host("ERR: "+$_.Exception.Message)}
$cn.Close()
