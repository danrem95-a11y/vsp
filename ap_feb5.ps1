$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$q=$ap -replace ':arg_tgl1',"'2026-02-01'" -replace ':arg_tgl2',"'2026-02-28'"

Qry "1. Split SISA_IDR: total positif (hutang) vs negatif (over-paid)" @"
select
 cast(sum(case when SISA_IDR>0 then SISA_IDR else 0 end) as numeric(18,2)) sisa_positif,
 cast(sum(case when SISA_IDR<0 then SISA_IDR else 0 end) as numeric(18,2)) sisa_negatif,
 cast(sum(SISA_IDR) as numeric(18,2)) total
from ($q) x
"@

Qry "2. Faktur OVER-PAID (SISA_IDR < -100rb) - vendor & voucher penyebab gap" @"
select CUST_ID, left(CUST_NAME,22) vendor, ORDER_CLIENT, left(BUKTI_REFF,14) reff, CURR_ID,
 cast(SALDO_AWAL_IDR as numeric(18,2)) awal, cast(MUTASI_IDR as numeric(18,2)) mutasi,
 cast(NILAI_BAYAR_IDR as numeric(18,2)) bayar, cast(SISA_IDR as numeric(18,2)) sisa
from ($q) x where SISA_IDR < -100000 order by SISA_IDR asc
"@
$cn.Close()
