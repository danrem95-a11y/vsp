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

Tab @"
select periode, cast(qty as numeric(12,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp_avg
  from sinv
 where stok_id='TS.066-8344C' and periode between '2026-01-01' and '2026-07-31'
 order by periode
"@ "1. SINV TS.066-8344C khusus 2026 (pastikan periode persis mulai rusak)"

# Cek tipe_trans '19' mutasi keluar detail lebih lengkap (semua kolom relevan)
Tab @"
select t1.bukti_id, t1.tgl, cast(t2.qty as numeric(12,2)) qty, cast(t2.netto as numeric(18,2)) netto, cast(isnull(t2.hpp,0) as numeric(18,2)) hpp, t2.stok_bj, t1.ket
  from tstok1 t1, tstok2 t2
 where t1.bukti_id=t2.bukti_id and t2.stok_id='TS.066-8344C' and t1.tipe_trans='19'
   and t1.tgl between '2026-04-25' and '2026-05-10'
 order by t1.tgl
"@ "2. Detail transaksi '19' sekitar tanggal anomali (25 Apr - 10 Mei)"
$c.Close()
