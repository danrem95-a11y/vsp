$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=120; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
$engRaw = [System.IO.File]::ReadAllText("C:\BTV\debug\_engine_sql.txt")
$engRaw = [regex]::Replace($engRaw, '(?is)\s+ORDER\s+BY\s+[^)]*\)\s*A,IM_PRODUCT_GROUP', ') A,IM_PRODUCT_GROUP')

$eng = $engRaw -replace ':arg_tgl2', "'2026-03-31'"
$eng = $eng -replace ':arg_tgl', "'2026-03-01'"
$q = @"
select z.PRODUK_ID, z.PRODUK_DESC, z.AKHIR qty_akhir,
  cast(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP as numeric(16,2)) akhir_dihitung,
  cast(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-04-01'),0) as numeric(16,2)) tersimpan,
  cast( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-04-01'),0) as numeric(16,2)) gap
from ( $eng ) z
where z.PERSEDIAAN='102-001'
  and abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-04-01'),0) ) > 100
order by abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-04-01'),0) ) desc
"@
Tab $q "Item 102-001 Maret 2026 dgn gap formula-vs-SINV >Rp100 (kandidat akar penyebab Rp10,7jt)"
$c.Close()
