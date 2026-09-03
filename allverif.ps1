$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Val($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; try{return [string]$c.ExecuteScalar()}catch{return "ERR: "+$_.Exception.Message} }
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

$opn=[System.IO.File]::ReadAllText("C:\BTV\debug\_sql_ar_opname.sql") -replace '(?s)ORDER BY\s+MAIN\.CUST_ID.*',''
function OP($t1,$t2){ $q=$opn -replace ':arg_tgl1',"'$t1'" -replace ':arg_tgl2',"'$t2'"; return Val "select cast(sum(SISA_IDR) as numeric(18,2)) from ($q) x" }

Write-Host "=== A. OPNAME PIUTANG per bulan vs baseline ==="
Write-Host ("  Jan : "+(OP '2026-01-01' '2026-01-31')+"   (baseline 31.691.199.927,10)")
Write-Host ("  Feb : "+(OP '2026-02-01' '2026-02-28')+"   (HARUS 31.245.559.808,10)")
Write-Host ("  Mar : "+(OP '2026-03-01' '2026-03-31')+"   (baseline 29.231.343.776,10)")
Write-Host ("  Apr : "+(OP '2026-04-01' '2026-04-30')+"   (baseline 19.680.007.939,85)")
Write-Host ("  Mei : "+(OP '2026-05-01' '2026-05-31')+"   (baseline 20.913.005.029,66)")
Write-Host ("  Jun : "+(OP '2026-06-01' '2026-06-30'))

Qry "B. doc_reff lintas-bulan (Feb vs bulan lain) - masih utuh?" @"
select 'Feb-Mar' pasangan, count(*) n from (select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01' intersect select doc_reff from gl_journal where posting='P' and tgl>='2026-03-01' and tgl<'2026-04-01') a
union all select 'Feb-Apr', count(*) from (select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01' intersect select doc_reff from gl_journal where posting='P' and tgl>='2026-04-01' and tgl<'2026-05-01') b
union all select 'Feb-Mei', count(*) from (select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01' intersect select doc_reff from gl_journal where posting='P' and tgl>='2026-05-01' and tgl<'2026-06-01') c
union all select 'Feb-Jun', count(*) from (select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01' intersect select doc_reff from gl_journal where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01') d
"@

Qry "C. Contoh doc_reff Feb-Mei: kedua sisi 103-001 masih ada?" @"
select g.doc_reff,
   cast(sum(case when g.tgl>='2026-02-01' and g.tgl<'2026-03-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end) as numeric(18,2)) feb,
   cast(sum(case when g.tgl>='2026-05-01' and g.tgl<'2026-06-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end) as numeric(18,2)) mei
from gl_journal g where g.posting='P' and g.doc_reff in ('10103260200033','10103260200041','10103260200060','10101260200002')
group by g.doc_reff order by g.doc_reff
"@
$cn.Close()
