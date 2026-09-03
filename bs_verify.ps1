$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "-- $lbl --"; $c=$P.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("   "+($a -join " | "))}; if(-not $any){Write-Host "   (kosong)"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }
$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$qd=$ar -replace ':arg_tgl1',"'2025-12-01'" -replace ':arg_tgl2',"'2025-12-31'"

Show "Opname Des2025 - Bingshan(200.B587) & Sutrisno(200.S327): faktur ber-SISA" @"
select CUST_ID, ORDER_CLIENT, cast(MUTASI_IDR as numeric(18,2)) mutasi, cast(NILAI_BAYAR_IDR as numeric(18,2)) bayar, cast(SISA_IDR as numeric(18,2)) sisa
from ($qd) x where CUST_ID in ('200.B587','200.S327') and abs(SISA_IDR)>1 order by CUST_ID, ORDER_CLIENT
"@
Show "Bingshan faktur ...002 di opname Des2025 (harus 170.995.500 kalau benar; 266jt=gantung)" @"
select ORDER_CLIENT, cast(SISA_IDR as numeric(18,2)) sisa from ($qd) x where ORDER_CLIENT='10105250700002'
"@
$P.Close()
