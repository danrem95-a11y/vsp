$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "0. Kolom SALDO_AWAL_FAKTUR" "select cname from SYS.SYSCOLUMNS where tname='SALDO_AWAL_FAKTUR' order by cname"

Qry "1. SAF (saldo awal 2026) utk faktur 10103251100061 (net = 94jt kalau benar)" @"
select bukti_id, tipe_trans, cast(periode as date) periode, cast(saldo as numeric(18,2)) saldo, cast(saldo_kurs as numeric(18,2)) saldo_kurs
from SALDO_AWAL_FAKTUR where bukti_id='10103251100061'
"@

$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$qd=$ar -replace ':arg_tgl1',"'2025-12-01'" -replace ':arg_tgl2',"'2025-12-31'"
Qry "2. Opname Des-2025 Metro Motor - faktur 10103251100061 (cocok GL?)" @"
select ORDER_CLIENT, cast(SALDO_AWAL_IDR as numeric(18,2)) awal, cast(NILAI_BAYAR_IDR as numeric(18,2)) bayar, cast(SISA_IDR as numeric(18,2)) sisa
from ($qd) x where CUST_ID='200.M096' and ORDER_CLIENT='10103251100061'
"@
Qry "3. Total Opname Des-2025 Metro Motor (SISA)" @"
select cast(sum(SISA_IDR) as numeric(18,2)) total_des25 from ($qd) x where CUST_ID='200.M096'
"@
$cn.Close()
