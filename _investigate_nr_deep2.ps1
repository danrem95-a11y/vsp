$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 60){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 60){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# Semua pembelian (02) NR bulan Mei dgn coa_id (serial)
Tab @"
select t1.bukti_id, t1.tgl, t2.stok_id, t2.coa_id, t2.qty, cast(t2.netto as numeric(16,2)) netto, cast(t2.hpp as numeric(16,2)) hpp
  from tstok1 t1, tstok2 t2
 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
   and t1.tgl between '2026-05-01' and '2026-05-31'
   and t2.stok_id like 'NR.%A'
 order by t1.tgl
"@ "1. Pembelian (tipe 02) NR *A (serial) bulan Mei"

# WIP-out NR bulan Mei dgn coa_id via evap kolom tsales2 (yg memang ada)
Tab @"
select s1.tgl, s2.stok_id, s2.evap, s2.qty, cast(s2.hpp as numeric(16,2)) hpp, s1.order_client
  from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88'
   and s1.tgl between '2026-05-01' and '2026-05-31'
   and s2.stok_id like 'NR.%A'
 order by s1.tgl
"@ "2. WIP-Out NR *A bulan Mei (evap=serial)"
$c.Close()
