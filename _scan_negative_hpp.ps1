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

# Scan SEMUA item dgn hpp_avg negatif ATAU |hpp_avg| tidak wajar (>10jt utk item non-unit/spare part) di SINV Jan-Jul 2026
Tab @"
select stok_id, periode, cast(qty as numeric(12,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp_avg
  from sinv
 where periode between '2026-01-01' and '2026-07-31'
   and (isnull(hpp_avg,0) < 0 or abs(isnull(nilai,0) / nullif(qty,0)) > 50000000)
 order by periode, abs(isnull(hpp_avg,0)) desc
"@ "1. SEMUA item dgn hpp_avg NEGATIF atau tidak wajar (>Rp50jt/unit) Jan-Jul 2026"

Tab @"
select count(distinct stok_id) n_item_terdampak
  from sinv
 where periode between '2026-01-01' and '2026-07-31'
   and (isnull(hpp_avg,0) < 0 or abs(isnull(nilai,0) / nullif(qty,0)) > 50000000)
"@ "2. Jumlah item unik terdampak"
$c.Close()
