$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 25){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 25){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
$engRaw = [System.IO.File]::ReadAllText("C:\BTV\debug\_engine_sql.txt")
$engRaw = [regex]::Replace($engRaw, '(?is)\s+ORDER\s+BY\s+[^)]*\)\s*A,IM_PRODUCT_GROUP', ') A,IM_PRODUCT_GROUP')

# April boundary (akun 102-001, TR.*) -- harus TR.038A/TR.039A TIDAK muncul lagi sbg gap>100
$eng1 = $engRaw -replace ':arg_tgl2', "'2026-04-30'"
$eng1 = $eng1 -replace ':arg_tgl', "'2026-04-01'"
$q1 = @"
select z.PRODUK_ID, z.PRODUK_DESC, z.AKHIR qty_akhir,
  cast(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP as numeric(16,2)) akhir_dihitung,
  cast(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-05-01'),0) as numeric(16,2)) tersimpan
from ( $eng1 ) z
where z.PERSEDIAAN='102-001'
  and abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-05-01'),0) ) > 100
order by abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-05-01'),0) ) desc
"@
Tab $q1 "1. Item 102-001 April kontributor gap>Rp100 SEKARANG (dulu TR.038A ada di sini)"

# Mei boundary
$eng2 = $engRaw -replace ':arg_tgl2', "'2026-05-31'"
$eng2 = $eng2 -replace ':arg_tgl', "'2026-05-01'"
$q2 = @"
select z.PRODUK_ID, z.PRODUK_DESC, z.AKHIR qty_akhir,
  cast(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP as numeric(16,2)) akhir_dihitung,
  cast(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-06-01'),0) as numeric(16,2)) tersimpan
from ( $eng2 ) z
where z.PERSEDIAAN='102-001'
  and abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-06-01'),0) ) > 100
order by abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-06-01'),0) ) desc
"@
Tab $q2 "2. Item 102-001 Mei kontributor gap>Rp100 SEKARANG"

# Juni boundary
$eng3 = $engRaw -replace ':arg_tgl2', "'2026-06-30'"
$eng3 = $eng3 -replace ':arg_tgl', "'2026-06-01'"
$q3 = @"
select z.PRODUK_ID, z.PRODUK_DESC, z.AKHIR qty_akhir,
  cast(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP as numeric(16,2)) akhir_dihitung,
  cast(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-07-01'),0) as numeric(16,2)) tersimpan
from ( $eng3 ) z
where z.PERSEDIAAN='102-001'
  and abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-07-01'),0) ) > 100
order by abs( (z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
     - isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-07-01'),0) ) desc
"@
Tab $q3 "3. Item 102-001 Juni kontributor gap>Rp100 SEKARANG"
$c.Close()
