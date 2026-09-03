$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 45){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 45){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
Tab @"
select count(*) n_ok
  from ZZ_WIPFIX_MAP_R3_20260810 m, tsales2 s2
 where s2.bukti_id=m.wo_bukti and s2.stok_id=m.stok_id and isnull(s2.evap,'')=isnull(m.evap,'')
   and abs(s2.hpp - round(m.hpp_new,2)) < 0.01
"@ "TSALES2 88 sudah ter-UPDATE? (8=sudah)"
Tab @"
select count(*) n_ok
  from ZZ_WIPFIX_MAP_R3_20260810 m, gl_journal g
 where g.voucher=m.voucher and g.account_id='102-020' and g.modul_id='AS'
   and abs(g.debet - round(m.hpp_new,2)) < 0.01
"@ "GL_JOURNAL Dr sudah ter-UPDATE? (8=sudah)"
$c.Close()
