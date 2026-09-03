$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=90; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
Tab @"
select top 15 bukti_id, tgl, keterangan
  from tstok1 where tipe_trans='99' and tgl between '2026-01-01' and '2026-06-30'
 order by tgl
"@ "1. Contoh 15 baris tipe_trans=99 (keterangan)"

Tab @"
select top 5 t1.bukti_id, t1.tgl, t2.stok_id, cast(t2.qty as numeric(12,2)) qty, cast(t2.netto as numeric(16,2)) netto, cast(isnull(t2.hpp,0) as numeric(16,2)) hpp
  from tstok1 t1, tstok2 t2
 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='99' and t1.tgl between '2026-01-01' and '2026-06-30'
 order by t1.tgl
"@ "2. Contoh detail TSTOK2 utk tipe_trans=99 (qty positif/negatif = plus/minus?)"
$c.Close()
