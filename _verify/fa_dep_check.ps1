$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "FA_ASSET PKT-0180" "select asset_code,acquisition_date,acquisition_cost,residual_value,useful_life_month,accum_dep_beginning,book_value_beginning,beginning_period,status,category_code from FA_ASSET where asset_code='PKT-0180' and site_id='101'"

Qry "FA_DEPRECIATION kolom" "select first * from FA_DEPRECIATION"

Qry "FA_DEPRECIATION PKT-0180 (semua periode)" "select * from FA_DEPRECIATION where asset_code='PKT-0180' order by 2"

Qry "FA_DEPRECIATION PKT-0179 (pembanding, beli 15-01-2026)" "select * from FA_DEPRECIATION where asset_code='PKT-0179' order by 2"
$cn.Close()
