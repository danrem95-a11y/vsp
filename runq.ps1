param([string]$File)
$ErrorActionPreference='Stop'
$q = Get-Content -Raw $File
$c=New-Object System.Data.Odbc.OdbcConnection('DSN=vsp;UID=dba;PWD=jakarta')
try{
  $c.Open(); $cmd=$c.CreateCommand(); $cmd.CommandTimeout=300; $cmd.CommandText=$q
  $r=$cmd.ExecuteReader(); $n=$r.FieldCount
  $h=@(); for($i=0;$i -lt $n;$i++){$h+=$r.GetName($i)}; ($h -join ' | ')
  while($r.Read()){ $v=@(); for($i=0;$i -lt $n;$i++){ $x=$r.GetValue($i); if($x -is [datetime]){$x=$x.ToString('yyyy-MM-dd')}; $v+=("$x").Trim() }; ($v -join ' | ') }
  $r.Close()
}catch{ "ERR => $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
finally{ $c.Close() }
