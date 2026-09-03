$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=500; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$apj = ($ap -replace ':arg_tgl1',"'2026-07-01'" -replace ':arg_tgl2',"'2026-07-31'")
Qry "Opname AP Juli - baris JAYA DIESEL (adakah 409.800?)" ("select cust_id, cust_name, order_client, curr_id, cast(sisa_idr as numeric(18,2)) sisa_idr from ("+$apj+") x where upper(cust_name) like '%JAYA DIESEL%' and abs(sisa_idr)>0.01 order by sisa_idr desc")

Qry "ap_trans: dokumen non-item NOITEM260700029 & faktur Jaya Diesel Jul (akun hutang yg dipakai)" @"
select at.order_client, at.vendor_id, cast(at.tgl as date) tgl, cast(at.netto as numeric(18,2)) netto, at.hutang_account
from ap_trans at where at.order_client='NOITEM260700029'
   or (at.vendor_id='4SL.J013' and at.tgl between '2026-07-01' and '2026-07-31')
order by at.tgl
"@
$cn.Close()
