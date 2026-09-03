$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }
$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$q=$ar -replace ':arg_tgl1',"'2026-06-01'" -replace ':arg_tgl2',"'2026-06-30'"

Qry "A. Opname AR Metro Motor Jun26 - faktur yg masih ada SISA" @"
select ORDER_CLIENT, left(BUKTI_REFF,14) reff, cast(SALDO_AWAL_IDR as numeric(18,2)) awal, cast(MUTASI_IDR as numeric(18,2)) mutasi, cast(NILAI_BAYAR_IDR as numeric(18,2)) bayar, cast(SISA_IDR as numeric(18,2)) sisa
from ($q) x where CUST_ID='200.M096' and abs(SISA_IDR)>1000 order by SISA_IDR desc
"@

Qry "B. Total Opname Metro Motor Jun26 (SISA)" @"
select cast(sum(SISA_IDR) as numeric(18,2)) total_kartu_piutang from ($q) x where CUST_ID='200.M096'
"@
$cn.Close()
