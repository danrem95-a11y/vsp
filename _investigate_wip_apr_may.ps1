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

# TR.038A: semua WIP-OUT (tsales 88, dgn evap/coa serial) April, lengkap dgn evap
Tab @"
select s1.bukti_id, s1.tgl, s1.order_client, isnull(s2.evap,'') evap, cast(s2.qty as numeric(10,2)) qty, cast(s2.hpp as numeric(16,2)) hpp
from tsales1 s1, tsales2 s2 where s1.bukti_id=s2.bukti_id and s2.stok_id='TR.038A' and s1.tipe_trans='88' and s1.tgl between '2026-04-01' and '2026-04-30'
order by s1.tgl
"@ "1. TR.038A WIP-OUT (tsales 88) April, dgn EVAP serial"

# TR.038A: semua WIP-IN (tstok 88) sepanjang tahun (utk lihat serial mana yg sudah/blm masuk kembali)
Tab @"
select t1.bukti_id, t1.tgl, isnull(t2.coa_id,'') coa_id, cast(t2.qty as numeric(10,2)) qty, cast(t2.netto as numeric(16,2)) netto
from tstok1 t1, tstok2 t2 where t1.bukti_id=t2.bukti_id and t2.stok_id='TR.038A' and t1.tipe_trans='88'
order by t1.tgl
"@ "2. TR.038A WIP-IN (tstok 88) SEMUA periode -- cek serial mana yg match"

# TR.038A: semua jual reguler (tsales 22) April, dgn evap
Tab @"
select s1.bukti_id, s1.tgl, isnull(s2.evap,'') evap, cast(s2.qty as numeric(10,2)) qty, cast(s2.hpp as numeric(16,2)) hpp
from tsales1 s1, tsales2 s2 where s1.bukti_id=s2.bukti_id and s2.stok_id='TR.038A' and s1.tipe_trans='22' and s1.tgl between '2026-04-01' and '2026-04-30'
order by s1.tgl
"@ "3. TR.038A jual reguler (tsales 22) April, dgn EVAP serial"
$c.Close()
