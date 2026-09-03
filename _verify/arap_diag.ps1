$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "gl_balance distinct period utk 103-001 (site101)" @"
select cast(period as date) period, count(*) n, cast(sum(amountdebet-amountcredit) as numeric(20,2)) net
from gl_balance where site_id='101' and accountcode='103-001' group by period order by period
"@

Qry "Scalars 103-001" @"
select
 cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where site_id='101' and period='2026-01-01' and accountcode='103-001') as numeric(20,2)) opening_glbal,
 cast((select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl>='2026-01-01' and tgl<'2026-02-01') as numeric(20,2)) mov_jan,
 cast((select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl>='2026-01-01' and tgl<'2026-05-01') as numeric(20,2)) mov_janapr,
 cast((select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and site_id='101' and account_id='103-001' and tgl<'2026-01-01') as numeric(20,2)) mov_before2026
"@

Qry "AR opname Jan & Apr (template) vs berbagai definisi ledger 103-001" @"
select 'x' k
"@
$cn.Close()
