$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
$cols="cast(q.AWAL_RP as numeric(18,2)) awal_rp, cast(q.BELI_RP as numeric(18,2)) beli_rp, cast(q.MUTASI_IN_RP as numeric(18,2)) mutin, cast(q.JUAL_REAL as numeric(18,2)) jual_real, cast(q.JUAL_BY_EVAP_RP as numeric(18,2)) jual_evap, cast(q.CONSIN_RP as numeric(18,2)) consin, cast(q.CONSIN_BY_EVAP_RP as numeric(18,2)) consin_evap, cast(q.CONSOUT_RP as numeric(18,2)) consout, cast(q.MUTASI_OUT_RP as numeric(18,2)) mutout, cast(q.RET_BELI_RP as numeric(18,2)) retbeli"
function Dump($label,$sqlfile){
  $sql=Get-Content $sqlfile -Raw
  $q="select $cols from ( $sql ) q where q.PRODUK_ID='TR.1006A'"
  $c=$cn.CreateCommand();$c.CommandTimeout=400;$c.CommandText=$q;$rd=$c.ExecuteReader()
  Write-Host $label
  while($rd.Read()){for($i=0;$i -lt $rd.FieldCount;$i++){Write-Host ("   "+$rd.GetName($i)+" = "+$rd[$i])}}
  $rd.Close()
}
Dump "=== REPORT (dw_stok_gl_mutasi fixed) TR.1006A ===" "C:/BTV/debug/_tr.sql"
Dump "=== REFRESH (dw_refresh_stok = SINV/ledger) TR.1006A ===" "C:/BTV/debug/_dwrs_TR.sql"
$cn.Close()
