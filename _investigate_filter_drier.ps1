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

# 1. SINV histori TS.066-8344C Jan-Jul (lihat kapan mulai negatif ekstrem)
Tab @"
select periode, cast(qty as numeric(12,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(16,2)) hpp_avg
  from sinv
 where stok_id='TS.066-8344C'
 order by periode
"@ "1. SINV TS.066-8344C semua periode (cari kapan mulai anomali)"

# 2. Semua mutasi TSTOK2 (pembelian dll) utk item ini Jan-Jun
Tab @"
select t1.tipe_trans, t1.tgl, t1.bukti_id, cast(t2.qty as numeric(12,2)) qty, cast(t2.netto as numeric(16,2)) netto, cast(isnull(t2.hpp,0) as numeric(16,2)) hpp
  from tstok1 t1, tstok2 t2
 where t1.bukti_id=t2.bukti_id and t2.stok_id='TS.066-8344C'
   and t1.tgl between '2026-01-01' and '2026-06-30'
 order by t1.tgl
"@ "2. Semua mutasi TSTOK2 (in) TS.066-8344C Jan-Jun"

# 3. Semua penjualan TSALES2 utk item ini Jan-Jun
Tab @"
select s1.tipe_trans, s1.tgl, s1.bukti_id, cast(s2.qty as numeric(12,2)) qty, cast(s2.netto as numeric(16,2)) netto, cast(isnull(s2.hpp,0) as numeric(16,2)) hpp
  from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s2.stok_id='TS.066-8344C'
   and s1.tgl between '2026-01-01' and '2026-06-30'
 order by s1.tgl
"@ "3. Semua penjualan/keluar TSALES2 TS.066-8344C Jan-Jun"
$c.Close()
