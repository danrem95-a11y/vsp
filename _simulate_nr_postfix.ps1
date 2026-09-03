$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=180; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 60){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 60){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
$engRaw = [System.IO.File]::ReadAllText("C:\BTV\debug\_engine_sql.txt")
$engRaw = [regex]::Replace($engRaw, '(?is)\s+ORDER\s+BY\s+[^)]*\)\s*A,IM_PRODUCT_GROUP', ') A,IM_PRODUCT_GROUP')

# 1. Simulasi Mei: hitung AKHIR_DIHITUNG (pakai TSALES2 yg SUDAH dikoreksi) utk NR *A -- prediksi qty & nilai post-refresh
$eng1 = $engRaw -replace ':arg_tgl2', "'2026-05-31'"
$eng1 = $eng1 -replace ':arg_tgl', "'2026-05-01'"
$q1 = @"
select z.PRODUK_ID, z.AKHIR qty_akhir_simulasi,
  cast(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP as numeric(16,2)) nilai_akhir_simulasi_mei,
  cast(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='2026-05-01'),0) as numeric(16,2)) nilai_tersimpan_saat_ini_awal_mei
from ( $eng1 ) z
where z.PERSEDIAAN='102-003' and z.PRODUK_ID like 'NR.%A'
order by z.PRODUK_ID
"@
Tab $q1 "1. SIMULASI Mei (formula pakai TSALES2 SUDAH dikoreksi) -- prediksi qty/nilai closing Mei utk NR *A"

# 2. Total 102-003 semua item Mei -- prediksi total opname pasca refresh Mei
$q1b = @"
select cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
       - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(18,2)) prediksi_opname_akhir_mei
from ( $eng1 ) z
where z.PERSEDIAAN='102-003'
"@
Tab $q1b "2. PREDIKSI total Opname 102-003 akhir Mei (semua item, formula dgn data terkoreksi)"

# 3. GL 102-003 akhir Mei (SUDAH pasti benar krn kita update GL langsung, tinggal bandingkan)
Tab @"
select cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-003' and b.Period='2026-01-01')
   + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-003' and g.tgl between '2026-01-01' and '2026-05-31'),0) as numeric(18,2)) ledger_gl_akhir_mei
"@ "3. GL 102-003 akhir Mei SEKARANG (sudah pasti benar, sudah kita update)"
$c.Close()
