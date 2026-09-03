$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=60; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); $v+=[string]$x }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
Tab "select * from SYS_PROGRAM where lower(PROGRAMNAME) like '%refresh%' or lower(PROGRAMNAME) like '%journal%'" "1. Cari PROGRAMNAME terkait refresh/journal"
Tab "select * from SYS_PROGRAM where lower(PROGRAMGROUP) like '%refresh%' or lower(PROGRAMGROUP) like '%journal%'" "2. Cari PROGRAMGROUP terkait refresh/journal"
Tab "select top 1 * from SYS_PROGRAM where ISPROGRAM=1 and PROGRAMLEVEL>=3" "3. Contoh baris level program (bukan kategori) utk lihat pola ITEM1-5"
$c.Close()
