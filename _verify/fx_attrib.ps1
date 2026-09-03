$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=500; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
function O($tpl,$t1,$t2){ ($tpl -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'") }

Qry "AP opname JAN by CURR_ID (baseline)" ("select curr_id, cast(sum(sisa_idr) as numeric(20,2)) sisa from ("+(O $ap '2026-01-01' '2026-01-31')+") x group by curr_id order by curr_id")
Qry "AR opname JAN by CURR_ID (baseline)" ("select curr_id, cast(sum(sisa_idr) as numeric(20,2)) sisa from ("+(O $ar '2026-01-01' '2026-01-31')+") x group by curr_id order by curr_id")

Qry "AP top valas suppliers Jun (nama, sisa)" ("select cust_id, max(nama) nama, curr_id, cast(sum(sisa) as numeric(20,2)) sisa_valas, cast(sum(sisa_idr) as numeric(20,2)) sisa_idr from ("+(O $ap '2026-06-01' '2026-06-30')+") x where curr_id<>'IDR' group by cust_id, curr_id order by sisa_idr desc")
Qry "AR top valas customers Jun (nama, sisa)" ("select cust_id, max(nama) nama, curr_id, cast(sum(sisa) as numeric(20,2)) sisa_valas, cast(sum(sisa_idr) as numeric(20,2)) sisa_idr from ("+(O $ar '2026-06-01' '2026-06-30')+") x where curr_id<>'IDR' group by cust_id, curr_id order by sisa_idr desc")
$cn.Close()
