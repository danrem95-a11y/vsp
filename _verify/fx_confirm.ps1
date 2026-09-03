$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=500; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$ap=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ap_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
$ar=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
function OpnCur($tpl,$t1,$t2){ ($tpl -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'") }

Qry "AP opname Jun by CURR_ID (sisa_idr)" ("select curr_id, count(*) n, cast(sum(sisa_idr) as numeric(20,2)) sisa_idr from ("+(OpnCur $ap '2026-06-01' '2026-06-30')+") x group by curr_id order by curr_id")
Qry "AR opname Jun by CURR_ID (sisa_idr)" ("select curr_id, count(*) n, cast(sum(sisa_idr) as numeric(20,2)) sisa_idr from ("+(OpnCur $ar '2026-06-01' '2026-06-30')+") x group by curr_id order by curr_id")

Qry "Akun SELISIH KURS (nama)" "select AccountCode, AccountDes from gl_acc where site_id='101' and (upper(AccountDes) like '%KURS%' or upper(AccountDes) like '%SELISIH KURS%') order by AccountCode"

Qry "Movement akun *KURS* 2026 cumulative per bln (site101)" @"
select x.AccountCode acc, x.AccountDes,
 cast(x.m3 as numeric(20,2)) s_mar, cast(x.m4 as numeric(20,2)) s_apr, cast(x.m5 as numeric(20,2)) s_mei, cast(x.m6 as numeric(20,2)) s_jun
from (
 select a.AccountCode, a.AccountDes,
  isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl between '2026-01-01' and '2026-03-31'),0) m3,
  isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl between '2026-01-01' and '2026-04-30'),0) m4,
  isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl between '2026-01-01' and '2026-05-31'),0) m5,
  isnull((select sum(debet-kredit) from gl_journal where posting='P' and site_id='101' and account_id=a.AccountCode and tgl between '2026-01-01' and '2026-06-30'),0) m6
 from gl_acc a where a.site_id='101' and upper(a.AccountDes) like '%KURS%'
) x where abs(x.m6)>1 order by abs(x.m6) desc
"@
$cn.Close()
