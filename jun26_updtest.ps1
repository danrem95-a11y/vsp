$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($c,$sql){ $c.CommandText=$sql; return [string]$c.ExecuteScalar() }
$tx = $cn.BeginTransaction()
$c = $cn.CreateCommand(); $c.Transaction=$tx; $c.CommandTimeout=120
$before = Val $c "select cast(isnull(hpp,0) as numeric(18,2)) from tsales2 where bukti_id='10126062200169' and stok_id='NR.201A'"
Write-Host "SEBELUM sale hpp = $before"
$upd = @"
update tsales2
set hpp = isnull((select max(t2.hpp) from tstok2 t2
   where t2.bukti_id = '10226062200169' and t2.stok_id = tsales2.stok_id
   and isnull(t2.coa_id,'') = isnull(tsales2.evap,'')
   and isnull(t2.produk_id,'') = isnull(tsales2.cond,'')),hpp)
where bukti_id = '10126062200169' and
isnull(evap,'') <> '' and
isnull(hpp,0) = 0
"@
try{
  $c.CommandText=$upd; $rows=$c.ExecuteNonQuery()
  Write-Host "UPDATE OK, baris terpengaruh = $rows"
  $after = Val $c "select cast(isnull(hpp,0) as numeric(18,2)) from tsales2 where bukti_id='10126062200169' and stok_id='NR.201A'"
  Write-Host "SESUDAH (dalam txn) sale hpp = $after"
}catch{ Write-Host ("SQL ERROR: "+$_.Exception.Message) }
$tx.Rollback()
Write-Host "ROLLBACK dilakukan (prod TIDAK berubah)"
$c2=$cn.CreateCommand()
$chk = Val $c2 "select cast(isnull(hpp,0) as numeric(18,2)) from tsales2 where bukti_id='10126062200169' and stok_id='NR.201A'"
Write-Host "VERIFIKASI pasca-rollback sale hpp = $chk (harus sama dgn sebelum: $before)"
$cn.Close()
